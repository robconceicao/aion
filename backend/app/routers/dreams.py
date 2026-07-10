from fastapi import APIRouter, Depends, HTTPException, Request, Header, BackgroundTasks, Response
from app.models.dream import (
    DreamCreate, InterviewRequest, InterviewResponse,
    NarrativeRequest, SemanticSearchRequest, SynthesisResult, SynthesisError
)
from app.database import get_supabase, get_supabase_service
from app.services.ai_service import (
    synthesize_dual,
    generate_interview_questions, analyze_recurring_pattern,
    generate_embedding
)
from datetime import datetime
from typing import Optional
import uuid
import asyncio
import logging
from app.routers.auth import get_current_user

router = APIRouter()
logger = logging.getLogger(__name__)

from app.core.recurrence import is_recurrence_triggered, numero_aparicoes


def _build_dream_row(
    dream_in: DreamCreate,
    synthesis: SynthesisResult,
    embedding: list | None,
    user_id: str,
    user_email: str,
    similar_dreams: list | None = None,
) -> tuple[str, dict]:
    """
    Monta payload dual (analise_completa + interpretacao_narrativa) na mesma row.
    INVARIANTE: os dois formatos são sempre gravados juntos (SPEC §5.3).
    """
    similar_dreams = similar_dreams or []
    legacy_interpretacao = {
        "narrative": synthesis.interpretacao_narrativa,
        "pergunta_para_reflexao": synthesis.pergunta_reflexao,
        "essencia": synthesis.analise_completa.sintese_tecnica,
        "simbolos_chave": [
            {"elemento": s.elemento, "significado": s.significado}
            for s in synthesis.analise_completa.simbolos
        ],
        "arquetipos": [
            {"nome": a.arquetipo, "descricao": a.manifestacao, "simbolo": "◯"}
            for a in synthesis.analise_completa.arquetipos
        ],
        "funcao_compensatoria": synthesis.analise_completa.compensacao,
        "fase_jornada": {"nome": synthesis.analise_completa.fase_jornada, "descricao": ""},
        "prospeccao": "",
        "mito_espelho": {"titulo": "", "paralela": ""},
        "pergunta_para_reflexao": synthesis.pergunta_reflexao,
        "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5,
        "is_recorrente": is_recurrence_triggered(len(similar_dreams)),
        "numero_aparicoes": (
            numero_aparicoes(len(similar_dreams))
            if is_recurrence_triggered(len(similar_dreams)) else 0
        ),
    }
    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "relato": dream_in.text,
        "analise_completa": synthesis.analise_completa.model_dump(),
        "interpretacao_narrativa": synthesis.interpretacao_narrativa,
        "pergunta_reflexao": synthesis.pergunta_reflexao,
        "interpretacao": legacy_interpretacao,
        "embedding": embedding,
        "tags_emocao": dream_in.tags_emocao or [],
        "temas": dream_in.temas or [],
        "residuos_diurnos": dream_in.residuos_diurnos or [],
        "is_recurrent": is_recurrence_triggered(len(similar_dreams)),
        "recurrence_count": len(similar_dreams),
        "user_id": user_id,
        "user_email": user_email,
        "created_at": datetime.utcnow().isoformat(),
        "interpretation_status": "ok",
        "embedding_status": "failed" if embedding is None else "ok",
    }
    return dream_id, dream_data


async def _persist_dream_dual_with_retry(dream_data: dict, max_attempts: int = 3) -> None:
    """
    Insert síncrono via service_role + retry + verificação por SELECT.
    Levanta se todas as tentativas falharem — o caller NÃO devolve HTTP 200.
    """
    service = get_supabase_service()
    dream_id = dream_data["id"]
    last_err: Exception | None = None
    delays = (0.5, 1.5)

    for attempt in range(1, max_attempts + 1):
        try:
            service.table("dreams").insert(dream_data).execute()
            check = (
                service.table("dreams")
                .select("id")
                .eq("id", dream_id)
                .limit(1)
                .execute()
            )
            if check.data:
                logger.info(
                    "[PERSIST] OK dream_id=%s attempt=%s embedding=%s",
                    dream_id, attempt, dream_data.get("embedding_status"),
                )
                return
            last_err = RuntimeError(
                f"insert retornou sem erro mas SELECT não encontrou id={dream_id}"
            )
            logger.error(
                "[PERSIST][ERROR] verify miss dream_id=%s attempt=%s/%s",
                dream_id, attempt, max_attempts,
            )
        except Exception as e:
            last_err = e
            logger.error(
                "[PERSIST][ERROR] insert falhou dream_id=%s attempt=%s/%s: %s",
                dream_id, attempt, max_attempts, e,
                exc_info=True,
            )
        if attempt < max_attempts:
            await asyncio.sleep(delays[attempt - 1])

    raise RuntimeError(
        f"persist failed after {max_attempts} attempts for dream_id={dream_id}: {last_err}"
    )


async def _background_recurrence_enrich(
    dream_id: str,
    dream_in: DreamCreate,
    synthesis: SynthesisResult,
    embedding: list | None,
    user_id: str,
):
    """
    Pós-resposta: detecta recorrência e enriquece analise_completa se aplicável.
    Falha aqui NÃO desfaz o insert dual já confirmado — só loga ERROR.
    """
    if embedding is None:
        return
    try:
        service = get_supabase_service()
        result = service.rpc("buscar_sonhos_semanticos", {
            "p_user_id": user_id,
            "query_emb": embedding,
            "threshold": 0.75,
            "max_results": 5,
        }).execute()
        similar_dreams = result.data or []

        if not is_recurrence_triggered(len(similar_dreams)):
            return

        recurrence_text = await analyze_recurring_pattern(
            current_dream=dream_in.text,
            similar_dreams=similar_dreams,
        )
        ac = synthesis.analise_completa.model_dump()
        ac["sintese_tecnica"] = (
            synthesis.analise_completa.sintese_tecnica
            + f"\n\n[PADRÃO RECORRENTE — {numero_aparicoes(len(similar_dreams))}ª ocorrência]\n"
            + recurrence_text
        )
        service.table("dreams").update({
            "analise_completa": ac,
            "is_recurrent": True,
            "recurrence_count": len(similar_dreams),
        }).eq("id", dream_id).execute()
        logger.info("[BACKGROUND] Recorrência OK dream_id=%s", dream_id)
    except Exception as e:
        logger.error(
            "[BACKGROUND][ERROR] recorrência falhou dream_id=%s: %s",
            dream_id, e, exc_info=True,
        )


@router.post("/", response_model=dict)
async def create_dream(
    dream_in: DreamCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """
    Cria uma nova interpretação de sonho com síntese dual (SPEC §5).

    A síntese dual roda em paralelo com o embedding.
    Em caso de SynthesisError → HTTP 503 e NADA persiste.
    Após síntese OK, o insert dual é SÍNCRONO (service_role) com retry+verify.
    HTTP 200 só é devolvido se a linha existir no banco (inclui `id`).
    Recorrência roda em background e pode falhar sem invalidar o 200.
    """
    user_id = current_user.get("sub")
    user_email = current_user.get("email", "anonimo@aion.app")

    # Síntese dual + embedding em paralelo
    try:
        synthesis_coro = synthesize_dual(
            dream_text=dream_in.text,
            tags_emocao=dream_in.tags_emocao,
            temas=dream_in.temas,
            residuos_diurnos=dream_in.residuos_diurnos,
            interview_answers=dream_in.interview_answers,
        )
        synthesis, embedding = await asyncio.gather(
            synthesis_coro,
            generate_embedding(dream_in.text),
            return_exceptions=False,  # SynthesisError propaga diretamente
        )
    except SynthesisError as e:
        logger.error("[ROUTER][ERROR] SynthesisError — nenhum dado salvo: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "synthesis_failed",
                "message": "Aion está em silêncio profundo. Nenhum provider de IA está disponível no momento. Tente novamente em instantes.",
            }
        )
    except Exception as e:
        if isinstance(e, SynthesisError):
            logger.error("[ROUTER][ERROR] SynthesisError (via gather): %s", e)
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "synthesis_failed",
                    "message": "Aion está em silêncio profundo. Tente novamente em instantes.",
                }
            )
        logger.error("[ROUTER][ERROR] Erro inesperado em create_dream: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail={"error": "internal_error", "message": str(e)})

    # Persistência dual SÍNCRONA — 200 só com linha confirmada
    dream_id, dream_data = _build_dream_row(
        dream_in, synthesis, embedding, user_id, user_email
    )
    try:
        await _persist_dream_dual_with_retry(dream_data)
    except Exception as e:
        logger.error(
            "[ROUTER][ERROR] Persistência dual FALHOU dream_id=%s user_id=%s: %s",
            dream_id,
            user_id,
            e,
            exc_info=True,
        )
        raise HTTPException(
            status_code=503,
            detail={
                "error": "persist_failed",
                "message": (
                    "A interpretação foi gerada, mas não foi possível salvá-la. "
                    "Tente novamente em instantes."
                ),
            },
        )

    # Recorrência (enriquecimento) — best-effort em background
    background_tasks.add_task(
        _background_recurrence_enrich,
        dream_id, dream_in, synthesis, embedding, user_id,
    )

    # 200: dual + id (linha garantida)
    return {
        "id": dream_id,
        "analise_completa": synthesis.analise_completa.model_dump(),
        "interpretacao_narrativa": synthesis.interpretacao_narrativa,
        "pergunta_reflexao": synthesis.pergunta_reflexao,
        # Compatibilidade com clientes Flutter antigos que leem 'narrative' e campos planos
        "narrative": synthesis.interpretacao_narrativa,
        "essencia": synthesis.analise_completa.sintese_tecnica,
        "simbolos_chave": [
            {"elemento": s.elemento, "significado": s.significado}
            for s in synthesis.analise_completa.simbolos
        ],
        "arquetipos": [
            {"nome": a.arquetipo, "descricao": a.manifestacao, "simbolo": "◯"}
            for a in synthesis.analise_completa.arquetipos
        ],
        "funcao_compensatoria": synthesis.analise_completa.compensacao,
        "fase_jornada": {"nome": synthesis.analise_completa.fase_jornada, "descricao": ""},
        "pergunta_para_reflexao": synthesis.pergunta_reflexao,
        "mito_espelho": {"titulo": "", "paralela": ""},
        "prospeccao": "",
        "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5,
    }


@router.get("/history", response_model=list)
async def get_user_history(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase()
    user_id = current_user.get("sub")
    try:
        res = (
            supabase.table("dreams")
            .select("id, relato, interpretacao, analise_completa, interpretacao_narrativa, pergunta_reflexao, audio_path, created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar histórico: {str(e)}")


@router.get("/{dream_id}/audio")
async def get_dream_audio_legacy(dream_id: str, current_user: dict = Depends(get_current_user)):
    """
    Endpoint legado de áudio (retorna bytes diretamente via Edge TTS sem cache).
    Mantido para compatibilidade com clientes antigos.
    O novo endpoint com cache está em POST /interpretacoes/{id}/audio (Fase 2).
    """
    supabase = get_supabase()
    user_id = current_user.get("sub")
    try:
        res = supabase.table("dreams").select("interpretacao, interpretacao_narrativa").eq("id", dream_id).eq("user_id", user_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Sonho não encontrado")

        # Prefere interpretacao_narrativa (novo campo) sobre legado
        narrativa = res.data[0].get("interpretacao_narrativa") or \
                    res.data[0].get("interpretacao", {}).get("narrative")
        if not narrativa:
            raise HTTPException(status_code=404, detail="Narrativa não disponível para este sonho")

        from app.services.audio_service import generate_narrative_audio
        audio_bytes = await generate_narrative_audio(narrativa)
        return Response(content=audio_bytes, media_type="audio/mpeg")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/interview", response_model=InterviewResponse)
async def get_interview_questions(request: InterviewRequest):
    try:
        perguntas = await generate_interview_questions(request.text)
        return InterviewResponse(perguntas=perguntas)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
async def semantic_search(
    request: SemanticSearchRequest,
    current_user: dict = Depends(get_current_user)
):
    """Busca semântica no diário de sonhos."""
    user_id = current_user.get("sub")
    try:
        query_embedding = await generate_embedding(request.query)
        supabase = get_supabase()
        result = supabase.rpc("buscar_sonhos_semanticos", {
            "p_user_id": user_id,
            "query_emb": query_embedding,
            "threshold": request.threshold,
            "max_results": request.max_results,
        }).execute()
        return {"results": result.data or []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/filter")
async def filter_dreams(
    emocao: str = None, fase: str = None,
    query: str = None, limit: int = 20, offset: int = 0,
    current_user: dict = Depends(get_current_user)
):
    """Filtra sonhos por emoção, fase da jornada ou texto livre."""
    user_id = current_user.get("sub")
    try:
        supabase = get_supabase()
        q = (supabase.table("dreams").select("*")
             .eq("user_id", user_id)
             .order("created_at", desc=True)
             .range(offset, offset + limit - 1))

        if emocao:
            q = q.contains("tags_emocao", [emocao])
        if fase:
            q = q.eq("interpretacao->fase_jornada->>nome", fase)
        if query:
            q = q.ilike("relato", f"%{query}%")

        result = q.execute()
        return {"dreams": result.data or []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

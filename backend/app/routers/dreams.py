from fastapi import APIRouter, Depends, HTTPException, Request, Header, BackgroundTasks, Response
from app.models.dream import (
    DreamCreate, InterviewRequest, InterviewResponse,
    NarrativeRequest, SemanticSearchRequest, SynthesisResult, SynthesisError
)
from app.database import get_supabase
from app.services.ai_service import (
    synthesize_dual,
    generate_interview_questions, analyze_recurring_pattern,
    generate_embedding
)
from datetime import datetime
from typing import Optional
import uuid
import asyncio
from app.routers.auth import get_current_user

router = APIRouter()

from app.core.recurrence import is_recurrence_triggered, numero_aparicoes


async def _background_save_and_recurrence(
    supabase, dream_in: DreamCreate, synthesis: SynthesisResult,
    embedding: list | None, user_id: str, user_email: str
):
    """
    Roda APÓS a resposta ser enviada ao cliente.
    Persiste o sonho com os dois formatos de interpretação na mesma operação.
    Detecta recorrência e enriquece analise_completa se aplicável.

    INVARIANTE: synthesis é sempre um SynthesisResult válido neste ponto —
    a rota não chama esta função em caso de SynthesisError.
    Os dois formatos (analise_completa + interpretacao_narrativa) são sempre
    gravados juntos, garantindo a não-divergência por construção (SPEC §5.3).
    """
    similar_dreams = []

    # Só busca recorrência se há embedding válido
    if embedding is not None:
        try:
            result = supabase.rpc("buscar_sonhos_semanticos", {
                "p_user_id": user_id,
                "query_emb": embedding,
                "threshold": 0.75,
                "max_results": 5,
            }).execute()
            similar_dreams = result.data or []

            if is_recurrence_triggered(len(similar_dreams)):
                recurrence_text = await analyze_recurring_pattern(
                    current_dream=dream_in.text,
                    similar_dreams=similar_dreams,
                )
                # Enriquece a síntese com metadado de recorrência (não altera os dois formatos)
                synthesis.analise_completa.sintese_tecnica = (
                    synthesis.analise_completa.sintese_tecnica
                    + f"\n\n[PADRÃO RECORRENTE — {numero_aparicoes(len(similar_dreams))}ª ocorrência]\n{recurrence_text}"
                )
        except Exception as e:
            print(f"[BACKGROUND] Erro recorrencia: {e}")

    # Prepara payload de compatibilidade para clientes legados
    # (campo 'interpretacao' mantido para não quebrar clients antigos)
    legacy_interpretacao = {
        "narrative": synthesis.interpretacao_narrativa,
        "pergunta_para_reflexao": synthesis.pergunta_reflexao,
        # Mapeamento dos campos novos para o formato legado esperado pelo Flutter atual
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
        "numero_aparicoes": numero_aparicoes(len(similar_dreams)) if is_recurrence_triggered(len(similar_dreams)) else 0,
    }

    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "relato": dream_in.text,
        # Novos campos (dual interpretation — SPEC §5.3)
        "analise_completa": synthesis.analise_completa.model_dump(),
        "interpretacao_narrativa": synthesis.interpretacao_narrativa,
        "pergunta_reflexao": synthesis.pergunta_reflexao,
        # Campo legado preservado para compatibilidade
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
        "interpretation_status": "ok",   # Sempre 'ok' aqui — SynthesisError impede chegar a esta função
        "embedding_status": "failed" if embedding is None else "ok",
    }
    try:
        supabase.table("dreams").insert(dream_data).execute()
        print(
            f"[BACKGROUND] Sonho {dream_id} salvo com dual interpretation "
            f"(embedding={dream_data['embedding_status']})."
        )
    except Exception as e:
        print(f"[BACKGROUND] Erro ao salvar: {str(e)}")


@router.post("/", response_model=dict)
async def create_dream(
    dream_in: DreamCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    """
    Cria uma nova interpretação de sonho com síntese dual (SPEC §5).

    A síntese dual roda em paralelo com o embedding.
    Em caso de SynthesisError (todos os providers falharam), retorna HTTP 503
    e NÃO persiste nada — o relato não é salvo sem interpretação.
    """
    supabase = get_supabase()
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
        print(f"[ROUTER] SynthesisError — nenhum dado salvo: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "error": "synthesis_failed",
                "message": "Aion está em silêncio profundo. Nenhum provider de IA está disponível no momento. Tente novamente em instantes.",
            }
        )
    except Exception as e:
        # asyncio.gather pode re-levantar SynthesisError ou erros de embedding
        # Embedding nunca levanta — retorna None. Qualquer outra exceção aqui é inesperada.
        if isinstance(e, SynthesisError):
            print(f"[ROUTER] SynthesisError (via gather) — nenhum dado salvo: {e}")
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "synthesis_failed",
                    "message": "Aion está em silêncio profundo. Tente novamente em instantes.",
                }
            )
        print(f"[ROUTER] Erro inesperado em create_dream: {e}")
        raise HTTPException(status_code=500, detail={"error": "internal_error", "message": str(e)})

    # Salva em background — síntese bem-sucedida garantida neste ponto
    background_tasks.add_task(
        _background_save_and_recurrence,
        supabase, dream_in, synthesis, embedding, user_id, user_email,
    )

    # Retorna o resultado dual ao cliente imediatamente
    return {
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

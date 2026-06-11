from fastapi import APIRouter, Depends, HTTPException, Request, Header, BackgroundTasks, Response
from app.models.dream import (
    DreamCreate, InterviewRequest, InterviewResponse,
    NarrativeRequest, SemanticSearchRequest
)
from app.database import get_supabase
from app.services.ai_service import (
    analyze_dream, analyze_dream_narrative, 
    generate_interview_questions, analyze_recurring_pattern,
    generate_embedding
)
from app.services.audio_service import generate_narrative_audio
from datetime import datetime
from typing import Optional
import uuid
import asyncio
from app.routers.auth import get_current_user

router = APIRouter()

async def _background_save_and_recurrence(
    supabase, dream_in: DreamCreate, analysis: dict,
    embedding: list, user_id: str, user_email: str
):
    """
    Roda APÓS a resposta ser enviada ao cliente.
    Detecta recorrência e persiste o sonho no Supabase.
    """
    similar_dreams = []
    try:
        # Busca sonhos do mesmo usuário para detectar recorrência
        result = supabase.rpc("buscar_sonhos_semanticos", {
            "p_user_id": user_id,
            "query_emb": embedding,
            "threshold": 0.75,
            "max_results": 3,
        }).execute()
        similar_dreams = result.data or []

        if len(similar_dreams) >= 2:
            recurrence_text = await analyze_recurring_pattern(
                current_dream=dream_in.text,
                similar_dreams=similar_dreams,
            )
            analysis["analise_recorrencia"] = {
                "is_recorrente": True,
                "numero_aparicoes": len(similar_dreams) + 1,
                "analise_evolucao": recurrence_text,
            }
    except Exception as e:
        print(f"[BACKGROUND] Erro recorrência: {e}")

    # Salva no Supabase
    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "relato": dream_in.text,
        "interpretacao": analysis,
        "embedding": embedding,
        "tags_emocao": dream_in.tags_emocao or [],
        "temas": dream_in.temas or [],
        "residuos_diurnos": dream_in.residuos_diurnos or [],
        "is_recurrent": len(similar_dreams) >= 2,
        "recurrence_count": len(similar_dreams),
        "user_id": user_id,
        "user_email": user_email,
        "created_at": datetime.utcnow().isoformat(),
    }
    try:
        supabase.table("dreams").insert(dream_data).execute()
        print(f"[BACKGROUND] Sonho {dream_id} salvo com sucesso.")
    except Exception as e:
        print(f"[BACKGROUND] Erro ao salvar: {str(e)}")


@router.post("/", response_model=dict)
async def create_dream(
    dream_in: DreamCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    supabase = get_supabase()
    user_id = current_user.get("sub")
    user_email = current_user.get("email", "anonimo@aion.app")

    # ── OTIMIZAÇÃO #1: Análise e Embedding em PARALELO ──────────────
    analysis, embedding = await asyncio.gather(
        analyze_dream(
            dream_text=dream_in.text,
            tags_emocao=dream_in.tags_emocao,
            temas=dream_in.temas,
            residuos_diurnos=dream_in.residuos_diurnos,
            interview_answers=dream_in.interview_answers,
        ),
        generate_embedding(dream_in.text),
    )

    # ── Narrativa ───────────
    try:
        narrative = await analyze_dream_narrative(
            dream_text=dream_in.text,
            analysis_context=analysis,
        )
        analysis["narrative"] = narrative
    except Exception as e:
        print(f"[ROUTER] Erro ao gerar narrativa: {e}")
        analysis["narrative"] = ""

    # ── OTIMIZAÇÃO #2: Recorrência + Supabase em BACKGROUND ─────────
    background_tasks.add_task(
        _background_save_and_recurrence,
        supabase, dream_in, analysis, embedding, user_id, user_email,
    )

    return analysis


@router.get("/history", response_model=list)
async def get_user_history(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase()
    user_id = current_user.get("sub")
    try:
        res = (
            supabase.table("dreams")
            .select("id, relato, interpretacao, created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar histórico: {str(e)}")


@router.get("/{dream_id}/audio")
async def get_dream_audio(dream_id: str, current_user: dict = Depends(get_current_user)):
    """Gera e retorna o áudio narrado (texto falado) da interpretação do sonho sob demanda."""
    supabase = get_supabase()
    user_id = current_user.get("sub")
    try:
        res = supabase.table("dreams").select("interpretacao").eq("id", dream_id).eq("user_id", user_id).execute()
        if not res.data:
            raise HTTPException(status_code=404, detail="Sonho não encontrado")
            
        narrative = res.data[0].get("interpretacao", {}).get("narrative")
        if not narrative:
            raise HTTPException(status_code=404, detail="Narrativa não disponível para este sonho")
            
        audio_bytes = await generate_narrative_audio(narrative)
        return Response(content=audio_bytes, media_type="audio/mpeg")
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

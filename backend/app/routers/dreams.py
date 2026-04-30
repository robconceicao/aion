from fastapi import APIRouter, Depends, HTTPException, Request, Header
from app.models.dream import (
    DreamCreate, InterviewRequest, InterviewResponse,
    NarrativeRequest, NarrativeResponse, SemanticSearchRequest
)
from app.database import get_supabase
from app.services.ai_service import (
    analyze_dream, analyze_dream_narrative, 
    generate_interview_questions, analyze_recurring_pattern,
    generate_embedding
)
from datetime import datetime
from typing import Optional
import uuid

router = APIRouter()

@router.post("/", response_model=dict)
async def create_dream(
    dream_in: DreamCreate,
    x_user_email: Optional[str] = Header(None),
):
    supabase = get_supabase()
    user_email = x_user_email or dream_in.user_email or "usuario@aion.app"

    # 1. Analisa via IA (Estrutural com tags e entrevista)
    analysis = await analyze_dream(
        dream_text=dream_in.text,
        tags_emocao=dream_in.tags_emocao,
        temas=dream_in.temas,
        residuos_diurnos=dream_in.residuos_diurnos,
        interview_answers=dream_in.interview_answers,
    )

    # 2. Narrativa
    try:
        narrative = await analyze_dream_narrative(
            dream_text=dream_in.text,
            analysis_context=analysis,
        )
        analysis["narrative"] = narrative
    except Exception as e:
        print(f"[ROUTER] Erro ao gerar narrativa: {e}")
        analysis["narrative"] = ""

    # 3. Embedding para busca semântica
    embedding = await generate_embedding(dream_in.text)

    # 4. Detectar recorrência
    similar_dreams = []
    try:
        # Busca sonhos similares do mesmo usuário no banco
        result = supabase.rpc("buscar_sonhos_semanticos", {
            "p_user_email": user_email,
            "query_emb": embedding,
            "threshold": 0.75,
            "max_results": 3,
        }).execute()
        
        similar_dreams = result.data or []
        
        # Se encontrou 2 ou mais sonhos anteriores similares, analisa o padrão
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
        print(f"[ROUTER] Erro detecção recorrência: {e}")

    # 5. Salva no Supabase
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
        "user_email": user_email,
        "created_at": datetime.utcnow().isoformat(),
    }

    try:
        supabase.table("dreams").insert(dream_data).execute()
    except Exception as e:
        print(f"[AVISO SUPABASE]: Erro ao salvar: {str(e)}")
    
    return analysis


@router.get("/history", response_model=list)
async def get_user_history(user_email: str):
    supabase = get_supabase()
    try:
        res = (
            supabase.table("dreams")
            .select("id, relato, interpretacao, created_at")
            .eq("user_email", user_email)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar histórico: {str(e)}")


@router.post("/interview", response_model=InterviewResponse)
async def get_interview_questions(request: InterviewRequest):
    try:
        perguntas = await generate_interview_questions(request.text)
        return InterviewResponse(perguntas=perguntas)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/search")
async def semantic_search(request: SemanticSearchRequest, x_user_email: Optional[str] = Header(None)):
    """Busca semântica no diário de sonhos."""
    user_email = x_user_email or "usuario@aion.app"
    try:
        query_embedding = await generate_embedding(request.query)
        supabase = get_supabase()
        result = supabase.rpc("buscar_sonhos_semanticos", {
            "p_user_email": user_email,
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
    x_user_email: Optional[str] = Header(None)
):
    """Filtra sonhos por emoção, fase da jornada ou texto livre."""
    user_email = x_user_email or "usuario@aion.app"
    try:
        supabase = get_supabase()
        q = (supabase.table("dreams").select("*")
             .eq("user_email", user_email)
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

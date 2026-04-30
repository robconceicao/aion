from fastapi import APIRouter, Depends, HTTPException, Request, Header
from app.models.dream import DreamCreate, DreamModel, NarrativeRequest, NarrativeResponse
from app.routers.auth import get_current_user
from app.database import get_supabase
from app.services.ai_service import analyze_dream, analyze_dream_narrative
from datetime import datetime
from typing import Optional
import uuid


router = APIRouter()


@router.post("/", response_model=dict)
async def create_dream(
    request: Request,
    dream_in: DreamCreate,
    x_user_email: Optional[str] = Header(None),
):
    supabase = get_supabase()

    # 1. Analisa via IA
    analysis = await analyze_dream(dream_in.text)

    # 2. Prepara dados — inclui e-mail do usuário se enviado pelo frontend
    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "relato": dream_in.text,
        "interpretacao": analysis,
        "created_at": datetime.utcnow().isoformat(),
    }
    if x_user_email:
        dream_data["user_email"] = x_user_email

    # 3. Salva no Supabase (Resiliente: não interrompe se falhar)
    try:
        supabase.table("sonhos").insert(dream_data).execute()
    except Exception as e:
        # Apenas loga o erro, mas não quebra a resposta para o usuário
        print(f"[AVISO SUPABASE]: Não foi possível salvar o registro, mas a análise continuará. Erro: {str(e)}")
    
    return analysis


@router.get("/history", response_model=list)
async def get_user_history(user_email: str):
    """
    Retorna o histórico de sonhos analisados de um usuário específico.
    Ordenado do mais recente para o mais antigo.
    """
    supabase = get_supabase()
    try:
        res = (
            supabase.table("sonhos")
            .select("id, relato, interpretacao, narrativa, created_at")
            .eq("user_email", user_email)
            .order("created_at", desc=True)
            .limit(50)
            .execute()
        )
        return res.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao buscar histórico: {str(e)}")


@router.get("/", response_model=list)
async def list_dreams():
    supabase = get_supabase()
    res = supabase.table("sonhos").select("*").limit(20).execute()
    return res.data


@router.get("/{dream_id}", response_model=dict)
async def get_dream(dream_id: str):
    supabase = get_supabase()
    res = supabase.table("sonhos").select("*").eq("id", dream_id).execute()

    if not res.data:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")

    return res.data[0]


@router.post("/narrative", response_model=NarrativeResponse)
async def get_narrative_interpretation(request: NarrativeRequest):
    """
    Retorna a interpretação narrativa (direta/acessível) do sonho.
    Recebe analysis_context para garantir coerência com o Mapa Arquetípico
    e usar a mesma pergunta para reflexão.
    """
    try:
        narrative_text = await analyze_dream_narrative(
            dream_text=request.text,
            analysis_context=request.analysis_context,
        )
        return NarrativeResponse(narrative=narrative_text)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erro ao gerar interpretação narrativa: {str(e)}"
        )

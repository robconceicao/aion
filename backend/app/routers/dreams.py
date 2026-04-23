from fastapi import APIRouter, Depends, HTTPException, Request
from app.models.dream import DreamCreate, DreamModel
from app.routers.auth import get_current_user
from app.database import get_supabase
from app.services.ai_service import analyze_dream
from datetime import datetime
import uuid

router = APIRouter()

@router.post("/", response_model=dict)
async def create_dream(
    request: Request,
    dream_in: DreamCreate
):
    # Usando um UUID válido para o usuário convidado
    current_user_id = "00000000-0000-0000-0000-000000000000"
    supabase = get_supabase()
    
    # 1. Analyze Dream via IA
    analysis = await analyze_dream(dream_in.text)
    
    # 2. Prepare data for Supabase (Apenas colunas essenciais confirmadas)
    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "relato": dream_in.text,
        "interpretacao": analysis
    }
    
    # 3. Save to Supabase (Table 'sonhos')
    try:
        # Nota: Estamos enviando apenas id, relato e interpretacao
        res = supabase.table("sonhos").insert(dream_data).execute()
        return dream_data
    except Exception as e:
        # Se falhar aqui, o log do Render mostrará o erro do Supabase
        print(f"[ERRO SUPABASE]: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Erro ao salvar no Oráculo: {str(e)}")

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

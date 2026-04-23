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
    dream_in: DreamCreate, 
    current_user: dict = Depends(get_current_user)
):
    supabase = get_supabase()
    
    # 1. Capture IP and simulate Geolocation
    client_host = request.client.host
    location = "São Paulo, Brasil" # Simulado
    
    # 2. Analyze Dream via IA (Immediate analysis for better UX)
    analysis = await analyze_dream(dream_in.text)
    
    # 3. Prepare data for Supabase
    dream_id = str(uuid.uuid4())
    dream_data = {
        "id": dream_id,
        "user_id": str(current_user.get("id", current_user.get("_id", "unknown"))),
        "relato": dream_in.text,
        "interpretacao": analysis,
        "criado_em": datetime.utcnow().isoformat(),
        "localizacao": location,
        "status": "processado"
    }
    
    # 4. Save to Supabase (Table 'sonhos')
    try:
        res = supabase.table("sonhos").insert(dream_data).execute()
        return dream_data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao salvar no Oráculo: {str(e)}")

@router.get("/", response_model=list)
async def list_dreams(current_user: dict = Depends(get_current_user)):
    supabase = get_supabase()
    user_id = str(current_user.get("id", current_user.get("_id", "unknown")))
    
    res = supabase.table("sonhos").select("*").eq("user_id", user_id).execute()
    return res.data

@router.get("/{dream_id}", response_model=dict)
async def get_dream(dream_id: str, current_user: dict = Depends(get_current_user)):
    supabase = get_supabase()
    user_id = str(current_user.get("id", current_user.get("_id", "unknown")))
    
    res = supabase.table("sonhos").select("*").eq("id", dream_id).eq("user_id", user_id).execute()
    
    if not res.data:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")
    
    return res.data[0]

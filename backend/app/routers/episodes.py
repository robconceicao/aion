from fastapi import APIRouter, HTTPException
from app.models.episode import EpisodeCreate, EpisodeModel
from app.database import get_supabase
from datetime import datetime
import uuid

router = APIRouter()

@router.get("/", response_model=list[EpisodeModel])
async def list_episodes():
    """Lista todos os episódios do canal em ordem crescente."""
    supabase = get_supabase()
    response = supabase.table("episodes").select("*").order("number", ascending=True).execute()
    return response.data

@router.get("/{episode_number}", response_model=EpisodeModel)
async def get_episode(episode_number: int):
    """Retorna um episódio específico pelo número."""
    supabase = get_supabase()
    response = supabase.table("episodes").select("*").eq("number", episode_number).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")
    return response.data[0]

@router.post("/", response_model=EpisodeModel, status_code=201)
async def create_episode(episode_in: EpisodeCreate):
    """Cria um novo episódio no canal."""
    supabase = get_supabase()

    # Impede duplicatas por número
    existing = supabase.table("episodes").select("*").eq("number", episode_in.number).execute()
    if existing.data:
        raise HTTPException(
            status_code=409,
            detail=f"Episódio número {episode_in.number} já existe.",
        )

    episode_dict = episode_in.model_dump()
    episode_dict["id"] = str(uuid.uuid4())
    episode_dict["created_at"] = datetime.utcnow().isoformat()

    response = supabase.table("episodes").insert(episode_dict).execute()
    return response.data[0]

@router.put("/{episode_number}", response_model=EpisodeModel)
async def update_episode(episode_number: int, episode_in: EpisodeCreate):
    """Atualiza os dados de um episódio existente."""
    supabase = get_supabase()
    
    update_data = episode_in.model_dump()
    response = supabase.table("episodes").update(update_data).eq("number", episode_number).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")
    
    return response.data[0]

@router.delete("/{episode_number}", status_code=204)
async def delete_episode(episode_number: int):
    """Remove um episódio do canal."""
    supabase = get_supabase()
    response = supabase.table("episodes").delete().eq("number", episode_number).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")

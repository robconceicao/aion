from fastapi import APIRouter, HTTPException, Depends
from app.models.episode import EpisodeCreate, EpisodeModel
from app.database import get_supabase, get_supabase_service
from app.routers.auth import get_current_admin
from datetime import datetime
import uuid

router = APIRouter()

@router.get("/", response_model=list[EpisodeModel])
async def list_episodes():
    """Lista todos os episódios do canal em ordem crescente."""
    supabase = get_supabase()
    response = supabase.table("episodes").select("*").order("number", desc=False).execute()
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
async def create_episode(episode_in: EpisodeCreate, admin: dict = Depends(get_current_admin)):
    """
    Cria um novo episódio no canal.

    service_role: as políticas de escrita de `episodes` são TO authenticated
    com claim de admin no JWT (migration 006). O cliente anon tem role `anon`,
    então nenhuma política permissiva se aplicava e o RLS negava a escrita —
    o admin passava por get_current_admin e o INSERT falhava no banco.
    Com service_role, Depends(get_current_admin) é a ÚNICA barreira.
    """
    supabase = get_supabase_service()

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
async def update_episode(episode_number: int, episode_in: EpisodeCreate, admin: dict = Depends(get_current_admin)):
    """
    Atualiza os dados de um episódio existente.

    service_role pelo mesmo motivo de create_episode — ver docstring de lá.
    Proteção = Depends(get_current_admin).
    """
    supabase = get_supabase_service()
    
    update_data = episode_in.model_dump()
    response = supabase.table("episodes").update(update_data).eq("number", episode_number).execute()
    
    if not response.data:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")
    
    return response.data[0]

@router.delete("/{episode_number}", status_code=204)
async def delete_episode(episode_number: int, admin: dict = Depends(get_current_admin)):
    """
    Remove um episódio do canal.

    service_role pelo mesmo motivo de create_episode — ver docstring de lá.
    Proteção = Depends(get_current_admin).
    """
    supabase = get_supabase_service()
    response = supabase.table("episodes").delete().eq("number", episode_number).execute()
    if not response.data:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")


from fastapi import APIRouter, HTTPException
from app.models.episode import EpisodeCreate, EpisodeModel
from app.database import get_database
from datetime import datetime
import uuid

router = APIRouter()


@router.get("/", response_model=list[EpisodeModel])
async def list_episodes():
    """Lista todos os episódios do canal em ordem crescente."""
    db = await get_database()
    episodes = await db.episodes.find().sort("number", 1).to_list(length=200)
    return episodes


@router.get("/{episode_number}", response_model=EpisodeModel)
async def get_episode(episode_number: int):
    """Retorna um episódio específico pelo número."""
    db = await get_database()
    episode = await db.episodes.find_one({"number": episode_number})
    if not episode:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")
    return episode


@router.post("/", response_model=EpisodeModel, status_code=201)
async def create_episode(episode_in: EpisodeCreate):
    """
    Cria um novo episódio no canal.
    Endpoint administrativo — adicione autenticação admin se necessário.
    """
    db = await get_database()

    # Impede duplicatas por número
    existing = await db.episodes.find_one({"number": episode_in.number})
    if existing:
        raise HTTPException(
            status_code=409,
            detail=f"Episódio número {episode_in.number} já existe.",
        )

    episode_dict = episode_in.model_dump()
    episode_dict["_id"] = str(uuid.uuid4())
    episode_dict["created_at"] = datetime.utcnow()

    await db.episodes.insert_one(episode_dict)
    return episode_dict


@router.put("/{episode_number}", response_model=EpisodeModel)
async def update_episode(episode_number: int, episode_in: EpisodeCreate):
    """Atualiza os dados de um episódio existente."""
    db = await get_database()
    episode = await db.episodes.find_one({"number": episode_number})
    if not episode:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")

    update_data = episode_in.model_dump()
    await db.episodes.update_one(
        {"number": episode_number}, {"$set": update_data}
    )
    updated = await db.episodes.find_one({"number": episode_number})
    return updated


@router.delete("/{episode_number}", status_code=204)
async def delete_episode(episode_number: int):
    """Remove um episódio do canal."""
    db = await get_database()
    result = await db.episodes.delete_one({"number": episode_number})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Episódio não encontrado")

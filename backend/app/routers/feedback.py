from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.routers.auth import get_current_user
from app.database import get_supabase_service

router = APIRouter()

class FeedbackCreate(BaseModel):
    rating: int  # 1 to 5
    comment: Optional[str] = None
    accurate_archetypes: bool = True

@router.post("/{dream_id}/feedback")
async def create_feedback(
    dream_id: str,
    feedback_in: FeedbackCreate,
    current_user: dict = Depends(get_current_user),
):
    # service_role: bypass RLS. Ownership no sonho = .eq("user_id", user_id).
    supabase = get_supabase_service()
    user_id = current_user.get("sub")

    # Verifica se o sonho pertence ao usuário
    res = (
        supabase.table("dreams")
        .select("id")
        .eq("id", dream_id)
        .eq("user_id", user_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Dream not found")

    # Persiste o feedback (id e created_at preenchidos pelo banco via default)
    feedback_data = {
        "dream_id": dream_id,
        "user_id": user_id,
        "rating": feedback_in.rating,
        "comment": feedback_in.comment,
        "accurate_archetypes": feedback_in.accurate_archetypes,
    }
    supabase.table("feedback").insert(feedback_data).execute()

    return {"status": "success", "message": "Feedback recorded. The Oracle learns."}

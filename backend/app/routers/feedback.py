from fastapi import APIRouter, Depends, HTTPException
from app.routers.auth import get_current_user
from app.database import get_supabase_service
from app.models.feedback import FeedbackCreate

router = APIRouter()

# Re-export para testes/imports legados (test_feedback_import).
__all__ = ["router", "FeedbackCreate", "create_feedback"]


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
    try:
        supabase.table("feedback").insert(feedback_data).execute()
    except Exception as e:
        # Log interno; resposta genérica ao cliente
        import logging
        logging.getLogger(__name__).error(
            "[FEEDBACK][ERROR] insert falhou dream_id=%s: %s", dream_id, e, exc_info=True
        )
        raise HTTPException(
            status_code=500,
            detail={"error": "feedback_failed", "message": "Não foi possível registrar o feedback."},
        )

    return {"status": "success", "message": "Feedback recorded. The Oracle learns."}

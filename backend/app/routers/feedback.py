from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.routers.auth import get_current_user
from app.database import get_database
from datetime import datetime

router = APIRouter()

class FeedbackCreate(BaseModel):
    rating: int # 1 to 5
    comment: Optional[str] = None
    accurate_archetypes: bool = True

@router.post("/{dream_id}/feedback")
async def create_feedback(
    dream_id: str,
    feedback_in: FeedbackCreate,
    current_user: dict = Depends(get_current_user)
):
    db = await get_database()
    
    # Verify dream belongs to user
    dream = await db.dreams.find_one({"_id": dream_id, "user_id": str(current_user["_id"])})
    if not dream:
        raise HTTPException(status_code=404, detail="Dream not found")
        
    feedback_dict = feedback_in.dict()
    feedback_dict["dream_id"] = dream_id
    feedback_dict["user_id"] = str(current_user["_id"])
    feedback_dict["created_at"] = datetime.utcnow()
    
    # Store feedback
    await db.feedback.insert_one(feedback_dict)
    
    # Log Analytics Event
    await db.analytics_events.insert_one({
        "event_type": "feedback_submitted",
        "user_id": str(current_user["_id"]),
        "dream_id": dream_id,
        "rating": feedback_in.rating,
        "timestamp": datetime.utcnow()
    })
    
    return {"status": "success", "message": "Feedback recorded. The Oracle learns."}

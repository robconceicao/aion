from fastapi import APIRouter, Depends, HTTPException
from app.models.feedback import FeedbackCreate, FeedbackModel
from app.routers.auth import get_current_user
from app.database import get_database
from datetime import datetime
import uuid

router = APIRouter()

@router.post("/{dream_id}", response_model=FeedbackModel)
async def create_feedback(
    dream_id: str,
    feedback_in: FeedbackCreate,
    current_user: dict = Depends(get_current_user)
):
    db = await get_database()
    
    # Verify dream exists and belongs to user
    dream = await db.dreams.find_one({"_id": dream_id, "user_id": str(current_user["_id"])})
    if not dream:
        raise HTTPException(status_code=404, detail="Dream not found")
    
    feedback_dict = feedback_in.dict()
    feedback_dict["_id"] = str(uuid.uuid4())
    feedback_dict["dream_id"] = dream_id
    feedback_dict["user_id"] = str(current_user["_id"])
    feedback_dict["created_at"] = datetime.utcnow()
    
    await db.feedback.insert_one(feedback_dict)
    
    # Also update the dream with the feedback reference or summary
    await db.dreams.update_one(
        {"_id": dream_id},
        {"$set": {"feedback_rating": feedback_in.rating}}
    )
    
    return feedback_dict

@router.get("/user", response_model=list[FeedbackModel])
async def list_user_feedback(current_user: dict = Depends(get_current_user)):
    db = await get_database()
    feedbacks = await db.feedback.find({"user_id": str(current_user["_id"])}).to_list(length=100)
    return feedbacks

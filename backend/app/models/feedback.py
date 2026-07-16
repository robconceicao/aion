from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class FeedbackCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(default=None, max_length=2000)
    accurate_archetypes: bool = True

class FeedbackModel(FeedbackCreate):
    id: str
    dream_id: str
    user_id: str
    created_at: datetime

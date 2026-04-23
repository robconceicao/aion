from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class FeedbackCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = None

class FeedbackModel(FeedbackCreate):
    id: str = Field(..., alias="_id")
    dream_id: str
    user_id: str
    created_at: datetime

    class Config:
        allow_population_by_field_name = True

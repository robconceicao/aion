from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, Field

class DreamAnalysis(BaseModel):
    essence: str
    archetypes: List[str]
    compensation: str
    symbols: List[str]
    journey_stage: str
    projection: str
    myth: str
    reflection: str

class DreamModel(BaseModel):
    id: Optional[str] = Field(None, alias="_id")
    user_id: str
    text: str
    emotion: str
    tags: List[str]
    is_recurrent: bool
    created_at: datetime = Field(default_factory=datetime.utcnow)
    analysis: Optional[DreamAnalysis] = None
    location: Optional[dict] = None # {country: str, city: str}

class DreamCreate(BaseModel):
    text: str
    emotion: str
    tags: List[str]
    is_recurrent: bool

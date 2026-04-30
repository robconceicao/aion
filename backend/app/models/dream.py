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
    narrative: str | None = None

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

class InterviewAnswerItem(BaseModel):
    pergunta: str
    resposta: str

class DreamCreate(BaseModel):
    text: str
    emotion: Optional[str] = "neutral"
    tags: Optional[List[str]] = []
    is_recurrent: Optional[bool] = False
    tags_emocao: Optional[List[str]] = None
    temas: Optional[List[str]] = None
    residuos_diurnos: Optional[List[str]] = None
    interview_answers: Optional[List[InterviewAnswerItem]] = None

class InterviewRequest(BaseModel):
    text: str

class InterviewResponse(BaseModel):
    perguntas: List[str]

class NarrativeRequest(BaseModel):
    text: str
    analysis_context: dict | None = None

class NarrativeResponse(BaseModel):
    narrative: str

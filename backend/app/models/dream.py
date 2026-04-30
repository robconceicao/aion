from pydantic import BaseModel
from typing import List, Optional, Dict, Any

class InterviewAnswerItem(BaseModel):
    pergunta: str
    resposta: str

class DreamCreate(BaseModel):
    text: str
    user_email: Optional[str] = "usuario@aion.app"
    emotion: Optional[str] = None
    tags: Optional[List[str]] = None
    is_recurrent: Optional[bool] = False
    
    # Tags estruturadas (Upgrade 2)
    tags_emocao: Optional[List[str]] = None
    temas: Optional[List[str]] = None
    residuos_diurnos: Optional[List[str]] = None
    
    # Entrevista (Upgrade 2)
    interview_answers: Optional[List[Dict[str, str]]] = None

class InterviewRequest(BaseModel):
    text: str

class InterviewResponse(BaseModel):
    perguntas: List[str]

class NarrativeRequest(BaseModel):
    text: str
    analysis_context: Optional[Dict[str, Any]] = None

class NarrativeResponse(BaseModel):
    narrative: str

class SemanticSearchRequest(BaseModel):
    query: str
    threshold: Optional[float] = 0.65
    max_results: Optional[int] = 6

class DreamHistoryResponse(BaseModel):
    id: str
    relato: str
    interpretacao: Dict[str, Any]
    created_at: str

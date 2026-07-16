from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Any


# Limites de input (proteção de custo LLM / DoS)
DREAM_TEXT_MAX_LEN = 8000
DREAM_TEXT_MIN_LEN = 5
SEARCH_QUERY_MAX_LEN = 500


# ─── MODELS EXISTENTES ──────────────────────────────────────────────────────

class InterviewAnswerItem(BaseModel):
    pergunta: str
    resposta: str

class DreamCreate(BaseModel):
    text: str = Field(..., min_length=DREAM_TEXT_MIN_LEN, max_length=DREAM_TEXT_MAX_LEN)
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
    text: str = Field(..., min_length=DREAM_TEXT_MIN_LEN, max_length=DREAM_TEXT_MAX_LEN)

class InterviewResponse(BaseModel):
    perguntas: List[str]

class NarrativeRequest(BaseModel):
    text: str = Field(..., min_length=DREAM_TEXT_MIN_LEN, max_length=DREAM_TEXT_MAX_LEN)
    analysis_context: Optional[Dict[str, Any]] = None

class NarrativeResponse(BaseModel):
    narrative: str

class SemanticSearchRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=SEARCH_QUERY_MAX_LEN)
    threshold: Optional[float] = Field(default=0.65, ge=0.0, le=1.0)
    max_results: Optional[int] = Field(default=6, ge=1, le=50)

class DreamHistoryResponse(BaseModel):
    id: str
    relato: str
    interpretacao: Dict[str, Any]
    created_at: str


# ─── MODELS NOVOS — SCHEMA DE SÍNTESE DUAL (SPEC §5.1) ─────────────────────

class Simbolo(BaseModel):
    """Um símbolo identificado no sonho com amplificação arquetípica."""
    elemento: str
    significado: str
    amplificacao: str

class Arquetipo(BaseModel):
    """Um arquétipo identificado no sonho e sua manifestação específica."""
    arquetipo: str
    manifestacao: str

class AnaliseCompleta(BaseModel):
    """
    Formato técnico estruturado — destinado a usuários que querem profundidade.
    Contém jargão junguiano/campbelliano explícito. Nunca exibido sem contexto
    que oriente o usuário a estar na 'aba técnica'.
    """
    simbolos: List[Simbolo] = []
    arquetipos: List[Arquetipo] = []
    compensacao: str = ""
    fase_jornada: str = ""
    sintese_tecnica: str = ""

    @field_validator('simbolos', 'arquetipos', mode='before')
    @classmethod
    def ensure_list(cls, v):
        return v if isinstance(v, list) else []

class SynthesisResult(BaseModel):
    """
    Resultado da síntese dual única (synthesize_dual).
    GARANTIA: os dois formatos são gerados em uma única chamada ao LLM
    e persistidos na mesma transação — nunca divergem em conteúdo interpretativo.

    analise_completa     → formato técnico estruturado (JSONB na tabela)
    interpretacao_narrativa → texto acessível, zero jargão (TEXT na tabela)
    pergunta_reflexao    → pergunta final em linguagem acessível (TEXT na tabela)
    """
    analise_completa: AnaliseCompleta
    interpretacao_narrativa: str
    pergunta_reflexao: str

    @field_validator('interpretacao_narrativa', 'pergunta_reflexao', mode='before')
    @classmethod
    def ensure_str(cls, v):
        return str(v) if v is not None else ""

class SynthesisError(Exception):
    """
    Erro tipado para falha de síntese dual.
    Propagado ao cliente como HTTP 503. Nada é gravado no banco quando
    este erro ocorre — o relato do sonho é preservado separadamente.
    """
    def __init__(self, reason: str):
        self.reason = reason
        super().__init__(f"SynthesisError: {reason}")

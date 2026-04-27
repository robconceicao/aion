from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class EpisodeCreate(BaseModel):
    number: int = Field(..., description="Número do episódio")
    title_main: str = Field(..., description="Título principal do episódio")
    title_secondary: str = Field(..., description="Título secundário / subtítulo")
    myths_symbols: list[str] = Field(default_factory=list, description="Mitos ou símbolos tratados")
    description: Optional[str] = Field(None, description="Descrição breve do episódio")


class EpisodeModel(EpisodeCreate):
    id: str = Field(alias="_id")
    created_at: datetime

    class Config:
        populate_by_name = True

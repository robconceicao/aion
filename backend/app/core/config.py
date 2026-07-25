import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Aion"
    ALLOWED_ORIGINS: list = [
        o.strip() for o in os.getenv(
            "ALLOWED_ORIGINS",
            "https://aion-self-seven.vercel.app,"
            "https://aion-git-main-robconceicaos-projects.vercel.app,"
            "https://aion-b546uzhij-robconceicaos-projects.vercel.app,"
            "http://localhost:5000"
        ).split(",") if o.strip()
    ]
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    ANTHROPIC_API_KEY: str = os.getenv("ANTHROPIC_API_KEY", "")
    XAI_API_KEY: str = os.getenv("XAI_API_KEY", "")
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

    # Chave service_role do Supabase — necessária para upload no Storage (Fase 2).
    # NUNCA hardcoded. Configurar exclusivamente como env var no Render.
    # Referência: SPEC §6.4 e §8.3 (regra de secrets).
    SUPABASE_SERVICE_KEY: str = os.getenv("SUPABASE_SERVICE_KEY", "")

    # Provider de TTS: 'edge' (padrão, zero credencial) ou 'google' (stub P2).
    # Ver app/services/tts_service.py para detalhes de cada implementação.
    TTS_PROVIDER: str = os.getenv("TTS_PROVIDER", "edge")

    class Config:
        env_file = ".env"
        # Permite vars de teste locais (E2E_USER_*) sem quebrar o boot do app.
        extra = "ignore"

settings = Settings()

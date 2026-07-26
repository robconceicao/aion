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

    # ElevenLabs — narração premium sob demanda (coexiste com Edge TTS).
    # NUNCA hardcoded. Provisionada manualmente como env var no Render.
    ELEVENLABS_API_KEY: str = os.getenv("ELEVENLABS_API_KEY", "")
    ELEVENLABS_VOICE_ID: str = os.getenv("ELEVENLABS_VOICE_ID", "")
    ELEVENLABS_MODEL_ID: str = os.getenv("ELEVENLABS_MODEL_ID", "eleven_multilingual_v2")
    # Preset "mais_estavel", escolhido por escuta na calibração de 2026-07-26:
    # prioriza consistência em narração longa sobre expressividade.
    # Ver docs/voice-design.md. Alterar qualquer valor abaixo invalida o cache
    # de narração existente (fazem parte do hash da cache_key) — intencional.
    ELEVENLABS_STABILITY: float = float(os.getenv("ELEVENLABS_STABILITY", "0.80"))
    ELEVENLABS_SIMILARITY_BOOST: float = float(os.getenv("ELEVENLABS_SIMILARITY_BOOST", "0.75"))
    ELEVENLABS_STYLE: float = float(os.getenv("ELEVENLABS_STYLE", "0.05"))
    ELEVENLABS_SPEED: float = float(os.getenv("ELEVENLABS_SPEED", "0.92"))
    ELEVENLABS_OUTPUT_FORMAT: str = os.getenv("ELEVENLABS_OUTPUT_FORMAT", "mp3_44100_128")

    # Guarda de custo — gerações reais (cache miss) por usuário por dia.
    ELEVENLABS_DAILY_LIMIT_PER_USER: int = int(os.getenv("ELEVENLABS_DAILY_LIMIT_PER_USER", "20"))

    class Config:
        env_file = ".env"
        # Permite vars de teste locais (E2E_USER_*) sem quebrar o boot do app.
        extra = "ignore"

settings = Settings()

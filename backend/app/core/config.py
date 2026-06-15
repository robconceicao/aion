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
    DEEPSEEK_API_KEY: str = os.getenv("DEEPSEEK_API_KEY", "")
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    SUPABASE_JWT_SECRET: str = os.getenv("SUPABASE_JWT_SECRET", "")

    class Config:
        env_file = ".env"

settings = Settings()

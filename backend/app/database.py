from supabase import create_client, Client
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Lazy clients — evita create_client no import (CI sem SUPABASE_* quebra a
# coleta de testes que só importam routers e mockam get_supabase_service).
_supabase: Client | None = None
_supabase_service: Client | None = None


def get_supabase() -> Client:
    """Cliente anon (leituras/RPCs). Lazy-init no primeiro uso."""
    global _supabase
    if _supabase is not None:
        return _supabase
    url = (settings.SUPABASE_URL or "").strip()
    key = (settings.SUPABASE_KEY or "").strip()
    if not url or not key:
        logger.error(
            "[DB][ERROR] SUPABASE_URL/SUPABASE_KEY ausentes — cliente anon impossível."
        )
        raise RuntimeError(
            "SUPABASE_URL e SUPABASE_KEY não configurados. "
            "Necessários para o cliente Supabase (anon)."
        )
    _supabase = create_client(url, key)
    return _supabase


def get_supabase_service() -> Client:
    """
    Cliente com SUPABASE_SERVICE_KEY (service_role).
    Obrigatório para insert/update de dreams sob RLS restritivo
    (WITH CHECK auth.uid() = user_id no cliente).
    """
    global _supabase_service
    if _supabase_service is not None:
        return _supabase_service
    if not (settings.SUPABASE_SERVICE_KEY or "").strip():
        logger.error(
            "[DB][ERROR] SUPABASE_SERVICE_KEY ausente — escritas privilegiadas impossíveis. "
            "Configure no Render (service_role do projeto Supabase)."
        )
        raise RuntimeError(
            "SUPABASE_SERVICE_KEY não configurada. "
            "Necessária para persistir sonhos sob RLS restritivo."
        )
    url = (settings.SUPABASE_URL or "").strip()
    if not url:
        raise RuntimeError("SUPABASE_URL não configurada.")
    _supabase_service = create_client(url, settings.SUPABASE_SERVICE_KEY.strip())
    return _supabase_service


# Mantendo compatibilidade de nome para facilitar a transição
async def get_database():
    return get_supabase()

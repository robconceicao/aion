from supabase import create_client, Client
from app.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Anon key — leituras/RPCs sob o modelo atual do backend.
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

# service_role — bypass RLS. Somente servidor. Nunca no Flutter.
_supabase_service: Client | None = None


def get_supabase():
    return supabase


def get_supabase_service() -> Client:
    """
    Cliente com SUPABASE_SERVICE_KEY (service_role).
    Obrigatório para insert/update de dreams sob RLS restritivo
    (WITH CHECK auth.uid() = user_id no cliente).
    """
    global _supabase_service
    if _supabase_service is not None:
        return _supabase_service
    if not settings.SUPABASE_SERVICE_KEY:
        logger.error(
            "[DB][ERROR] SUPABASE_SERVICE_KEY ausente — escritas privilegiadas impossíveis. "
            "Configure no Render (service_role do projeto Supabase)."
        )
        raise RuntimeError(
            "SUPABASE_SERVICE_KEY não configurada. "
            "Necessária para persistir sonhos sob RLS restritivo."
        )
    _supabase_service = create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)
    return _supabase_service


# Mantendo compatibilidade de nome para facilitar a transição
async def get_database():
    return supabase

from supabase import create_client, Client
from app.core.config import settings

# Initialize Supabase Client
supabase: Client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)

def get_supabase():
    return supabase

# Mantendo compatibilidade de nome para facilitar a transição
async def get_database():
    return supabase

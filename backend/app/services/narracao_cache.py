"""
Cache de narração multi-provider (ElevenLabs) — SPEC da task de narração, Fase 2.

Cobrança da ElevenLabs é por caractere: regerar o mesmo áudio é dinheiro
jogado fora. Este módulo garante que a mesma combinação de
(texto sanitizado + voice_id + model_id + voice_settings) nunca gera
duas chamadas à API — consulte sempre o cache antes de chamar o provider.
"""
import hashlib
import json
import datetime


def compute_cache_key(
    texto_sanitizado: str,
    voice_id: str,
    model_id: str,
    voice_settings: dict,
) -> str:
    """SHA-256 de texto + voice_id + model_id + voice_settings (serialização
    ordenada — a ordem das chaves no dict não pode mudar o hash)."""
    settings_serialized = json.dumps(voice_settings, sort_keys=True)
    payload = f"{texto_sanitizado}|{voice_id}|{model_id}|{settings_serialized}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def get_cached_narracao(supabase, cache_key: str) -> dict | None:
    """Consulta o cache por cache_key. Retorna a linha ou None (cache miss).
    Não faz nenhuma chamada externa — apenas leitura no Postgres."""
    res = (
        supabase.table("narracao_cache")
        .select("storage_path, duracao_segundos")
        .eq("cache_key", cache_key)
        .limit(1)
        .execute()
    )
    if res.data:
        return res.data[0]
    return None


def save_narracao_cache(
    supabase,
    *,
    dream_id: str,
    user_id: str,
    provider: str,
    cache_key: str,
    storage_path: str,
    voice_id: str,
    model_id: str,
    duracao_segundos: float | None,
) -> None:
    """Persiste uma geração real (cache miss) — cada chamada aqui representa
    uma cobrança real da ElevenLabs."""
    supabase.table("narracao_cache").insert({
        "dream_id": dream_id,
        "user_id": user_id,
        "provider": provider,
        "cache_key": cache_key,
        "storage_path": storage_path,
        "voice_id": voice_id,
        "model_id": model_id,
        "duracao_segundos": duracao_segundos,
    }).execute()


def count_generations_today(supabase, user_id: str, provider: str) -> int:
    """Conta gerações REAIS (cache miss) de hoje para a guarda de custo diária.
    Cache hits não inserem linha nova, então não entram nesta contagem."""
    today_start = datetime.datetime.now(datetime.timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    ).isoformat()
    res = (
        supabase.table("narracao_cache")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .eq("provider", provider)
        .gte("created_at", today_start)
        .execute()
    )
    return res.count or 0

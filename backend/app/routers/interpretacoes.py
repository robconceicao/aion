"""
Router de interpretações — operações sobre interpretações existentes.

Atualmente: endpoint de áudio on-demand com cache no Supabase Storage.
"""
from fastapi import APIRouter, Depends, HTTPException
from app.database import get_supabase_service
from app.services.tts_service import (
    get_tts_provider,
    get_elevenlabs_provider,
    ElevenLabsAuthError,
    ElevenLabsRateLimitError,
    ElevenLabsInvalidRequestError,
    ElevenLabsTimeoutError,
    ElevenLabsError,
)
from app.services.tts_sanitizer import sanitize_for_tts
from app.services.narracao_cache import (
    compute_cache_key,
    get_cached_narracao,
    save_narracao_cache,
    count_generations_today,
)
from app.routers.auth import get_current_user
from app.core.config import settings
from mutagen.mp3 import MP3
import datetime
import logging
import httpx
import io

logger = logging.getLogger(__name__)

router = APIRouter()

# Limite de caracteres para TTS — proteção de custo e latência (SPEC §10, Q4)
TTS_CHAR_LIMIT = 4000

# Caminho no bucket: {user_id}/{dream_id}.mp3
BUCKET_NAME = "interpretacoes-audio"

# Duração da signed URL em segundos (1 hora)
SIGNED_URL_EXPIRY = 3600

NARRACAO_PROVIDER_NAME = "elevenlabs"


def _require_service_key() -> str:
    """service_role key — só servidor. Nunca hardcoded."""
    key = settings.SUPABASE_SERVICE_KEY
    if not key:
        raise RuntimeError(
            "SUPABASE_SERVICE_KEY não configurada. "
            "Adicionar como env var no Render para habilitar cache de áudio."
        )
    return key


def _storage_headers() -> dict:
    key = _require_service_key()
    return {
        "Authorization": f"Bearer {key}",
        "apikey": key,
    }


async def _upload_audio_mp3(object_path: str, audio_bytes: bytes) -> None:
    """
    Upload via Storage REST (service_role) com x-upsert.
    Evita ambiguidades do client storage3 multipart em alguns ambientes.
    """
    base = settings.SUPABASE_URL.rstrip("/")
    url = f"{base}/storage/v1/object/{BUCKET_NAME}/{object_path}"
    headers = {
        **_storage_headers(),
        "Content-Type": "audio/mpeg",
        "x-upsert": "true",
    }
    async with httpx.AsyncClient(timeout=60.0) as client:
        resp = await client.post(url, content=audio_bytes, headers=headers)
        if resp.status_code in (200, 201):
            logger.info("[AUDIO] Upload OK path=%s bytes=%s", object_path, len(audio_bytes))
            return
        # fallback PUT (replace)
        resp2 = await client.put(url, content=audio_bytes, headers=headers)
        if resp2.status_code in (200, 201):
            logger.info("[AUDIO] Upload PUT OK path=%s", object_path)
            return
        raise RuntimeError(
            f"storage upload failed POST={resp.status_code} body={resp.text[:240]} "
            f"| PUT={resp2.status_code} body={resp2.text[:240]}"
        )


async def _create_signed_url(object_path: str) -> str:
    """Gera signed URL via Storage REST (service_role)."""
    base = settings.SUPABASE_URL.rstrip("/")
    url = f"{base}/storage/v1/object/sign/{BUCKET_NAME}/{object_path}"
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.post(
            url,
            headers={**_storage_headers(), "Content-Type": "application/json"},
            json={"expiresIn": SIGNED_URL_EXPIRY},
        )
        if resp.status_code != 200:
            raise RuntimeError(
                f"signed URL failed status={resp.status_code} body={resp.text[:240]}"
            )
        data = resp.json()
        # API devolve {"signedURL": "/object/sign/..."} (path relativo) ou URL absoluta
        signed = data.get("signedURL") or data.get("signedUrl") or data.get("signed_url")
        if not signed:
            raise RuntimeError(f"signed URL response sem campo: {list(data.keys())}")
        if signed.startswith("http"):
            return signed
        return f"{base}/storage/v1{signed}"


@router.post("/{dream_id}/audio")
async def request_audio(
    dream_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Gera ou recupera o áudio da interpretação narrativa (SPEC §6.2).
    
    Fluxo:
    1. Verifica ownership do sonho.
    2. Cache hit: audio_path preenchido → retorna signed URL (sem nova chamada TTS).
    3. Cache miss: gera TTS de interpretacao_narrativa, salva no bucket,
       grava audio_path + audio_gerado_em, retorna signed URL.
    
    Falha de TTS → HTTP 503 tipado. O texto narrativo permanece íntegro e acessível.
    Falha de Storage → HTTP 503 tipado. Idem.
    """
    user_id = current_user.get("sub")
    # service_role: bypass RLS. Ownership = ÚNICA proteção → sempre .eq("user_id", user_id).
    supabase = get_supabase_service()

    # 1. Verifica ownership e recupera estado do áudio
    try:
        res = (
            supabase.table("dreams")
            .select("id, user_id, interpretacao_narrativa, audio_path")
            .eq("id", dream_id)
            .eq("user_id", user_id)
            .single()
            .execute()
        )
    except Exception as e:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")

    if not res.data:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")

    dream = res.data

    # 2. Cache hit — retorna signed URL sem gerar novo áudio
    if dream.get("audio_path"):
        try:
            signed_url = await _create_signed_url(dream["audio_path"])
            logger.info("[AUDIO] cache hit — %s", dream["audio_path"])
            return {"signed_url": signed_url, "cached": True}
        except Exception as e:
            logger.error("[AUDIO][ERROR] signed URL cache miss regenerando: %s", e)
            # Não propaga — tenta regenerar abaixo
            pass

    # 3. Cache miss — verifica se há narrativa para sintetizar
    narrativa = dream.get("interpretacao_narrativa") or ""
    if not narrativa.strip():
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_narrative",
                "message": "Este sonho não possui narrativa disponível para áudio. "
                           "Pode ser um sonho legado sem interpretação narrativa."
            }
        )

    # Trunca se necessário (proteção de custo — SPEC §10 Q4)
    if len(narrativa) > TTS_CHAR_LIMIT:
        print(f"[AUDIO] Narrativa truncada de {len(narrativa)} para {TTS_CHAR_LIMIT} chars.")
        narrativa = narrativa[:TTS_CHAR_LIMIT]

    # 4. Gera áudio via TTS
    try:
        provider = get_tts_provider()
        audio_bytes = await provider.generate(narrativa)
        print(f"[AUDIO] TTS gerado — {len(audio_bytes)} bytes via {provider.__class__.__name__}")
    except NotImplementedError as e:
        raise HTTPException(
            status_code=503,
            detail={
                "error": "tts_not_implemented",
                "message": str(e)
            }
        )
    except Exception as e:
        print(f"[AUDIO] Falha TTS: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "error": "tts_failed",
                "message": "Não foi possível gerar o áudio no momento. O texto continua disponível para leitura."
            }
        )

    # 5. Upload para Supabase Storage (service_role REST)
    audio_path = f"{user_id}/{dream_id}.mp3"
    try:
        await _upload_audio_mp3(audio_path, audio_bytes)
    except Exception as e:
        logger.error("[AUDIO][ERROR] Upload Storage: %s", e, exc_info=True)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "storage_failed",
                "message": "Áudio gerado mas não foi possível salvar. O texto continua disponível para leitura.",
            }
        )

    # 6. Persiste audio_path + timestamp no registro do sonho
    # Ownership no update: .eq("id") E .eq("user_id") — service_role sem RLS.
    try:
        supabase.table("dreams").update({
            "audio_path": audio_path,
            "audio_gerado_em": datetime.datetime.utcnow().isoformat(),
        }).eq("id", dream_id).eq("user_id", user_id).execute()
    except Exception as e:
        # Não fatal — o áudio foi gerado e uploadado; só o cache ficou sem registro
        logger.error("[AUDIO][ERROR] Falha ao persistir audio_path dream_id=%s: %s", dream_id, e)

    # 7. Gera e retorna signed URL
    try:
        signed_url = await _create_signed_url(audio_path)
        return {"signed_url": signed_url, "cached": False}
    except Exception as e:
        logger.error("[AUDIO][ERROR] signed URL final: %s", e, exc_info=True)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "signed_url_failed",
                "message": "Áudio gerado mas URL temporária indisponível. Tente novamente.",
            }
        )


def _mp3_duration_seconds(audio_bytes: bytes) -> float | None:
    """Lê a duração do MP3 pelo header (mutagen), sem decodificar o áudio."""
    try:
        audio = MP3(io.BytesIO(audio_bytes))
        return round(audio.info.length, 2)
    except Exception as e:
        logger.warning("[NARRACAO] Não foi possível calcular duração do MP3: %s", e)
        return None


@router.post("/{dream_id}/narracao")
async def request_narracao(
    dream_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    Gera ou recupera a narração premium (ElevenLabs) da interpretação narrativa.

    Coexiste com POST /{dream_id}/audio (Edge TTS) — não o substitui.
    Cache chaveado por hash(texto_sanitizado + voice_id + model_id + voice_settings),
    não por dream_id: a mesma interpretação pode ter narrações cacheadas para
    configurações de voz diferentes sem invalidar umas às outras.

    Fluxo:
    1. Verifica ownership do sonho.
    2. Cache hit (por hash): retorna signed URL sem chamar a ElevenLabs.
    3. Cache miss: checa guarda de custo diária, gera via ElevenLabs, faz
       upload, persiste o cache, retorna signed URL.
    """
    user_id = current_user.get("sub")
    # service_role: bypass RLS. Busca por id apenas (sem filtro de user_id) para
    # poder distinguir 404 (não existe) de 403 (existe, mas não é do usuário) —
    # diferente do endpoint /audio, aqui o critério de aceite pede 403 explícito.
    supabase = get_supabase_service()

    # 1. Busca o sonho e verifica ownership
    try:
        res = (
            supabase.table("dreams")
            .select("id, user_id, interpretacao_narrativa")
            .eq("id", dream_id)
            .single()
            .execute()
        )
    except Exception:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")

    if not res.data:
        raise HTTPException(status_code=404, detail="Sonho não encontrado")

    dream = res.data
    if dream.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Você não tem acesso a esta interpretação")

    narrativa = dream.get("interpretacao_narrativa") or ""
    if not narrativa.strip():
        raise HTTPException(
            status_code=404,
            detail={
                "error": "no_narrative",
                "message": "Este sonho não possui narrativa disponível para narração. "
                           "Pode ser um sonho legado sem interpretação narrativa."
            }
        )

    # Usa o formato narrativo (nunca o técnico) e sanitiza markdown antes de sintetizar.
    texto_sanitizado = sanitize_for_tts(narrativa)

    provider = get_elevenlabs_provider()
    cache_key = compute_cache_key(
        texto_sanitizado, provider.voice_id, provider.model_id, provider.voice_settings
    )

    # 2. Cache hit — sem chamada à ElevenLabs
    cached = get_cached_narracao(supabase, cache_key)
    if cached:
        try:
            signed_url = await _create_signed_url(cached["storage_path"])
            logger.info("[NARRACAO] cache hit — %s", cached["storage_path"])
            return {
                "signed_url": signed_url,
                "duracao_segundos": cached.get("duracao_segundos"),
                "cached": True,
            }
        except Exception as e:
            logger.error("[NARRACAO][ERROR] signed URL cache hit falhou, regenerando: %s", e)
            # Não propaga — tenta gerar de novo abaixo (cache_key é o mesmo,
            # o insert seguinte substitui a referência de storage_path).

    # 3. Guarda de custo diária — só conta gerações reais (cache miss).
    generations_today = count_generations_today(supabase, user_id, NARRACAO_PROVIDER_NAME)
    if generations_today >= settings.ELEVENLABS_DAILY_LIMIT_PER_USER:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "daily_limit_exceeded",
                "message": f"Limite diário de {settings.ELEVENLABS_DAILY_LIMIT_PER_USER} "
                           "narrações atingido. Tente novamente amanhã.",
            }
        )

    # 4. Gera via ElevenLabs — cada exceção tipada vira uma mensagem distinta.
    try:
        audio_bytes = await provider.generate(texto_sanitizado)
    except ElevenLabsAuthError as e:
        logger.error("[NARRACAO][ERROR] ElevenLabs auth: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "elevenlabs_auth_failed",
                "message": "Não foi possível gerar a narração agora. Tente novamente mais tarde.",
            }
        )
    except ElevenLabsRateLimitError as e:
        logger.error("[NARRACAO][ERROR] ElevenLabs rate limit: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "elevenlabs_rate_limited",
                "message": "O serviço de narração está sobrecarregado no momento. Tente novamente em instantes.",
            }
        )
    except ElevenLabsInvalidRequestError as e:
        logger.error("[NARRACAO][ERROR] ElevenLabs payload inválido: %s", e)
        raise HTTPException(
            status_code=422,
            detail={
                "error": "elevenlabs_invalid_request",
                "message": "Não foi possível narrar este texto.",
            }
        )
    except ElevenLabsTimeoutError as e:
        logger.error("[NARRACAO][ERROR] ElevenLabs timeout: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "elevenlabs_timeout",
                "message": "O serviço de narração demorou demais para responder. Tente novamente.",
            }
        )
    except ElevenLabsError as e:
        logger.error("[NARRACAO][ERROR] ElevenLabs falhou: %s", e)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "elevenlabs_failed",
                "message": "Não foi possível gerar a narração no momento. O texto continua disponível para leitura.",
            }
        )

    duracao_segundos = _mp3_duration_seconds(audio_bytes)

    # 5. Upload para Supabase Storage (mesmo bucket privado do Edge TTS,
    # path diferente para não colidir: elevenlabs/{user_id}/{cache_key}.mp3)
    storage_path = f"elevenlabs/{user_id}/{cache_key}.mp3"
    try:
        await _upload_audio_mp3(storage_path, audio_bytes)
    except Exception as e:
        logger.error("[NARRACAO][ERROR] Upload Storage: %s", e, exc_info=True)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "storage_failed",
                "message": "Narração gerada mas não foi possível salvar. Tente novamente.",
            }
        )

    # 6. Persiste o cache — falha aqui não é fatal (áudio já está no storage),
    # mas significa que a próxima requisição vai gerar de novo.
    try:
        save_narracao_cache(
            supabase,
            dream_id=dream_id,
            user_id=user_id,
            provider=NARRACAO_PROVIDER_NAME,
            cache_key=cache_key,
            storage_path=storage_path,
            voice_id=provider.voice_id,
            model_id=provider.model_id,
            duracao_segundos=duracao_segundos,
        )
    except Exception as e:
        logger.error("[NARRACAO][ERROR] Falha ao persistir cache dream_id=%s: %s", dream_id, e)

    # 7. Gera e retorna signed URL
    try:
        signed_url = await _create_signed_url(storage_path)
        return {
            "signed_url": signed_url,
            "duracao_segundos": duracao_segundos,
            "cached": False,
        }
    except Exception as e:
        logger.error("[NARRACAO][ERROR] signed URL final: %s", e, exc_info=True)
        raise HTTPException(
            status_code=503,
            detail={
                "error": "signed_url_failed",
                "message": "Narração gerada mas URL temporária indisponível. Tente novamente.",
            }
        )

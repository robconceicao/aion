"""
Router de interpretações — operações sobre interpretações existentes.

Atualmente: endpoint de áudio on-demand com cache no Supabase Storage.
"""
from fastapi import APIRouter, Depends, HTTPException
from app.database import get_supabase_service
from app.services.tts_service import get_tts_provider
from app.routers.auth import get_current_user
from app.core.config import settings
import datetime
import logging
import httpx

logger = logging.getLogger(__name__)

router = APIRouter()

# Limite de caracteres para TTS — proteção de custo e latência (SPEC §10, Q4)
TTS_CHAR_LIMIT = 4000

# Caminho no bucket: {user_id}/{dream_id}.mp3
BUCKET_NAME = "interpretacoes-audio"

# Duração da signed URL em segundos (1 hora)
SIGNED_URL_EXPIRY = 3600


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

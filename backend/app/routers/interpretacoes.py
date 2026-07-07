"""
Router de interpretações — operações sobre interpretações existentes.

Atualmente: endpoint de áudio on-demand com cache no Supabase Storage.
"""
from fastapi import APIRouter, Depends, HTTPException
from app.database import get_supabase
from app.services.tts_service import get_tts_provider
from app.routers.auth import get_current_user
from app.core.config import settings
from supabase import create_client
import datetime

router = APIRouter()

# Limite de caracteres para TTS — proteção de custo e latência (SPEC §10, Q4)
TTS_CHAR_LIMIT = 4000

# Caminho no bucket: {user_id}/{dream_id}.mp3
BUCKET_NAME = "interpretacoes-audio"

# Duração da signed URL em segundos (1 hora)
SIGNED_URL_EXPIRY = 3600


def _get_storage_client():
    """
    Retorna cliente Supabase com SUPABASE_SERVICE_KEY para operações de Storage.
    A chave service_role é necessária para upload em bucket privado.
    
    SEGURANÇA: a chave é lida exclusivamente de settings.SUPABASE_SERVICE_KEY,
    que por sua vez lê exclusivamente da env var SUPABASE_SERVICE_KEY.
    Nunca aparece hardcoded. (SPEC §8.3)
    """
    if not settings.SUPABASE_SERVICE_KEY:
        raise ValueError(
            "[TTS] SUPABASE_SERVICE_KEY não configurada. "
            "Adicionar como env var no Render para habilitar cache de áudio."
        )
    return create_client(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_KEY)


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
    supabase = get_supabase()

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
            storage = _get_storage_client()
            signed = storage.storage.from_(BUCKET_NAME).create_signed_url(
                dream["audio_path"], SIGNED_URL_EXPIRY
            )
            print(f"[AUDIO] cache hit — {dream['audio_path']}")
            return {"signed_url": signed["signedURL"], "cached": True}
        except Exception as e:
            print(f"[AUDIO] Falha ao gerar signed URL para cache: {e}")
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

    # 5. Upload para Supabase Storage
    audio_path = f"{user_id}/{dream_id}.mp3"
    try:
        storage = _get_storage_client()
        storage.storage.from_(BUCKET_NAME).upload(
            path=audio_path,
            file=audio_bytes,
            file_options={"content-type": "audio/mpeg", "upsert": "true"}
        )
        print(f"[AUDIO] Upload concluído — {audio_path}")
    except Exception as e:
        print(f"[AUDIO] Falha no upload Storage: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "error": "storage_failed",
                "message": "Áudio gerado mas não foi possível salvar. O texto continua disponível para leitura."
            }
        )

    # 6. Persiste audio_path + timestamp no registro do sonho
    try:
        supabase.table("dreams").update({
            "audio_path": audio_path,
            "audio_gerado_em": datetime.datetime.utcnow().isoformat(),
        }).eq("id", dream_id).execute()
    except Exception as e:
        # Não fatal — o áudio foi gerado e uploadado; só o cache ficou sem registro
        print(f"[AUDIO] Falha ao persistir audio_path (não fatal): {e}")

    # 7. Gera e retorna signed URL
    try:
        storage = _get_storage_client()
        signed = storage.storage.from_(BUCKET_NAME).create_signed_url(
            audio_path, SIGNED_URL_EXPIRY
        )
        return {"signed_url": signed["signedURL"], "cached": False}
    except Exception as e:
        print(f"[AUDIO] Falha ao gerar signed URL final: {e}")
        raise HTTPException(
            status_code=503,
            detail={
                "error": "signed_url_failed",
                "message": "Áudio gerado mas URL temporária indisponível. Tente novamente."
            }
        )

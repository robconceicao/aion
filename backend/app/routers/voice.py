from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Header
from app.routers.auth import get_current_user
from app.services.voice_service import transcribe_audio
from app.services.tadeu_metering import check_tadeu_quota, consume_tadeu_usage
import logging
import os
import tempfile
import uuid

logger = logging.getLogger(__name__)

router = APIRouter()

# Limite de upload de áudio (proteção de memória / custo Gemini)
MAX_AUDIO_BYTES = 15 * 1024 * 1024  # 15 MB
ALLOWED_EXTENSIONS = {".m4a", ".mp3", ".wav", ".ogg", ".aac", ".webm", ".flac"}
CHUNK_SIZE = 1024 * 1024  # 1 MB


@router.post("/transcribe")
async def transcribe_voice(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
    x_tadeu_token: str | None = Header(default=None, alias="X-Tadeu-Token"),
    x_tadeu_idempotency_key: str | None = Header(
        default=None,
        alias="X-Tadeu-Idempotency-Key",
    ),
):
    """
    Receives an audio file, transcribes it using Gemini, and returns the text.
    The file is stored temporarily and deleted after processing.

    A cota Tadeu Apps é consultada antes da chamada externa e consumida somente
    depois de uma transcrição válida, evitando desconto em falhas do provedor.
    """
    filename = file.filename or "audio.m4a"
    extension = os.path.splitext(filename)[1].lower()
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail="Unsupported audio format")

    # Diretório temp portátil (Linux Render e Windows local)
    temp_dir = os.path.join(tempfile.gettempdir(), "aion")
    os.makedirs(temp_dir, exist_ok=True)
    temp_path = os.path.join(temp_dir, f"temp_{uuid.uuid4()}{extension}")

    try:
        total = 0
        with open(temp_path, "wb") as buffer:
            while True:
                chunk = file.file.read(CHUNK_SIZE)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_AUDIO_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail={
                            "error": "audio_too_large",
                            "message": f"Áudio excede o limite de {MAX_AUDIO_BYTES // (1024 * 1024)} MB.",
                        },
                    )
                buffer.write(chunk)

        if total == 0:
            raise HTTPException(status_code=400, detail="Empty audio file")

        await check_tadeu_quota(
            token=x_tadeu_token,
            feature="voice_transcriptions_monthly",
        )

        transcription = await transcribe_audio(temp_path)

        if not transcription:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "transcription_failed",
                    "message": "Não foi possível transcrever o áudio. Tente novamente.",
                },
            )

        await consume_tadeu_usage(
            token=x_tadeu_token,
            feature="voice_transcriptions_monthly",
            amount=1,
            idempotency_key=x_tadeu_idempotency_key,
        )

        return {"text": transcription}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(
            "[VOICE][ERROR] transcribe user=%s: %s",
            current_user.get("sub"),
            e,
            exc_info=True,
        )
        raise HTTPException(
            status_code=500,
            detail={
                "error": "transcription_error",
                "message": "Erro interno na transcrição.",
            },
        )
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                pass

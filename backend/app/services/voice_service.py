import os
import base64
import json
import httpx
from app.core.config import settings


async def transcribe_audio(audio_path: str) -> str | None:
    """
    Transcreve um arquivo de áudio usando a API Gemini (multimodal).
    Retorna o texto transcrito ou None em caso de falha.
    """
    if not settings.GEMINI_API_KEY:
        print("[VOICE_SERVICE] GEMINI_API_KEY não configurada. Transcrição indisponível.")
        return None

    print(f"[VOICE_SERVICE] Iniciando transcrição: {audio_path}")

    # Lê e codifica o arquivo em base64
    try:
        with open(audio_path, "rb") as f:
            audio_bytes = f.read()
        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
    except FileNotFoundError:
        print(f"[VOICE_SERVICE] Arquivo não encontrado: {audio_path}")
        return None
    except Exception as e:
        print(f"[VOICE_SERVICE] Erro ao ler arquivo de áudio: {e}")
        return None

    # Determina o MIME type pelo formato do arquivo
    ext = os.path.splitext(audio_path)[1].lower()
    mime_map = {
        ".m4a": "audio/mp4",
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".ogg": "audio/ogg",
        ".aac": "audio/aac",
        ".webm": "audio/webm",
        ".flac": "audio/flac",
    }
    mime_type = mime_map.get(ext, "audio/mp4")
    print(f"[VOICE_SERVICE] Formato detectado: {mime_type}")

    # Monta o payload para a API Gemini (gemini-1.5-flash — mais rápido e eficiente para STT)
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={settings.GEMINI_API_KEY}"

    payload = {
        "contents": [
            {
                "parts": [
                    {
                        "text": (
                            "Transcreva o áudio abaixo de forma literal e completa. "
                            "O usuário está relatando um sonho que acabou de ter. "
                            "Mantenha as palavras exatas, sem corrigir ou resumir. "
                            "Responda APENAS com o texto transcrito, sem qualquer comentário adicional."
                        )
                    },
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": audio_b64,
                        }
                    },
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.0,
            "maxOutputTokens": 2048,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            print(f"[VOICE_SERVICE] Enviando áudio para Gemini ({len(audio_bytes)} bytes)...")
            response = await client.post(url, json=payload)
            response.raise_for_status()

            data = response.json()
            transcription = (
                data.get("candidates", [{}])[0]
                .get("content", {})
                .get("parts", [{}])[0]
                .get("text", "")
                .strip()
            )

            if transcription:
                print(f"[VOICE_SERVICE] Transcrição concluída ({len(transcription)} chars).")
                return transcription
            else:
                print("[VOICE_SERVICE] Gemini retornou resposta vazia.")
                return None

    except httpx.HTTPStatusError as e:
        print(f"[VOICE_SERVICE] Erro HTTP {e.response.status_code}: {e.response.text}")
        return None
    except Exception as e:
        print(f"[VOICE_SERVICE] Erro inesperado: {e}")
        return None

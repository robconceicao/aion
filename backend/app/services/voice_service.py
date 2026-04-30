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

    # Monta o payload para a API Gemini (gemini-2.5-flash — o modelo estável de 2026 confirmado no diagnóstico)
    gemini_key = settings.GEMINI_API_KEY.strip()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={gemini_key}"

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": "Transcreva o áudio a seguir exatamente como foi dito, sem comentários adicionais. Se não houver fala clara, retorne apenas '[Áudio sem fala clara]'."},
                    {
                        "inline_data": {
                            "mime_type": mime_type,
                            "data": audio_b64
                        }
                    }
                ]
            }
        ]
    }

    import asyncio
    max_retries = 3
    for attempt in range(max_retries):
        try:
            async with httpx.AsyncClient(timeout=45.0) as client:
                print(f"[VOICE_SERVICE] Enviando áudio para Gemini (Tentativa {attempt + 1}/{max_retries})...")
                response = await client.post(url, json=payload)
                
                if response.status_code == 200:
                    data = response.json()
                    transcription = data['candidates'][0]['content']['parts'][0]['text']
                    print(f"[VOICE_SERVICE] Transcrição concluída ({len(transcription)} chars).")
                    return transcription.strip()
                
                elif response.status_code == 503:
                    print(f"[VOICE_SERVICE] Gemini sobrecarregado (503). Aguardando para tentar novamente...")
                    if attempt < max_retries - 1:
                        await asyncio.sleep(2.0)
                        continue
                
                print(f"[VOICE_SERVICE] Erro HTTP {response.status_code}: {response.text}")
                return None
                
        except Exception as e:
            print(f"[VOICE_SERVICE] Erro na tentativa {attempt + 1}: {e}")
            if attempt < max_retries - 1:
                await asyncio.sleep(1.0)
                continue
            return None

    return None

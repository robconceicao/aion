from google import genai
from app.core.config import settings

# Novo SDK oficial do Google
client = genai.Client(api_key=settings.GEMINI_API_KEY)

async def transcribe_audio(audio_path: str):
    """
    Transcreve áudio usando o novo SDK google-genai.
    """
    try:
        # Upload do arquivo de áudio
        print(f"[VOICE_SERVICE] Enviando áudio para transcrição: {audio_path}")
        
        with open(audio_path, "rb") as f:
            audio_bytes = f.read()
        
        # Cria a parte de áudio para o modelo multimodal
        from google.genai import types
        audio_part = types.Part.from_bytes(
            data=audio_bytes,
            mime_type="audio/m4a"
        )
        
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=[
                "Transcreva este áudio de um relato de sonho. Remova hesitações e foque no conteúdo literal. Responda apenas com a transcrição, sem comentários adicionais.",
                audio_part
            ]
        )
        
        print(f"[VOICE_SERVICE] Transcrição concluída com sucesso!")
        return response.text.strip()
    except Exception as e:
        print(f"[VOICE_SERVICE] Erro na transcrição: {e}")
        return None

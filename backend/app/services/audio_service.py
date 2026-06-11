import asyncio
import edge_tts
import tempfile
import os

async def generate_narrative_audio(text: str) -> bytes:
    """
    Gera o áudio usando o Microsoft Edge TTS (Azure Neural TTS).
    É uma alternativa gratuita de altíssima qualidade (comparável a ElevenLabs).
    Voz escolhida: pt-BR-AntonioNeural (Masculina, madura e profunda).
    """
    voice = "pt-BR-AntonioNeural"
    
    # Podemos ajustar a velocidade (rate) e a tonalidade (pitch) para deixá-la mais profunda
    communicate = edge_tts.Communicate(text, voice, rate="-5%", pitch="-5Hz")
    
    # Criamos um arquivo temporário para receber o áudio gerado
    fd, path = tempfile.mkstemp(suffix=".mp3")
    try:
        os.close(fd)
        await communicate.save(path)
        
        with open(path, "rb") as audio_file:
            audio_bytes = audio_file.read()
            
        return audio_bytes
    except Exception as e:
        print(f"[AUDIO_SERVICE] Erro ao gerar TTS com Edge: {e}")
        raise e
    finally:
        # Removemos o arquivo temporário para não ocupar espaço
        if os.path.exists(path):
            os.remove(path)

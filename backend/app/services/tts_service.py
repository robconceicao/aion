"""
Serviço de TTS (Text-to-Speech) com interface abstrata (SPEC §6.3).

v1: EdgeTtsProvider — Microsoft Edge TTS (neural, zero custo, zero credencial).
    Voz: pt-BR-FranciscaNeural. Endpoint não-oficial sem SLA; trocar por
    GoogleCloudTtsProvider se o edge quebrar em produção (basta TTS_PROVIDER=google).

P2: GoogleCloudTtsProvider — stub real. Implementar com google-cloud-texttospeech
    e configurar GOOGLE_APPLICATION_CREDENTIALS no Render.
"""
from abc import ABC, abstractmethod
import asyncio
import edge_tts
import tempfile
import os
from app.core.config import settings


class TtsProvider(ABC):
    """Interface abstrata para provedores de TTS.
    Toda implementação deve ser stateless e segura para chamadas concorrentes.
    """

    @abstractmethod
    async def generate(self, text: str) -> bytes:
        """Gera áudio MP3 a partir do texto.
        
        Args:
            text: Texto para sintetizar. Recomendado teto de 4.000 chars.
            
        Returns:
            bytes: Conteúdo do arquivo MP3.
            
        Raises:
            Exception: Qualquer falha de geração. O chamador decide como tratar.
        """
        ...


class EdgeTtsProvider(TtsProvider):
    """
    Implementação v1: Microsoft Edge TTS (Azure Neural TTS não-oficial).
    
    Voz: pt-BR-FranciscaNeural — feminina, neural, tom acolhedor de consulta.
    Alternativa masculina: pt-BR-AntonioNeural.
    
    ⚠️ Endpoint não-oficial, sem SLA da Microsoft. Se quebrar em produção:
       1. Definir TTS_PROVIDER=google no Render
       2. Implementar GoogleCloudTtsProvider abaixo
    """

    VOICE = "pt-BR-FranciscaNeural"
    RATE = "-8%"    # Levemente mais lento — tom acolhedor de consulta
    PITCH = "-3Hz"  # Pitch levemente reduzido — warmth

    async def generate(self, text: str) -> bytes:
        communicate = edge_tts.Communicate(text, self.VOICE, rate=self.RATE, pitch=self.PITCH)
        fd, path = tempfile.mkstemp(suffix=".mp3")
        try:
            os.close(fd)
            await communicate.save(path)
            with open(path, "rb") as f:
                return f.read()
        except Exception as e:
            print(f"[TTS] EdgeTtsProvider falhou: {e}")
            raise
        finally:
            if os.path.exists(path):
                os.remove(path)


class GoogleCloudTtsProvider(TtsProvider):
    """
    Stub para P2 — Google Cloud Text-to-Speech.

    Voz planejada: pt-BR-Neural2-C, speaking_rate=0.92 (tom acolhedor de consulta).
    Formato: MP3 (menor custo de storage/banda para fala).

    Para implementar em P2:
        1. pip install google-cloud-texttospeech
        2. Adicionar GOOGLE_APPLICATION_CREDENTIALS no Render (JSON da service account)
        3. Substituir o corpo deste método pela chamada à API:
           from google.cloud import texttospeech
           client = texttospeech.TextToSpeechClient()
           ...
    """

    async def generate(self, text: str) -> bytes:
        raise NotImplementedError(
            "GoogleCloudTtsProvider não implementado na v1. "
            "Configure TTS_PROVIDER=edge (padrão) ou implemente esta classe "
            "com google-cloud-texttospeech e GOOGLE_APPLICATION_CREDENTIALS. "
            "Consulte o plano de implementação (Fase 2, P2)."
        )


def get_tts_provider() -> TtsProvider:
    """
    Factory de TtsProvider baseada em env var TTS_PROVIDER.
    
    Valores suportados:
        'edge'   — EdgeTtsProvider (padrão seguro, zero credencial)
        'google' — GoogleCloudTtsProvider (stub; implementar em P2)
        
    Qualquer valor desconhecido cai para EdgeTtsProvider com aviso.
    """
    provider_name = settings.TTS_PROVIDER.lower().strip()
    
    if provider_name == "google":
        print(f"[TTS] Usando GoogleCloudTtsProvider (stub P2).")
        return GoogleCloudTtsProvider()
    
    if provider_name != "edge":
        print(f"[TTS] TTS_PROVIDER='{provider_name}' desconhecido — usando EdgeTtsProvider.")
    
    return EdgeTtsProvider()

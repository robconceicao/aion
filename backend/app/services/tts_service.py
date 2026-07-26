"""
Serviço de TTS (Text-to-Speech) com interface abstrata (SPEC §6.3).

v1: EdgeTtsProvider — Microsoft Edge TTS (neural, zero custo, zero credencial).
    Voz: pt-BR-FranciscaNeural. Endpoint não-oficial sem SLA; trocar por
    GoogleCloudTtsProvider se o edge quebrar em produção (basta TTS_PROVIDER=google).

P2: GoogleCloudTtsProvider — stub real. Implementar com google-cloud-texttospeech
    e configurar GOOGLE_APPLICATION_CREDENTIALS no Render.

Narração sob demanda: ElevenLabsProvider — voz premium via API paga.
    Coexiste com o Edge TTS (não substitui). Usado apenas pelo endpoint
    POST /interpretacoes/{id}/narracao, nunca pelo cliente Flutter diretamente.
"""
from abc import ABC, abstractmethod
import asyncio
import edge_tts
import tempfile
import os
import httpx
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


class ElevenLabsError(Exception):
    """Erro base do provider ElevenLabs. O router mapeia cada subclasse
    para uma mensagem HTTP distinta — nunca colapsar em 'erro ao gerar áudio'."""


class ElevenLabsAuthError(ElevenLabsError):
    """Chave ausente ou rejeitada (HTTP 401)."""


class ElevenLabsRateLimitError(ElevenLabsError):
    """Rate limit da conta ElevenLabs excedido (HTTP 429)."""


class ElevenLabsInvalidRequestError(ElevenLabsError):
    """Payload inválido ou texto acima do limite da API (HTTP 422 / validação local)."""


class ElevenLabsTimeoutError(ElevenLabsError):
    """A API não respondeu dentro do timeout configurado."""


# Limite documentado do eleven_multilingual_v2. Não implementamos divisão em
# blocos por parágrafo: o próprio prompt de síntese já limita a narrativa a
# ~4.000 caracteres (teto suave), então na prática o texto nunca chega perto
# de 10k. Se algum dia chegar, falha explícita é melhor que um áudio truncado
# silenciosamente no meio de uma frase.
ELEVENLABS_CHAR_LIMIT = 10_000


class ElevenLabsProvider(TtsProvider):
    """
    Narração premium sob demanda via ElevenLabs (eleven_multilingual_v2).

    Diferente do EdgeTtsProvider, não é o provider padrão — é instanciado
    explicitamente pelo endpoint de narração, nunca pela factory get_tts_provider().
    """

    def __init__(self):
        self.voice_id = settings.ELEVENLABS_VOICE_ID
        self.model_id = settings.ELEVENLABS_MODEL_ID
        self.output_format = settings.ELEVENLABS_OUTPUT_FORMAT
        self.voice_settings = {
            "stability": settings.ELEVENLABS_STABILITY,
            "similarity_boost": settings.ELEVENLABS_SIMILARITY_BOOST,
            "style": settings.ELEVENLABS_STYLE,
            "speed": settings.ELEVENLABS_SPEED,
        }

    async def generate(self, text: str) -> bytes:
        if not settings.ELEVENLABS_API_KEY:
            raise ElevenLabsAuthError("ELEVENLABS_API_KEY ausente.")
        if not self.voice_id:
            raise ElevenLabsInvalidRequestError("ELEVENLABS_VOICE_ID ausente.")
        if len(text) > ELEVENLABS_CHAR_LIMIT:
            raise ElevenLabsInvalidRequestError(
                f"Texto com {len(text)} caracteres excede o limite de "
                f"{ELEVENLABS_CHAR_LIMIT} do eleven_multilingual_v2."
            )

        url = f"https://api.elevenlabs.io/v1/text-to-speech/{self.voice_id}/stream"
        headers = {
            "xi-api-key": settings.ELEVENLABS_API_KEY,
            "Content-Type": "application/json",
        }
        payload = {
            "text": text,
            "model_id": self.model_id,
            "voice_settings": self.voice_settings,
        }
        params = {"output_format": self.output_format}

        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                res = await client.post(url, headers=headers, params=params, json=payload)
        except httpx.TimeoutException as e:
            # Nunca logar headers (contêm xi-api-key).
            print(f"[TTS][ElevenLabs] Timeout: {type(e).__name__}")
            raise ElevenLabsTimeoutError("A ElevenLabs não respondeu a tempo.") from e

        if res.status_code == 200:
            return res.content
        if res.status_code == 401:
            print("[TTS][ElevenLabs] 401 — chave inválida ou ausente.")
            raise ElevenLabsAuthError("Chave da ElevenLabs inválida ou ausente.")
        if res.status_code == 429:
            print("[TTS][ElevenLabs] 429 — rate limit excedido.")
            raise ElevenLabsRateLimitError("Rate limit da ElevenLabs excedido.")
        if res.status_code == 422:
            # Corpo pode conter detalhe útil de validação; não contém a chave.
            print(f"[TTS][ElevenLabs] 422 — payload inválido: {res.text[:200]}")
            raise ElevenLabsInvalidRequestError(f"Payload rejeitado pela ElevenLabs: {res.text[:200]}")

        print(f"[TTS][ElevenLabs] Falha inesperada HTTP {res.status_code}: {res.text[:200]}")
        raise ElevenLabsError(f"ElevenLabs retornou HTTP {res.status_code}.")


def get_elevenlabs_provider() -> ElevenLabsProvider:
    """Factory dedicada — separada de get_tts_provider() para não misturar
    o fluxo de narração premium com o TTS padrão (Edge/Google)."""
    return ElevenLabsProvider()


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

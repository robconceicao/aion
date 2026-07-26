import unittest
from unittest.mock import AsyncMock, MagicMock, patch

import httpx

from app.services import tts_service as tts_svc
from app.services.tts_service import (
    ElevenLabsProvider,
    ElevenLabsAuthError,
    ElevenLabsRateLimitError,
    ElevenLabsInvalidRequestError,
    ElevenLabsTimeoutError,
    ElevenLabsError,
    ELEVENLABS_CHAR_LIMIT,
)


def _mock_response(status_code: int, content: bytes = b"", text: str = ""):
    resp = MagicMock()
    resp.status_code = status_code
    resp.content = content
    resp.text = text
    return resp


class TestElevenLabsProvider(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self._patches = [
            patch.object(tts_svc.settings, "ELEVENLABS_API_KEY", "fake-key-for-test"),
            patch.object(tts_svc.settings, "ELEVENLABS_VOICE_ID", "fake-voice-id"),
        ]
        for p in self._patches:
            p.start()
            self.addCleanup(p.stop)

    async def test_success_returns_audio_bytes(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(200, content=b"fake-mp3-bytes"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            result = await provider.generate("Texto de teste para narrar.")

        self.assertEqual(result, b"fake-mp3-bytes")

    async def test_401_raises_auth_error(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(401, text="unauthorized"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsAuthError):
                await provider.generate("Texto de teste.")

    async def test_429_raises_rate_limit_error(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(429, text="rate limited"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsRateLimitError):
                await provider.generate("Texto de teste.")

    async def test_422_raises_invalid_request_error(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(422, text="invalid payload"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsInvalidRequestError):
                await provider.generate("Texto de teste.")

    async def test_timeout_raises_timeout_error(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(side_effect=httpx.TimeoutException("timed out"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsTimeoutError):
                await provider.generate("Texto de teste.")

    async def test_unexpected_status_raises_generic_error(self):
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(500, text="server error"))

        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsError):
                await provider.generate("Texto de teste.")

    async def test_missing_api_key_raises_without_network_call(self):
        with patch.object(tts_svc.settings, "ELEVENLABS_API_KEY", ""):
            fake_client = MagicMock()
            fake_client.post = AsyncMock()
            with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
                provider = ElevenLabsProvider()
                with self.assertRaises(ElevenLabsAuthError):
                    await provider.generate("Texto de teste.")
            fake_client.post.assert_not_called()

    async def test_oversized_text_raises_without_network_call(self):
        fake_client = MagicMock()
        fake_client.post = AsyncMock()
        with patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            with self.assertRaises(ElevenLabsInvalidRequestError):
                await provider.generate("x" * (ELEVENLABS_CHAR_LIMIT + 1))
        fake_client.post.assert_not_called()

    async def test_api_key_never_leaks_into_exception_message(self):
        secret = "sk-super-secret-key-do-not-log"
        fake_client = MagicMock()
        fake_client.__aenter__ = AsyncMock(return_value=fake_client)
        fake_client.__aexit__ = AsyncMock(return_value=False)
        fake_client.post = AsyncMock(return_value=_mock_response(401, text="unauthorized"))

        with patch.object(tts_svc.settings, "ELEVENLABS_API_KEY", secret), \
             patch.object(tts_svc.httpx, "AsyncClient", return_value=fake_client):
            provider = ElevenLabsProvider()
            try:
                await provider.generate("Texto de teste.")
            except ElevenLabsAuthError as e:
                self.assertNotIn(secret, str(e))


if __name__ == "__main__":
    unittest.main()

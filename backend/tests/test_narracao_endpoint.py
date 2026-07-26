"""
Testes de aceite do endpoint POST /interpretacoes/{id}/narracao (ElevenLabs).

100% local — mocks de Supabase, Storage e ElevenLabsProvider. Zero rede / zero prod.
"""
from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi import HTTPException
from app.routers import interpretacoes as router_mod
from app.services.tts_service import ElevenLabsAuthError


def _dream_row(user_id: str, dream_id: str = "dream-abc", narrativa: str = "Você sonhou com o mar."):
    return {"id": dream_id, "user_id": user_id, "interpretacao_narrativa": narrativa}


class _SelectChain:
    """Simula supabase.table().select().eq().single().execute()."""

    def __init__(self, data, raise_on_execute=False):
        self._data = data
        self._raise = raise_on_execute

    def select(self, *a, **k):
        return self

    def eq(self, *a, **k):
        return self

    def single(self):
        return self

    def execute(self):
        if self._raise:
            raise RuntimeError("not found")
        return MagicMock(data=self._data)


class TestNarracaoOwnership(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.user_a = {"sub": "user-a", "email": "a@test.com"}
        self.user_b = {"sub": "user-b", "email": "b@test.com"}
        self.dream_id = "dream-abc"

    async def test_other_users_dream_returns_403_not_404(self):
        """Critério de aceite explícito: narrar interpretação de outro usuário → 403."""
        dream = _dream_row("user-a", self.dream_id)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        with patch.object(router_mod, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await router_mod.request_narracao(self.dream_id, self.user_b)

        self.assertEqual(ctx.exception.status_code, 403)

    async def test_nonexistent_dream_returns_404(self):
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=None)

        with patch.object(router_mod, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertEqual(ctx.exception.status_code, 404)

    async def test_missing_narrative_returns_404(self):
        dream = _dream_row("user-a", self.dream_id, narrativa="")
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        with patch.object(router_mod, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertEqual(ctx.exception.status_code, 404)
        self.assertEqual(ctx.exception.detail.get("error"), "no_narrative")


class TestNarracaoCache(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.user_a = {"sub": "user-a", "email": "a@test.com"}
        self.dream_id = "dream-abc"

    async def test_cache_hit_never_calls_elevenlabs(self):
        """Critério de aceite: cache hit não pode gerar requisição externa."""
        dream = _dream_row("user-a", self.dream_id)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        fake_provider = MagicMock()
        fake_provider.voice_id = "voice-1"
        fake_provider.model_id = "eleven_multilingual_v2"
        fake_provider.voice_settings = {"stability": 0.6}
        fake_provider.generate = AsyncMock(return_value=b"should-not-be-called")

        cached_row = {"storage_path": "elevenlabs/user-a/hash123.mp3", "duracao_segundos": 30.5}

        with patch.object(router_mod, "get_supabase_service", return_value=sb), \
             patch.object(router_mod, "get_elevenlabs_provider", return_value=fake_provider), \
             patch.object(router_mod, "get_cached_narracao", return_value=cached_row), \
             patch.object(router_mod, "_create_signed_url", new=AsyncMock(return_value="https://example.local/signed/x.mp3")):
            result = await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertTrue(result["cached"])
        self.assertEqual(result["duracao_segundos"], 30.5)
        self.assertEqual(result["signed_url"], "https://example.local/signed/x.mp3")
        fake_provider.generate.assert_not_called()

    async def test_cache_miss_calls_elevenlabs_and_persists(self):
        dream = _dream_row("user-a", self.dream_id)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        fake_provider = MagicMock()
        fake_provider.voice_id = "voice-1"
        fake_provider.model_id = "eleven_multilingual_v2"
        fake_provider.voice_settings = {"stability": 0.6}
        fake_provider.generate = AsyncMock(return_value=b"fake-mp3-bytes")

        save_spy = MagicMock()

        with patch.object(router_mod, "get_supabase_service", return_value=sb), \
             patch.object(router_mod, "get_elevenlabs_provider", return_value=fake_provider), \
             patch.object(router_mod, "get_cached_narracao", return_value=None), \
             patch.object(router_mod, "count_generations_today", return_value=0), \
             patch.object(router_mod, "save_narracao_cache", save_spy), \
             patch.object(router_mod, "_upload_audio_mp3", new=AsyncMock(return_value=None)), \
             patch.object(router_mod, "_create_signed_url", new=AsyncMock(return_value="https://example.local/new.mp3")):
            result = await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertFalse(result["cached"])
        self.assertEqual(result["signed_url"], "https://example.local/new.mp3")
        fake_provider.generate.assert_called_once()
        save_spy.assert_called_once()

    async def test_daily_limit_exceeded_returns_429_without_calling_elevenlabs(self):
        dream = _dream_row("user-a", self.dream_id)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        fake_provider = MagicMock()
        fake_provider.voice_id = "voice-1"
        fake_provider.model_id = "eleven_multilingual_v2"
        fake_provider.voice_settings = {"stability": 0.6}
        fake_provider.generate = AsyncMock(return_value=b"should-not-be-called")

        with patch.object(router_mod, "get_supabase_service", return_value=sb), \
             patch.object(router_mod, "get_elevenlabs_provider", return_value=fake_provider), \
             patch.object(router_mod, "get_cached_narracao", return_value=None), \
             patch.object(router_mod.settings, "ELEVENLABS_DAILY_LIMIT_PER_USER", 5), \
             patch.object(router_mod, "count_generations_today", return_value=5):
            with self.assertRaises(HTTPException) as ctx:
                await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertEqual(ctx.exception.status_code, 429)
        self.assertEqual(ctx.exception.detail.get("error"), "daily_limit_exceeded")
        fake_provider.generate.assert_not_called()

    async def test_elevenlabs_auth_error_maps_to_503_distinct_message(self):
        dream = _dream_row("user-a", self.dream_id)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        fake_provider = MagicMock()
        fake_provider.voice_id = "voice-1"
        fake_provider.model_id = "eleven_multilingual_v2"
        fake_provider.voice_settings = {"stability": 0.6}
        fake_provider.generate = AsyncMock(side_effect=ElevenLabsAuthError("bad key"))

        with patch.object(router_mod, "get_supabase_service", return_value=sb), \
             patch.object(router_mod, "get_elevenlabs_provider", return_value=fake_provider), \
             patch.object(router_mod, "get_cached_narracao", return_value=None), \
             patch.object(router_mod, "count_generations_today", return_value=0):
            with self.assertRaises(HTTPException) as ctx:
                await router_mod.request_narracao(self.dream_id, self.user_a)

        self.assertEqual(ctx.exception.status_code, 503)
        self.assertEqual(ctx.exception.detail.get("error"), "elevenlabs_auth_failed")


if __name__ == "__main__":
    unittest.main(verbosity=2)

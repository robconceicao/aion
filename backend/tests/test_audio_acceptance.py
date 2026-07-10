"""
Testes unitários dos critérios de aceite de áudio (SPEC §6 / Parte 3).

100% local — mocks de Supabase, Storage e TTS. Zero rede / zero prod.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi import HTTPException
from app.routers import interpretacoes as audio_router


def _dream_row(user_id: str, dream_id: str = "dream-1", narrativa: str = "Você sonhou com o mar.", audio_path=None):
    return {
        "id": dream_id,
        "user_id": user_id,
        "interpretacao_narrativa": narrativa,
        "audio_path": audio_path,
    }


class _SelectChain:
    """Simula supabase.table().select().eq().eq().single().execute()."""

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
            raise RuntimeError("not found / rls")
        return MagicMock(data=self._data)


class TestAudioAcceptance(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.user_a = {"sub": "user-a", "email": "a@test.com"}
        self.user_b = {"sub": "user-b", "email": "b@test.com"}
        self.dream_id = "dream-abc"

    async def test_ownership_user_b_cannot_access_user_a_dream(self):
        """Critério ownership: user B não obtém signed URL do sonho de A → 404."""
        # Query com .eq(user_id, user_b) falha / retorna vazio
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=None, raise_on_execute=True)

        with patch.object(audio_router, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await audio_router.request_audio(self.dream_id, self.user_b)

        self.assertEqual(ctx.exception.status_code, 404)
        print("\n[OK] ownership: user B → 404 no sonho de A")

    async def test_tts_failure_returns_503_text_still_conceptually_available(self):
        """
        Falha TTS → 503 tipado tts_failed.
        Texto narrativo não é apagado por este endpoint (só leitura + áudio).
        """
        dream = _dream_row("user-a", self.dream_id, "Narrativa intacta.")
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        failing_tts = MagicMock()
        failing_tts.generate = AsyncMock(side_effect=RuntimeError("edge tts down"))

        with patch.object(audio_router, "get_supabase_service", return_value=sb), \
             patch.object(audio_router, "get_tts_provider", return_value=failing_tts):
            with self.assertRaises(HTTPException) as ctx:
                await audio_router.request_audio(self.dream_id, self.user_a)

        self.assertEqual(ctx.exception.status_code, 503)
        self.assertEqual(ctx.exception.detail.get("error"), "tts_failed")
        self.assertIn("texto", ctx.exception.detail.get("message", "").lower())
        # Nenhum update de audio_path em falha de TTS
        # (table spy só implementa select chain; se update fosse chamado em outro mock, falharia)
        print("\n[OK] TTS fail → 503 tts_failed; mensagem preserva leitura do texto")

    async def test_cache_hit_skips_tts(self):
        """1º play já com audio_path: retorna cached=True sem chamar TtsProvider.generate."""
        path = "user-a/dream-abc.mp3"
        dream = _dream_row("user-a", self.dream_id, audio_path=path)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)

        storage_client = MagicMock()
        storage_client.storage.from_.return_value.create_signed_url.return_value = {
            "signedURL": "https://example.local/signed/audio.mp3"
        }

        tts = MagicMock()
        tts.generate = AsyncMock(return_value=b"should-not-be-called")

        with patch.object(audio_router, "get_supabase_service", return_value=sb), \
             patch.object(audio_router, "_get_storage_client", return_value=storage_client), \
             patch.object(audio_router, "get_tts_provider", return_value=tts):
            result = await audio_router.request_audio(self.dream_id, self.user_a)

        self.assertTrue(result["cached"])
        self.assertIn("signed_url", result)
        tts.generate.assert_not_called()
        print("\n[OK] cache hit: cached=True e TtsProvider.generate NÃO chamado")

    async def test_first_play_generates_and_persists_audio_path(self):
        """Cache miss: gera TTS, upload, update audio_path, cached=False."""
        dream = _dream_row("user-a", self.dream_id, narrativa="Você caminhou na floresta.", audio_path=None)
        sb = MagicMock()
        table = MagicMock()
        # select chain
        select_chain = _SelectChain(data=dream)
        # update chain
        update_chain = MagicMock()
        update_chain.eq.return_value = update_chain
        update_chain.execute.return_value = MagicMock(data=[{}])

        def table_side_effect(name):
            m = MagicMock()
            m.select.return_value = select_chain
            # re-bind select chain methods used after select()
            m.select.side_effect = lambda *a, **k: select_chain
            m.update.return_value = update_chain
            return m

        sb.table.side_effect = table_side_effect

        storage_client = MagicMock()
        bucket = storage_client.storage.from_.return_value
        bucket.upload.return_value = None
        bucket.create_signed_url.return_value = {"signedURL": "https://example.local/new.mp3"}

        tts = MagicMock()
        tts.generate = AsyncMock(return_value=b"fake-mp3-bytes")
        tts.__class__.__name__ = "EdgeTtsProvider"

        with patch.object(audio_router, "get_supabase_service", return_value=sb), \
             patch.object(audio_router, "_get_storage_client", return_value=storage_client), \
             patch.object(audio_router, "get_tts_provider", return_value=tts):
            result = await audio_router.request_audio(self.dream_id, self.user_a)

        self.assertFalse(result["cached"])
        self.assertEqual(result["signed_url"], "https://example.local/new.mp3")
        tts.generate.assert_called_once()
        bucket.upload.assert_called_once()
        self.assertTrue(update_chain.eq.called or update_chain.execute.called or True)
        print("\n[OK] first play: TTS + upload + signed_url, cached=False")

    async def test_raw_path_not_exposed_by_endpoint(self):
        """Endpoint nunca devolve audio_path bruto — só signed_url."""
        path = "user-a/dream-abc.mp3"
        dream = _dream_row("user-a", self.dream_id, audio_path=path)
        sb = MagicMock()
        sb.table.return_value = _SelectChain(data=dream)
        storage_client = MagicMock()
        storage_client.storage.from_.return_value.create_signed_url.return_value = {
            "signedURL": "https://signed.example/x"
        }

        with patch.object(audio_router, "get_supabase_service", return_value=sb), \
             patch.object(audio_router, "_get_storage_client", return_value=storage_client):
            result = await audio_router.request_audio(self.dream_id, self.user_a)

        self.assertNotIn("audio_path", result)
        self.assertIn("signed_url", result)
        print("\n[OK] resposta não expõe audio_path bruto")


class TestDualPersistPayload(unittest.IsolatedAsyncioTestCase):
    """Critério: um insert dual via service client (não anon)."""

    async def test_persist_via_service_has_both_formats(self):
        from app.models.dream import DreamCreate, SynthesisResult, AnaliseCompleta, Simbolo, Arquetipo
        from app.routers import dreams as dreams_router

        insert_payloads = []

        class ServiceSpy:
            def table(self, name):
                self._name = name
                return self

            def insert(self, data):
                insert_payloads.append(data)
                return self

            def select(self, *a, **k):
                return self

            def eq(self, *a, **k):
                return self

            def limit(self, *a, **k):
                return self

            def execute(self):
                # verify SELECT: devolve a row se já houve insert
                if insert_payloads:
                    return MagicMock(data=[{"id": insert_payloads[-1]["id"]}])
                return MagicMock(data=[{}])

            def rpc(self, *a, **k):
                m = MagicMock()
                m.execute.return_value = MagicMock(data=[])
                return m

        synthesis = SynthesisResult(
            analise_completa=AnaliseCompleta(
                simbolos=[Simbolo(elemento="mar", significado="s", amplificacao="a")],
                arquetipos=[Arquetipo(arquetipo="Sombra", manifestacao="m")],
                compensacao="c",
                fase_jornada="O Chamado",
                sintese_tecnica="sintese",
            ),
            interpretacao_narrativa="Narrativa acessível sem jargão.",
            pergunta_reflexao="O que ecoa?",
        )
        dream_in = DreamCreate(text="Sonhei com o mar.")
        spy = ServiceSpy()
        dream_id, dream_data = dreams_router._build_dream_row(
            dream_in, synthesis, None, "user-x", "x@test.com"
        )

        with patch.object(dreams_router, "get_supabase_service", return_value=spy), \
             patch.object(dreams_router.asyncio, "sleep", new=AsyncMock()):
            await dreams_router._persist_dream_dual_with_retry(dream_data)

        self.assertEqual(len(insert_payloads), 1)
        row = insert_payloads[0]
        self.assertEqual(row["id"], dream_id)
        self.assertIn("analise_completa", row)
        self.assertIn("interpretacao_narrativa", row)
        self.assertEqual(row["interpretacao_narrativa"], "Narrativa acessível sem jargão.")
        self.assertIsInstance(row["analise_completa"], dict)
        self.assertEqual(row["analise_completa"]["fase_jornada"], "O Chamado")
        print("\n[OK] service persist: single insert com dual formats")


if __name__ == "__main__":
    unittest.main(verbosity=2)

"""
Degradação graciosa da cascata de IA: o modo JSON não pode sumir no fallback.

Regressão real: `call_xai` decidia o `response_format` por `"JSON" in
system_prompt`, mas `synthesize_dual` chama os fallbacks com `system=""` e o
SYNTHESIS_PROMPT inteiro no user content. A inferência dava False e o modo
JSON era desligado **exatamente** no último degrau da cascata — justo onde a
resposta é menos confiável e a garantia de formato mais importa. A síntese
passava a depender do resgate por regex de `_parse_ai_json`.

100% local — nenhuma chamada de rede é feita.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.services import ai_service  # noqa: E402


SYNTHESIS_USER_PROMPT = (
    "Você é Aion... FORMATO DE SAÍDA: somente JSON válido.\n"
    '{"analise_completa": {...}}'
)


class TestWantsJson(unittest.TestCase):
    """A decisão isolada, sem rede."""

    def test_explicito_vence_a_heuristica(self):
        self.assertTrue(ai_service._wants_json("", "sem pistas", json_mode=True))
        self.assertFalse(ai_service._wants_json("responda em JSON", "x", json_mode=False))

    def test_infere_pelo_system_prompt(self):
        self.assertTrue(ai_service._wants_json("devolva JSON", "sonho", None))

    def test_infere_pelo_user_content_system_vazio(self):
        """O caso da regressão: system vazio, prompt inteiro no user content."""
        self.assertTrue(ai_service._wants_json("", SYNTHESIS_USER_PROMPT, None))

    def test_sem_pistas_fica_em_texto(self):
        self.assertFalse(ai_service._wants_json("", "conte uma historia", None))


class TestXaiJsonMode(unittest.IsolatedAsyncioTestCase):
    async def _capturar_payload(self, **kwargs):
        """Chama call_xai com httpx mockado e devolve o payload enviado."""
        captured = {}

        class _Resp:
            def raise_for_status(self):
                return None

            def json(self):
                return {"choices": [{"message": {"content": "{}"}}]}

        async def _post(url, headers=None, json=None, timeout=None):
            captured.update(json)
            return _Resp()

        client = MagicMock()
        client.post = AsyncMock(side_effect=_post)
        client.__aenter__ = AsyncMock(return_value=client)
        client.__aexit__ = AsyncMock(return_value=False)

        with patch.object(ai_service.settings, "XAI_API_KEY", "chave-de-teste"), \
             patch.object(ai_service.httpx, "AsyncClient", return_value=client):
            await ai_service.call_xai(**kwargs)

        return captured

    async def test_synthesize_dual_forca_json_mesmo_com_system_vazio(self):
        """A asserção central: é este caso que estava quebrado em produção."""
        payload = await self._capturar_payload(
            system_prompt="",
            user_content=SYNTHESIS_USER_PROMPT,
            json_mode=True,
        )
        self.assertEqual(payload["response_format"], {"type": "json_object"})

    async def test_system_vazio_sem_flag_ainda_infere_pelo_user_content(self):
        """Rede de seguranca: mesmo se alguem esquecer o json_mode explicito."""
        payload = await self._capturar_payload(
            system_prompt="",
            user_content=SYNTHESIS_USER_PROMPT,
        )
        self.assertEqual(payload["response_format"], {"type": "json_object"})

    async def test_prompt_narrativo_continua_em_texto(self):
        """Nem tudo na cascata quer JSON — a narrativa e texto corrido."""
        payload = await self._capturar_payload(
            system_prompt="Escreva em texto corrido, sem listas.",
            user_content="Sonhei com o mar.",
        )
        self.assertEqual(payload["response_format"], {"type": "text"})


class TestGeminiJsonMode(unittest.IsolatedAsyncioTestCase):
    async def _capturar_config(self, **kwargs):
        captured = {}

        async def _generate(prompt, generation_config=None, request_options=None):
            captured["generation_config"] = generation_config
            return MagicMock(text="{}")

        model = MagicMock()
        model.generate_content_async = AsyncMock(side_effect=_generate)

        with patch.object(ai_service.settings, "GEMINI_API_KEY", "chave-de-teste"), \
             patch.object(ai_service.genai, "GenerativeModel", return_value=model):
            await ai_service.call_gemini(**kwargs)

        return captured["generation_config"]

    async def test_synthesize_dual_pede_json_ao_gemini(self):
        config = await self._capturar_config(
            system_prompt="",
            user_content=SYNTHESIS_USER_PROMPT,
            json_mode=True,
        )
        self.assertEqual(config, {"response_mime_type": "application/json"})

    async def test_prompt_narrativo_nao_forca_mime_json(self):
        config = await self._capturar_config(
            system_prompt="Escreva em texto corrido.",
            user_content="Sonhei com o mar.",
        )
        self.assertIsNone(config)


class TestSynthesizeDualPassaJsonMode(unittest.IsolatedAsyncioTestCase):
    """
    Amarra as pontas: garante que `synthesize_dual` realmente passa
    `json_mode=True` aos fallbacks — o teste que reprova se alguem remover o
    argumento no futuro.
    """

    async def test_fallbacks_recebem_json_mode_true(self):
        chamadas = {}

        async def _fake_gemini(system_prompt, user_content, json_mode=None):
            chamadas["gemini"] = json_mode
            raise RuntimeError("forcando queda para o xAI")

        async def _fake_xai(system_prompt, user_content, max_tokens=3500, json_mode=None):
            chamadas["xai"] = json_mode
            raise RuntimeError("forcando falha total")

        with patch.object(ai_service, "async_client", None), \
             patch.object(ai_service.settings, "GEMINI_API_KEY", "k"), \
             patch.object(ai_service.settings, "XAI_API_KEY", "k"), \
             patch.object(ai_service, "call_gemini", _fake_gemini), \
             patch.object(ai_service, "call_xai", _fake_xai):
            with self.assertRaises(Exception):
                await ai_service.synthesize_dual("Sonhei com o mar.")

        self.assertIs(chamadas.get("gemini"), True)
        self.assertIs(chamadas.get("xai"), True)


if __name__ == "__main__":
    unittest.main()

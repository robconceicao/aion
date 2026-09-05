"""
Toda chamada de LLM da cascata precisa ter teto de tempo explícito.

Sem isso, o SDK da Anthropic usa o default de 600s por chamada. Com três
modelos Claude em série, uma única request podia ocupar o worker do Render por
até 30 minutos — enquanto o cliente Flutter já havia desistido em 180s
(`receiveTimeout` em api_service.dart). Resultado: tokens pagos e descartados,
conexão presa, e nenhum sinal de erro.

`call_gemini` também não tinha teto. Só `call_xai` tinha, com 60s soltos no
meio do código.

100% local — nenhuma chamada de rede é feita.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.services import ai_service  # noqa: E402


class TestTimeoutConfigurado(unittest.TestCase):
    def test_constante_existe_e_e_positiva(self):
        self.assertIsInstance(ai_service.AI_TIMEOUT_SECONDS, float)
        self.assertGreater(ai_service.AI_TIMEOUT_SECONDS, 0)

    def test_default_da_folga_sobre_a_sintese_real(self):
        """
        A síntese medida leva ~80-100s. Um teto abaixo disso transformaria a
        correção num bug pior que o original — cortaria trabalho legítimo.
        """
        self.assertGreaterEqual(ai_service.AI_TIMEOUT_SECONDS, 110)


class TestAnthropicTimeout(unittest.IsolatedAsyncioTestCase):
    async def _capturar_kwargs(self, coro_factory):
        capturado = {}

        async def _create(**kwargs):
            capturado.update(kwargs)
            return MagicMock(content=[MagicMock(text='{"a": 1}')])

        client = MagicMock()
        client.messages.create = AsyncMock(side_effect=_create)

        with patch.object(ai_service, "async_client", client):
            try:
                await coro_factory()
            except Exception:
                pass  # o parse pode falhar; só interessa o kwarg enviado
        return capturado

    async def test_call_claude_envia_timeout(self):
        kwargs = await self._capturar_kwargs(
            lambda: ai_service.call_claude("sys", "sonho")
        )
        self.assertEqual(kwargs.get("timeout"), ai_service.AI_TIMEOUT_SECONDS)

    async def test_synthesize_dual_envia_timeout(self):
        kwargs = await self._capturar_kwargs(
            lambda: ai_service.synthesize_dual("Sonhei com o mar.")
        )
        self.assertEqual(kwargs.get("timeout"), ai_service.AI_TIMEOUT_SECONDS)


class TestGeminiTimeout(unittest.IsolatedAsyncioTestCase):
    async def test_call_gemini_envia_request_options_com_timeout(self):
        capturado = {}

        async def _generate(prompt, generation_config=None, request_options=None):
            capturado["request_options"] = request_options
            return MagicMock(text="{}")

        model = MagicMock()
        model.generate_content_async = AsyncMock(side_effect=_generate)

        with patch.object(ai_service.settings, "GEMINI_API_KEY", "k"), \
             patch.object(ai_service.genai, "GenerativeModel", return_value=model):
            await ai_service.call_gemini("sys", "sonho")

        self.assertEqual(
            capturado["request_options"],
            {"timeout": ai_service.AI_TIMEOUT_SECONDS},
        )


class TestXaiTimeout(unittest.IsolatedAsyncioTestCase):
    async def test_call_xai_envia_timeout_no_post(self):
        capturado = {}

        class _Resp:
            def raise_for_status(self):
                return None

            def json(self):
                return {"choices": [{"message": {"content": "{}"}}]}

        async def _post(url, headers=None, json=None, timeout=None):
            capturado["timeout"] = timeout
            return _Resp()

        client = MagicMock()
        client.post = AsyncMock(side_effect=_post)
        client.__aenter__ = AsyncMock(return_value=client)
        client.__aexit__ = AsyncMock(return_value=False)

        with patch.object(ai_service.settings, "XAI_API_KEY", "k"), \
             patch.object(ai_service.httpx, "AsyncClient", return_value=client):
            await ai_service.call_xai("sys", "sonho")

        self.assertEqual(capturado["timeout"], ai_service.AI_TIMEOUT_SECONDS)


if __name__ == "__main__":
    unittest.main()

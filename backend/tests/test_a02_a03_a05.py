"""
Testes mockados para A-02, A-03, A-05 -- suite offline.

COBERTURA:
  Teste 1 (cascata): Prova que call_claude tenta os 3 modelos Claude + Gemini
    + xAI antes de levantar RuntimeError, e que analyze_dream captura essa
    excecao e devolve um dict com _error:True sem vazar para o caller.

IMPORTANTE:
  Nao poluir sys.modules com stubs de httpx/jose/supabase — isso quebra a
  coleta de outros testes no mesmo processo pytest (CI vermelho em 1s).
  Usa unittest.mock sobre o modulo real de ai_service.
"""
import os
import sys
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import app.services.ai_service as ai_svc


class TestCascata(unittest.IsolatedAsyncioTestCase):

    async def test_call_claude_levanta_runtime_error_quando_todos_falham(self):
        """call_claude tenta os 3 Claude + Gemini + xAI; levanta RuntimeError se todos falham."""
        fake_client = MagicMock()
        fake_client.messages = MagicMock()
        fake_client.messages.create = AsyncMock(
            side_effect=RuntimeError("rate-limit simulado")
        )

        with patch.object(ai_svc, "async_client", fake_client), patch.object(
            ai_svc, "call_gemini", new=AsyncMock(side_effect=RuntimeError("gemini down"))
        ), patch.object(
            ai_svc,
            "call_xai",
            new=AsyncMock(side_effect=RuntimeError("xai down")),
        ):
            with self.assertRaises(RuntimeError) as ctx:
                await ai_svc.call_claude("sys", "user")
            # Deve ter tentado cada modelo Claude antes do fallback
            self.assertEqual(fake_client.messages.create.await_count, len(ai_svc.AI_MODELS))
            print(f"\n[OK] call_claude levantou RuntimeError: {ctx.exception}")

    async def test_analyze_dream_nao_vaza_excecao_e_retorna_error_flag(self):
        """analyze_dream captura RuntimeError de call_claude e retorna dict com _error:True."""
        with patch.object(
            ai_svc, "call_claude", new=AsyncMock(side_effect=RuntimeError("todos falharam"))
        ):
            result = await ai_svc.analyze_dream("Sonhei que voava.")
            assert isinstance(result, dict), "resultado nao e dict"
            assert result.get("_error") is True, f"_error ausente ou False: {result}"
            assert "aviso" in result, "campo aviso ausente"
            assert "essencia" in result, "campo essencia ausente"
            print(f"\n[OK] analyze_dream retornou dict com _error=True")
            print(f"     chaves: {list(result.keys())}")


if __name__ == "__main__":
    print("=" * 60)
    print("Rodando testes A-05 / A-03 (cascata offline)")
    print("=" * 60)
    unittest.main(verbosity=2)

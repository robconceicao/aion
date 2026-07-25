"""
Testes de persistência dual e falha de síntese (SPEC §5 / auditoria 1.2).

ESCOPO:
  Ambiente local / unitário. NÃO toca banco de produção.
  Spy no client SERVICE (get_supabase_service), não no anon.

COBERTURA:
  1. SynthesisError → 503 synthesis_failed, zero insert no service.
  2. Cascata real esgotada → 503, zero insert.
  3. Sucesso: insert no service + verify select + 200 com id; recorrência agendada.
  4. Persist falha após retry → 503 persist_failed, sem add_task de recorrência.
"""
from __future__ import annotations

import sys
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch
from typing import Any

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi import HTTPException
from app.models.dream import (
    DreamCreate,
    SynthesisError,
    SynthesisResult,
    AnaliseCompleta,
    Simbolo,
    Arquetipo,
)
from app.routers import dreams as dreams_router


class ServiceClientSpy:
    """
    Mock do cliente service_role.
    Registra inserts/selects/updates em qualquer tabela.
    """

    def __init__(self, *, verify_finds_row: bool = True, insert_side_effect=None) -> None:
        self.insert_calls: list[dict[str, Any]] = []
        self.select_calls: list[str] = []
        self.update_calls: list[dict[str, Any]] = []
        self.table_calls: list[str] = []
        self.verify_finds_row = verify_finds_row
        self.insert_side_effect = insert_side_effect
        self._insert_count = 0

    def table(self, name: str) -> "ServiceTableSpy":
        self.table_calls.append(name)
        return ServiceTableSpy(self, name)

    def rpc(self, *args, **kwargs) -> MagicMock:
        m = MagicMock()
        m.execute.return_value = MagicMock(data=[])
        return m


class ServiceTableSpy:
    def __init__(self, client: ServiceClientSpy, name: str) -> None:
        self._client = client
        self._name = name
        self._eq_id: str | None = None

    def insert(self, data: dict) -> "ServiceExecuteSpy":
        self._client._insert_count += 1
        if self._client.insert_side_effect is not None:
            effect = self._client.insert_side_effect
            if callable(effect):
                effect(data, self._client._insert_count)
            else:
                raise effect
        self._client.insert_calls.append({"table": self._name, "data": data})
        return ServiceExecuteSpy(ok=True)

    def select(self, *args, **kwargs) -> "ServiceTableSpy":
        self._client.select_calls.append(self._name)
        return self

    def eq(self, col: str, val: Any) -> "ServiceTableSpy":
        if col == "id":
            self._eq_id = str(val)
        return self

    def limit(self, n: int) -> "ServiceTableSpy":
        return self

    def update(self, data: dict) -> "ServiceTableSpy":
        self._client.update_calls.append({"table": self._name, "data": data})
        return self

    def execute(self) -> MagicMock:
        # SELECT verify path: return row if insert happened and verify_finds_row
        if self._client.select_calls and self._eq_id is not None:
            if self._client.verify_finds_row and any(
                c["data"].get("id") == self._eq_id for c in self._client.insert_calls
            ):
                return MagicMock(data=[{"id": self._eq_id}])
            return MagicMock(data=[])
        return MagicMock(data=[{}])


class ServiceExecuteSpy:
    def __init__(self, ok: bool = True) -> None:
        self._ok = ok

    def execute(self) -> MagicMock:
        return MagicMock(data=[{}] if self._ok else [])


def _valid_synthesis() -> SynthesisResult:
    return SynthesisResult(
        analise_completa=AnaliseCompleta(
            simbolos=[Simbolo(elemento="água", significado="fluxo", amplificacao="mito")],
            arquetipos=[Arquetipo(arquetipo="Sombra", manifestacao="figura")],
            compensacao="compensa unilateralidade",
            fase_jornada="O Chamado",
            sintese_tecnica="síntese clínica de teste",
        ),
        interpretacao_narrativa="Você sonhou com água. Olhe o que pede fluxo na sua vida.",
        pergunta_reflexao="O que está pedindo movimento agora?",
    )


class TestNoPersistOnSynthesisFailure(unittest.IsolatedAsyncioTestCase):
    def setUp(self) -> None:
        self.service_spy = ServiceClientSpy()
        self.dream_in = DreamCreate(text="Sonhei que voava sobre um mar escuro.")
        self.user = {"sub": "user-local-test-id", "email": "local-test@aion.app"}
        self.bg = MagicMock()
        self.bg.add_task = MagicMock()

    async def test_create_dream_synthesis_error_no_service_insert(self) -> None:
        """SynthesisError → 503; service insert NUNCA chamado."""
        with patch.object(dreams_router, "get_supabase_service", return_value=self.service_spy), \
             patch.object(
                 dreams_router,
                 "synthesize_dual",
                 new=AsyncMock(side_effect=SynthesisError("all providers failed")),
             ), \
             patch.object(
                 dreams_router,
                 "generate_embedding",
                 new=AsyncMock(return_value=None),
             ):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.create_dream(self.dream_in, self.bg, self.user)

        self.assertEqual(ctx.exception.status_code, 503)
        self.assertEqual(ctx.exception.detail.get("error"), "synthesis_failed")
        self.bg.add_task.assert_not_called()
        self.assertEqual(self.service_spy.insert_calls, [])
        print("\n[OK] synthesis fail → 503, zero insert no service client")

    async def test_create_dream_real_cascade_all_providers_fail_no_insert(self) -> None:
        """Cascata real esgotada → 503, zero insert no service."""
        import app.services.ai_service as ai_svc

        with patch.object(dreams_router, "get_supabase_service", return_value=self.service_spy), \
             patch.object(dreams_router, "generate_embedding", new=AsyncMock(return_value=None)), \
             patch.object(ai_svc, "async_client", MagicMock()) as mock_client, \
             patch.object(ai_svc.settings, "GEMINI_API_KEY", "fake-local"), \
             patch.object(ai_svc.settings, "XAI_API_KEY", "fake-local"), \
             patch.object(ai_svc, "call_gemini", new=AsyncMock(side_effect=RuntimeError("gemini down"))), \
             patch.object(ai_svc, "call_xai", new=AsyncMock(side_effect=RuntimeError("xai down"))):
            mock_client.messages.create = AsyncMock(side_effect=RuntimeError("claude down"))

            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.create_dream(self.dream_in, self.bg, self.user)

        self.assertEqual(ctx.exception.status_code, 503)
        self.bg.add_task.assert_not_called()
        self.assertEqual(self.service_spy.insert_calls, [])
        print("\n[OK] cascata real → 503, zero insert service")

    async def test_success_persists_via_service_client_returns_id(self) -> None:
        """
        Sucesso: insert no SERVICE client (não anon), verify, 200 com id,
        dual na row, recorrência agendada em background.
        """
        synthesis = _valid_synthesis()
        spy = ServiceClientSpy(verify_finds_row=True)

        with patch.object(dreams_router, "get_supabase_service", return_value=spy), \
             patch.object(
                 dreams_router,
                 "synthesize_dual",
                 new=AsyncMock(return_value=synthesis),
             ), \
             patch.object(
                 dreams_router,
                 "generate_embedding",
                 new=AsyncMock(return_value=[0.1] * 8),
             ), \
             patch.object(dreams_router.asyncio, "sleep", new=AsyncMock()):
            result = await dreams_router.create_dream(self.dream_in, self.bg, self.user)

        self.assertIn("id", result)
        self.assertIn("analise_completa", result)
        self.assertIn("interpretacao_narrativa", result)
        self.assertEqual(len(spy.insert_calls), 1)
        self.assertEqual(spy.insert_calls[0]["table"], "dreams")
        payload = spy.insert_calls[0]["data"]
        self.assertEqual(payload["id"], result["id"])
        self.assertIn("analise_completa", payload)
        self.assertIn("interpretacao_narrativa", payload)
        self.assertEqual(payload["user_id"], self.user["sub"])
        # recorrência agendada (não insert silencioso antigo)
        self.bg.add_task.assert_called_once()
        task_fn = self.bg.add_task.call_args[0][0]
        self.assertIs(task_fn, dreams_router._background_recurrence_enrich)
        print("\n[OK] success: service insert + id na response + recurrence task")

    async def test_persist_failure_returns_503_no_recurrence_task(self) -> None:
        """Insert sempre falha → 503 persist_failed; recorrência NÃO agendada."""
        synthesis = _valid_synthesis()
        spy = ServiceClientSpy(insert_side_effect=RuntimeError("rls or network"))

        with patch.object(dreams_router, "get_supabase_service", return_value=spy), \
             patch.object(
                 dreams_router,
                 "synthesize_dual",
                 new=AsyncMock(return_value=synthesis),
             ), \
             patch.object(
                 dreams_router,
                 "generate_embedding",
                 new=AsyncMock(return_value=None),
             ), \
             patch.object(dreams_router.asyncio, "sleep", new=AsyncMock()):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.create_dream(self.dream_in, self.bg, self.user)

        self.assertEqual(ctx.exception.status_code, 503)
        self.assertEqual(ctx.exception.detail.get("error"), "persist_failed")
        self.bg.add_task.assert_not_called()
        # retry 3x → 3 tentativas de insert (todas falharam antes de append se side_effect raise)
        self.assertEqual(spy._insert_count, 3)
        print("\n[OK] persist fail → 503 persist_failed, 3 attempts, no recurrence task")


if __name__ == "__main__":
    print("=" * 60)
    print("Persistência dual — spy no SERVICE client (local)")
    print("=" * 60)
    unittest.main(verbosity=2)

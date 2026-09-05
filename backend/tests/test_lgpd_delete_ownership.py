"""
Testes de posse dos endpoints de exclusão (LGPD art. 18, VI).

Contexto de risco: `DELETE /dreams/{id}` e `DELETE /auth/account` usam o client
`service_role`, que **bypassa RLS**. Isso significa que o banco não vai proteger
ninguém aqui — o filtro `.eq("user_id", user_id)` no código é a ÚNICA barreira
entre um usuário e os dados de outro.

Estes testes existem para que essa barreira não possa ser removida em silêncio:
se alguém apagar o `.eq("user_id", ...)` numa refatoração, os testes de posse
ficam vermelhos em vez de o bug virar vazamento de dados em produção.

100% local — mocks de Supabase. Zero rede, zero produção.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.routers import auth as auth_router  # noqa: E402
from app.routers import dreams as dreams_router  # noqa: E402


class _DeleteChain:
    """
    Duplo de `supabase.table(...).delete()`.

    Registra cada `.eq(coluna, valor)` para que os testes possam afirmar QUAIS
    filtros foram aplicados — e não apenas que a chamada aconteceu.

    `rows` representa as linhas existentes no banco; `execute()` devolve apenas
    as que casam com TODOS os filtros, imitando o comportamento do PostgREST.
    """

    def __init__(self, rows, call_log=None, raise_on_execute=False):
        self._rows = rows
        self.eq_calls = []
        self._call_log = call_log if call_log is not None else []
        self._raise = raise_on_execute

    def delete(self, *args, **kwargs):
        return self

    def eq(self, column, value):
        self.eq_calls.append((column, value))
        return self

    @property
    def filters(self) -> dict:
        return dict(self.eq_calls)

    def execute(self):
        if self._raise:
            raise RuntimeError("supabase indisponivel")
        self._call_log.append(("delete_dreams", self.filters))
        matched = [
            row for row in self._rows
            if all(row.get(col) == val for col, val in self.eq_calls)
        ]
        return MagicMock(data=matched)


def _dream(dream_id: str, owner: str):
    return {"id": dream_id, "user_id": owner}


# ─── DELETE /dreams/{dream_id} ────────────────────────────────────────────────

class TestDeleteDreamOwnership(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.owner = {"sub": "user-a", "email": "a@test.com"}
        self.attacker = {"sub": "user-b", "email": "b@test.com"}
        self.dream_id = "dream-de-a"
        self.rows = [_dream(self.dream_id, "user-a")]

    async def test_filtra_por_id_e_por_user_id(self):
        """
        A asserção central deste arquivo.

        Se o `.eq("user_id", ...)` for removido, `filters` perde a chave e este
        teste falha — que é exatamente o alarme que queremos.
        """
        chain = _DeleteChain(self.rows)
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            await dreams_router.delete_dream(self.dream_id, self.owner)

        sb.table.assert_called_once_with("dreams")
        self.assertEqual(
            chain.filters,
            {"id": self.dream_id, "user_id": "user-a"},
            "a exclusao precisa filtrar por id E por user_id — service_role bypassa RLS",
        )

    async def test_sonho_de_outro_usuario_nao_e_apagado(self):
        """user-b tentando apagar sonho de user-a: nada casa o filtro -> 404."""
        chain = _DeleteChain(self.rows)
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.delete_dream(self.dream_id, self.attacker)

        self.assertEqual(ctx.exception.status_code, 404)
        # E o filtro tem de ter sido pelo id de QUEM PEDIU, nunca pelo dono.
        self.assertEqual(chain.filters.get("user_id"), "user-b")

    async def test_dono_apaga_o_proprio_sonho(self):
        chain = _DeleteChain(self.rows)
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            result = await dreams_router.delete_dream(self.dream_id, self.owner)

        self.assertEqual(result, {"deleted": True, "id": self.dream_id})

    async def test_sonho_inexistente_retorna_404(self):
        chain = _DeleteChain([])
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.delete_dream("nao-existe", self.owner)

        self.assertEqual(ctx.exception.status_code, 404)

    async def test_falha_do_supabase_vira_500_sem_vazar_a_excecao(self):
        chain = _DeleteChain(self.rows, raise_on_execute=True)
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.delete_dream(self.dream_id, self.owner)

        self.assertEqual(ctx.exception.status_code, 500)
        self.assertEqual(ctx.exception.detail["error"], "delete_failed")
        self.assertNotIn("supabase indisponivel", str(ctx.exception.detail))

    async def test_404_nao_e_convertido_em_500(self):
        """O `except HTTPException: raise` precisa continuar antes do `except Exception`."""
        chain = _DeleteChain([])
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(dreams_router, "get_supabase_service", return_value=sb):
            with self.assertRaises(HTTPException) as ctx:
                await dreams_router.delete_dream("nao-existe", self.owner)

        self.assertEqual(ctx.exception.status_code, 404)


# ─── DELETE /auth/account ─────────────────────────────────────────────────────

class TestDeleteAccountOwnership(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.user = {"sub": "user-a", "email": "a@test.com"}

    def _service(self, rows=None, raise_on_dreams=False, raise_on_auth=False):
        call_log = []
        chain = _DeleteChain(
            rows if rows is not None else [_dream("d1", "user-a")],
            call_log=call_log,
            raise_on_execute=raise_on_dreams,
        )
        service = MagicMock()
        service.table.return_value = chain

        def _delete_user(uid):
            if raise_on_auth:
                raise RuntimeError("gotrue fora do ar")
            call_log.append(("delete_auth_user", uid))

        service.auth.admin.delete_user.side_effect = _delete_user
        return service, chain, call_log

    async def test_apaga_apenas_os_sonhos_do_proprio_usuario(self):
        service, chain, _ = self._service()

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            result = await auth_router.delete_account(self.user)

        self.assertEqual(result, {"deleted": True})
        service.table.assert_called_once_with("dreams")
        self.assertEqual(
            chain.filters,
            {"user_id": "user-a"},
            "a exclusao de conta nao pode apagar sonhos de outros usuarios",
        )

    async def test_remove_do_auth_o_proprio_usuario(self):
        service, _, _ = self._service()

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            await auth_router.delete_account(self.user)

        service.auth.admin.delete_user.assert_called_once_with("user-a")

    async def test_ordem_sonhos_antes_do_auth(self):
        """Ordem deliberada e documentada na rota: dados primeiro, conta depois."""
        service, _, call_log = self._service()

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            await auth_router.delete_account(self.user)

        self.assertEqual(
            [step for step, _ in call_log],
            ["delete_dreams", "delete_auth_user"],
        )

    async def test_falha_ao_apagar_sonhos_nao_remove_a_conta(self):
        """Se os dados não puderam ser apagados, a conta não pode sumir junto."""
        service, _, _ = self._service(raise_on_dreams=True)

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            with self.assertRaises(HTTPException) as ctx:
                await auth_router.delete_account(self.user)

        self.assertEqual(ctx.exception.status_code, 500)
        service.auth.admin.delete_user.assert_not_called()

    async def test_falha_no_auth_avisa_que_os_sonhos_ja_foram_removidos(self):
        service, _, _ = self._service(raise_on_auth=True)

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            with self.assertRaises(HTTPException) as ctx:
                await auth_router.delete_account(self.user)

        self.assertEqual(ctx.exception.status_code, 500)
        self.assertEqual(ctx.exception.detail["error"], "delete_failed")
        self.assertIn("sonhos foram removidos", ctx.exception.detail["message"])

    async def test_token_sem_sub_retorna_400_e_nao_toca_no_banco(self):
        service, _, _ = self._service()

        with patch.object(auth_router, "get_supabase_service", return_value=service):
            with self.assertRaises(HTTPException) as ctx:
                await auth_router.delete_account({"email": "sem-sub@test.com"})

        self.assertEqual(ctx.exception.status_code, 400)
        service.table.assert_not_called()
        service.auth.admin.delete_user.assert_not_called()


if __name__ == "__main__":
    unittest.main()

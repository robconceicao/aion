"""
Cada rota de `episodes` precisa usar o client Supabase certo.

Descoberto ao cruzar o dump real de pg_policies (2026-09-04) com o código: as
três rotas de escrita autenticavam o admin no FastAPI, via
`Depends(get_current_admin)`, mas gravavam pelo client **anon**.

As políticas de escrita de `episodes` são `TO authenticated` com claim de admin
no JWT. O client anon tem role `anon`, então nenhuma política permissiva se
aplicava e o RLS negava a operação: o admin passava pela checagem da API e o
INSERT morria no banco. Consistente com a tabela `episodes` estar vazia em
produção.

A leitura, ao contrário, DEVE continuar no client anon — a política de SELECT é
`USING (true)`, pública, e o endpoint é aberto. Usar service_role ali seria
privilégio desnecessário.

Estes testes travam essa divisão nos dois sentidos: escrita com service_role,
leitura sem. 100% local, sem rede.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.routers import episodes as episodes_router  # noqa: E402
from app.models.episode import EpisodeCreate  # noqa: E402


def _row(number: int = 1):
    return {
        "id": "00000000-0000-0000-0000-000000000001",
        "number": number,
        "title_main": "Episodio",
        "title_secondary": "Sub",
        "myths_symbols": [],
        "description": "",
        "created_at": "2026-06-14T06:00:00",
    }


class _Chain:
    """Duplo encadeável de supabase.table(...) — devolve `rows` no execute()."""

    def __init__(self, rows):
        self._rows = rows

    def select(self, *a, **k):
        return self

    def insert(self, *a, **k):
        return self

    def update(self, *a, **k):
        return self

    def delete(self, *a, **k):
        return self

    def eq(self, *a, **k):
        return self

    def order(self, column, *, desc=False, nullsfirst=None, foreign_table=None):
        return self

    def execute(self):
        return MagicMock(data=self._rows)


class _Empty(_Chain):
    """Para o check de duplicata em create_episode: nada existe ainda."""

    def __init__(self):
        super().__init__([])
        self._calls = 0

    def execute(self):
        # 1a chamada: check de duplicata (vazio). 2a: retorno do insert.
        self._calls += 1
        return MagicMock(data=[] if self._calls == 1 else [_row()])


def _payload():
    return EpisodeCreate(
        number=1,
        title_main="Episodio",
        title_secondary="Sub",
        myths_symbols=[],
        description="",
    )


class TestEscritaUsaServiceRole(unittest.IsolatedAsyncioTestCase):
    """
    As três rotas de escrita precisam do client service_role. Com o anon, o RLS
    nega — foi o bug.
    """

    async def test_create_usa_service_role(self):
        anon, service = MagicMock(), MagicMock()
        service.table.return_value = _Empty()

        with patch.object(episodes_router, "get_supabase", return_value=anon), \
             patch.object(episodes_router, "get_supabase_service", return_value=service):
            await episodes_router.create_episode(_payload(), {"sub": "admin"})

        service.table.assert_called_with("episodes")
        anon.table.assert_not_called()

    async def test_update_usa_service_role(self):
        anon, service = MagicMock(), MagicMock()
        service.table.return_value = _Chain([_row()])

        with patch.object(episodes_router, "get_supabase", return_value=anon), \
             patch.object(episodes_router, "get_supabase_service", return_value=service):
            await episodes_router.update_episode(1, _payload(), {"sub": "admin"})

        service.table.assert_called_with("episodes")
        anon.table.assert_not_called()

    async def test_delete_usa_service_role(self):
        anon, service = MagicMock(), MagicMock()
        service.table.return_value = _Chain([_row()])

        with patch.object(episodes_router, "get_supabase", return_value=anon), \
             patch.object(episodes_router, "get_supabase_service", return_value=service):
            await episodes_router.delete_episode(1, {"sub": "admin"})

        service.table.assert_called_with("episodes")
        anon.table.assert_not_called()


class TestLeituraNaoEscalaPrivilegio(unittest.IsolatedAsyncioTestCase):
    """
    A leitura e publica (`USING (true)`) e deve continuar no client anon.
    Promover a service_role seria privilegio sem necessidade.
    """

    async def test_list_usa_anon(self):
        anon, service = MagicMock(), MagicMock()
        anon.table.return_value = _Chain([_row()])

        with patch.object(episodes_router, "get_supabase", return_value=anon), \
             patch.object(episodes_router, "get_supabase_service", return_value=service):
            await episodes_router.list_episodes()

        anon.table.assert_called_with("episodes")
        service.table.assert_not_called()

    async def test_get_por_numero_usa_anon(self):
        anon, service = MagicMock(), MagicMock()
        anon.table.return_value = _Chain([_row()])

        with patch.object(episodes_router, "get_supabase", return_value=anon), \
             patch.object(episodes_router, "get_supabase_service", return_value=service):
            await episodes_router.get_episode(1)

        anon.table.assert_called_with("episodes")
        service.table.assert_not_called()


if __name__ == "__main__":
    unittest.main()

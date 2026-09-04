"""
Testes de rota do Canal (GET /episodes/).

Motivação (regressão real, 2026-09-04): `list_episodes` chamava
`.order("number", ascending=True)`. O kwarg `ascending` pertencia ao postgrest
antigo; o postgrest instalado hoje expõe `order(column, *, desc=False, ...)`.
Como `requirements.txt` pina `supabase>=2.11.0,<3` (faixa flutuante), o Render
subiu uma versão sem `ascending` e o endpoint passou a devolver 500 em produção.

O CI ficou verde o tempo todo porque `test_episode_model.py` só valida o modelo
Pydantic — nenhum teste exercitava a rota. Estes testes fecham essa lacuna:

  1. test_list_episodes_*  — exercita a rota contra um duplo do client Supabase
     cuja assinatura de `.order()` espelha a do postgrest real.
  2. test_order_call_matches_installed_postgrest_signature — trava o contrato
     contra a biblioteca instalada de verdade, para que a próxima mudança de
     API apareça como teste vermelho e não como 500 em produção.

100% local — zero rede, zero produção.
"""
from __future__ import annotations

import inspect
import sys
import os
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.routers import episodes as episodes_router  # noqa: E402


def _episode_row(number: int):
    return {
        "id": f"00000000-0000-0000-0000-00000000000{number}",
        "number": number,
        "title_main": f"Episodio {number}",
        "title_secondary": "Sub",
        "myths_symbols": [],
        "description": "",
        "created_at": "2026-06-14T06:00:00",
    }


class _FakeSelectChain:
    """
    Duplo de `supabase.table(...).select(...)`.

    `order()` replica a assinatura REAL do postgrest instalado — `column`
    posicional e o resto keyword-only. É isso que faz o teste falhar com
    TypeError se alguém voltar a passar um kwarg que a lib não aceita.
    """

    def __init__(self, rows):
        self._rows = rows
        self.order_calls = []

    def select(self, *args, **kwargs):
        return self

    def order(self, column, *, desc=False, nullsfirst=None, foreign_table=None):
        self.order_calls.append({"column": column, "desc": desc})
        reverse = bool(desc)
        self._rows = sorted(self._rows, key=lambda r: r["number"], reverse=reverse)
        return self

    def execute(self):
        return MagicMock(data=self._rows)


class TestListEpisodes(unittest.IsolatedAsyncioTestCase):
    async def test_list_episodes_returns_rows_without_raising(self):
        """A regressão se manifestava como TypeError -> 500. Aqui deve passar limpo."""
        chain = _FakeSelectChain([_episode_row(2), _episode_row(1)])
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(episodes_router, "get_supabase", return_value=sb):
            result = await episodes_router.list_episodes()

        self.assertEqual(len(result), 2)
        sb.table.assert_called_once_with("episodes")

    async def test_list_episodes_orders_by_number_ascending(self):
        """O docstring da rota promete ordem crescente — esta é a asserção que cobra isso."""
        chain = _FakeSelectChain([_episode_row(3), _episode_row(1), _episode_row(2)])
        sb = MagicMock()
        sb.table.return_value = chain

        with patch.object(episodes_router, "get_supabase", return_value=sb):
            result = await episodes_router.list_episodes()

        self.assertEqual([row["number"] for row in result], [1, 2, 3])
        self.assertEqual(chain.order_calls, [{"column": "number", "desc": False}])


class TestPostgrestOrderContract(unittest.TestCase):
    def test_order_call_matches_installed_postgrest_signature(self):
        """
        Trava o contrato contra a lib instalada.

        Se um upgrade de `supabase`/`postgrest` renomear ou remover `desc`, este
        teste fica vermelho no CI — em vez de o endpoint quebrar em produção.
        """
        from postgrest._sync.request_builder import SyncSelectRequestBuilder

        signature = inspect.signature(SyncSelectRequestBuilder.order)

        # Exatamente a chamada feita em app/routers/episodes.py::list_episodes
        signature.bind(None, "number", desc=False)

        # E a forma antiga tem de continuar sendo rejeitada, senão este teste
        # deixaria de proteger contra a regressão que o motivou.
        with self.assertRaises(TypeError):
            signature.bind(None, "number", ascending=True)


if __name__ == "__main__":
    unittest.main()

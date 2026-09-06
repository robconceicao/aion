"""
O GET / precisa dizer QUAL build está no ar.

Motivação: o Render não registra deploy na API do GitHub (os deployments que
aparecem lá são todos do vercel[bot], do frontend) e as mudanças de backend
costumam ser invisíveis de fora — sem isto, não existia sonda anônima capaz de
distinguir um commit do outro em produção. A pergunta "o merge já subiu?" só
tinha resposta abrindo o painel do Render.

O SHA vem de RENDER_GIT_COMMIT, injetada pelo próprio Render em todo deploy.
Fora dele a variável não existe, e a resposta precisa ser "desconhecido" — a
ausência de informação é aceitável, um SHA errado não é.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.core.config import Settings  # noqa: E402

SHA = "1b2ca79d53f0c99e325a18e7105eca9b2d721342"


class TestCommitCurto(unittest.TestCase):
    """A propriedade lida pelo endpoint, testada sem subir a app."""

    def test_encurta_o_sha_para_7_como_git_log_oneline(self):
        with patch.dict(os.environ, {"RENDER_GIT_COMMIT": SHA}, clear=False):
            self.assertEqual(Settings().commit_curto, "1b2ca79")

    def test_sem_a_env_var_responde_desconhecido_e_nao_string_vazia(self):
        # String vazia no JSON seria lida como "o campo sumiu" por quem
        # consome; "desconhecido" diz explicitamente que não há informação.
        env = {k: v for k, v in os.environ.items() if k != "RENDER_GIT_COMMIT"}
        with patch.dict(os.environ, env, clear=True):
            self.assertEqual(Settings().commit_curto, "desconhecido")

    def test_sha_ja_curto_nao_e_corrompido(self):
        with patch.dict(os.environ, {"RENDER_GIT_COMMIT": "abc123"}, clear=False):
            self.assertEqual(Settings().commit_curto, "abc123")


class TestRootResponse(unittest.TestCase):
    """O contrato do endpoint em si.

    Chama a corotina direto em vez de usar TestClient: com httpx 0.28 e
    starlette 0.27 o TestClient levanta TypeError no construtor — é por isso
    que o CI ignora tests/test_api.py, o único outro teste que depende dele.
    Um teste que não roda no CI não protege nada.
    """

    def _get_root(self, env: dict) -> dict:
        # A app lê `settings` no import; recarregar dentro do patch garante que
        # o valor testado é o que o processo realmente serviria.
        with patch.dict(os.environ, env, clear=False):
            import asyncio
            import importlib

            from app.core import config as config_mod

            importlib.reload(config_mod)
            from app import main as main_mod

            importlib.reload(main_mod)
            return asyncio.run(main_mod.root())

    def test_expoe_commit_e_branch_do_deploy(self):
        body = self._get_root(
            {"RENDER_GIT_COMMIT": SHA, "RENDER_GIT_BRANCH": "main"}
        )
        self.assertEqual(body["commit"], "1b2ca79")
        self.assertEqual(body["branch"], "main")

    def test_mantem_a_mensagem_de_liveness_original(self):
        # O keep-alive.yml só olha o status code, mas a mensagem é contrato
        # público desde antes — acrescentar campos não pode removê-la.
        body = self._get_root({"RENDER_GIT_COMMIT": SHA})
        self.assertIn("Aion está ativo", body["message"])


if __name__ == "__main__":
    unittest.main()

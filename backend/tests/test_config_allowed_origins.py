"""
ALLOWED_ORIGINS não pode derrubar o boot da aplicação.

Regressão latente: o campo era declarado como `list`. Para tipos complexos, o
pydantic-settings tenta `json.loads` no valor da env var **antes** de qualquer
validator. Definir ALLOWED_ORIGINS no Render na forma natural —
`"https://a.com,https://b.com"` — levantava SettingsError e a aplicação não
subia.

O bug nunca se manifestou apenas porque a variável não estava setada em
produção: o `os.getenv(...)` no default fazia a divisão e a env var jamais era
lida pelo pydantic. Bastava alguém configurar a variável para o backend parar
de subir — e a mensagem de erro não apontaria para CORS.

O campo passou a ser `str`, com a divisão em `allowed_origins_list`.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.core.config import Settings  # noqa: E402


class TestAllowedOrigins(unittest.TestCase):
    def test_env_var_com_virgulas_nao_quebra_o_boot(self):
        """O caso exato que levantava SettingsError."""
        with patch.dict(os.environ, {"ALLOWED_ORIGINS": "https://a.com,https://b.com"}):
            settings = Settings()
            self.assertEqual(
                settings.allowed_origins_list,
                ["https://a.com", "https://b.com"],
            )

    def test_espacos_em_branco_sao_removidos(self):
        with patch.dict(os.environ, {"ALLOWED_ORIGINS": " https://a.com , https://b.com "}):
            self.assertEqual(
                Settings().allowed_origins_list,
                ["https://a.com", "https://b.com"],
            )

    def test_origem_unica_sem_virgula(self):
        with patch.dict(os.environ, {"ALLOWED_ORIGINS": "https://so-uma.com"}):
            self.assertEqual(Settings().allowed_origins_list, ["https://so-uma.com"])

    def test_entradas_vazias_sao_descartadas(self):
        with patch.dict(os.environ, {"ALLOWED_ORIGINS": "https://a.com,,  ,https://b.com,"}):
            self.assertEqual(
                Settings().allowed_origins_list,
                ["https://a.com", "https://b.com"],
            )

    def test_default_continua_restrito_e_sem_curinga(self):
        """
        CORS aberto seria pior que o bug original. O default precisa continuar
        sendo uma lista fechada — nunca "*".
        """
        origens = Settings().allowed_origins_list
        self.assertGreater(len(origens), 0)
        self.assertNotIn("*", origens)
        for origem in origens:
            self.assertTrue(
                origem.startswith("https://") or origem.startswith("http://localhost"),
                f"origem suspeita no default: {origem}",
            )

    def test_lista_e_de_strings(self):
        """main.py entrega isto direto ao CORSMiddleware."""
        origens = Settings().allowed_origins_list
        self.assertIsInstance(origens, list)
        for origem in origens:
            self.assertIsInstance(origem, str)


if __name__ == "__main__":
    unittest.main()

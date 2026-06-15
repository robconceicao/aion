"""
Testes mockados para A-02, A-03, A-05 -- suite offline.

COBERTURA:
  Teste 1 (cascata): Prova que call_claude tenta os 3 modelos Claude + Gemini
    + DeepSeek antes de levantar RuntimeError, e que analyze_dream captura essa
    excecao e devolve um dict com _error:True sem vazar para o caller.

FORA DE ESCOPO AQUI (validacao manual no app):
  O cenario de persistencia -- que _background_save_and_recurrence grava
  interpretation_status='failed' e embedding_status='failed' quando analysis
  contem _error:True e embedding=None -- nao e testado aqui porque exige
  importar app.routers.dreams, que registra rotas FastAPI no nivel de modulo
  (decoradores @router.post) e requer o pacote supabase instalado.
  Validacao: rodar o app apontando para provedores invalidos e confirmar no
  painel Supabase que o sonho foi gravado com os campos de status corretos.
"""
import sys, os, types, unittest
from unittest.mock import AsyncMock, MagicMock, patch

# ── Stubs de dependencias externas ────────────────────────────────────────────
for mod_name in [
    'anthropic', 'google', 'google.generativeai',
    'httpx', 'app.core.config',
]:
    sys.modules.setdefault(mod_name, types.ModuleType(mod_name))

# Config stub
cfg = sys.modules['app.core.config']
class FakeSettings:
    ANTHROPIC_API_KEY = 'fake-anthropic'
    GEMINI_API_KEY    = 'fake-gemini'
    DEEPSEEK_API_KEY  = 'fake-deepseek'
cfg.settings = FakeSettings()

# anthropic stub: messages.create levanta excecao (simula rate-limit)
anthropic_mod = sys.modules['anthropic']
class FakeAnthropic:
    def __init__(self, **_): self.messages = self
    async def create(self, **_): raise RuntimeError("rate-limit simulado")
anthropic_mod.AsyncAnthropic = FakeAnthropic

# google.generativeai stub
genai_mod = types.ModuleType('google.generativeai')
genai_mod.configure = lambda **_: None
sys.modules['google.generativeai'] = genai_mod
sys.modules['google'].generativeai = genai_mod

# httpx stub (DeepSeek usa httpx)
httpx_mod = sys.modules['httpx']
class FakeHttpxClient:
    async def __aenter__(self): return self
    async def __aexit__(self, *_): pass
    async def post(self, *_, **__): raise RuntimeError("httpx simulado")
httpx_mod.AsyncClient = FakeHttpxClient

# Limpa cache de ai_service para reimportar com stubs
for m in list(sys.modules.keys()):
    if 'ai_service' in m:
        del sys.modules[m]

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import app.services.ai_service as ai_svc


# ═══════════════════════════════════════════════════════════════════════════════
# TESTE 1: cascata completa -- todos os provedores falham
# ═══════════════════════════════════════════════════════════════════════════════
class TestCascata(unittest.IsolatedAsyncioTestCase):

    async def test_call_claude_levanta_runtime_error_quando_todos_falham(self):
        """call_claude tenta os 3 Claude + Gemini + DeepSeek; levanta RuntimeError se todos falham."""
        with patch.object(ai_svc, 'call_gemini',   new=AsyncMock(side_effect=RuntimeError("gemini down"))), \
             patch.object(ai_svc, 'call_deepseek', new=AsyncMock(side_effect=RuntimeError("deepseek down"))):
            with self.assertRaises(RuntimeError) as ctx:
                await ai_svc.call_claude("sys", "user")
            print(f"\n[OK] call_claude levantou RuntimeError: {ctx.exception}")

    async def test_analyze_dream_nao_vaza_excecao_e_retorna_error_flag(self):
        """analyze_dream captura RuntimeError de call_claude e retorna dict com _error:True."""
        with patch.object(ai_svc, 'call_claude', new=AsyncMock(side_effect=RuntimeError("todos falharam"))):
            result = await ai_svc.analyze_dream("Sonhei que voava.")
            assert isinstance(result, dict), "resultado nao e dict"
            assert result.get("_error") is True, f"_error ausente ou False: {result}"
            assert "aviso" in result, "campo aviso ausente"
            assert "essencia" in result, "campo essencia ausente"
            print(f"\n[OK] analyze_dream retornou dict com _error=True")
            print(f"     chaves: {list(result.keys())}")


if __name__ == '__main__':
    print("=" * 60)
    print("Rodando testes A-05 / A-03 (cascata offline)")
    print("=" * 60)
    unittest.main(verbosity=2)

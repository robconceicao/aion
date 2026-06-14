"""
Teste alternativo de import -- B-02
Verifica que o modulo feedback importa sem erros sintaticos ou de dependencia
circular, sem precisar subir o app inteiro nem carregar .env.
"""
import sys, types

# Stub minimo para suprimir dependencias de runtime (pydantic_settings, supabase)
# sem precisar instalar pacotes no ambiente de CI local
for mod in ['pydantic_settings', 'supabase', 'jose', 'jose.jwt',
            'app.database', 'app.routers.auth', 'app.core.config']:
    stub = types.ModuleType(mod)
    # Stubs necessarios para o modulo nao quebrar no nivel de import
    if mod == 'pydantic_settings':
        class BaseSettings: pass
        stub.BaseSettings = BaseSettings
    if mod == 'app.database':
        stub.get_supabase = lambda: None
    if mod == 'app.routers.auth':
        stub.get_current_user = lambda: None
    if mod == 'app.core.config':
        class FakeSettings:
            PROJECT_NAME = 'Aion'
        stub.settings = FakeSettings()
    sys.modules[mod] = stub

sys.path.insert(0, '.')

import app.routers.feedback as fb

# Verifica que o router existe e tem a rota correta
routes = [r for r in fb.router.routes]
route_paths = [r.path for r in routes]

assert '/{dream_id}/feedback' in route_paths, f'Rota esperada ausente: {route_paths}'
assert hasattr(fb, 'FeedbackCreate'), 'FeedbackCreate nao encontrado'
assert hasattr(fb, 'create_feedback'), 'create_feedback nao encontrado'

print('OK - app.routers.feedback importado sem erros')
print(f'  Rotas registradas: {route_paths}')
print(f'  FeedbackCreate: {fb.FeedbackCreate.__fields__.keys() if hasattr(fb.FeedbackCreate,"__fields__") else list(fb.FeedbackCreate.model_fields.keys())}')
print()
print('[PASS] Import alternativo do modulo feedback: SUCESSO')

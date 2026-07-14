"""
Teste de import do modulo feedback (B-02).

Verifica que o router importa com as dependencias reais do backend
(sem poluir sys.modules — stubs quebravam a coleta de outros testes no CI).
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))


def test_feedback_router_imports_and_has_route():
    from app.routers import feedback as fb

    route_paths = [r.path for r in fb.router.routes]
    assert "/{dream_id}/feedback" in route_paths, f"Rota esperada ausente: {route_paths}"
    assert hasattr(fb, "FeedbackCreate"), "FeedbackCreate nao encontrado"
    assert hasattr(fb, "create_feedback"), "create_feedback nao encontrado"


if __name__ == "__main__":
    test_feedback_router_imports_and_has_route()
    print("[PASS] Import do modulo feedback: SUCESSO")

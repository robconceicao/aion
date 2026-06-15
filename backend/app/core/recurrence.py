"""
Critério de recorrência — funções puras, sem I/O, sem dependências externas.
Importável em testes sem precisar do restante do stack (FastAPI, Supabase, etc.).
"""

_RECURRENCE_MIN = 3


def is_recurrence_triggered(n: int) -> bool:
    """True se há n sonhos similares suficientes para declarar recorrência."""
    return n >= _RECURRENCE_MIN


def numero_aparicoes(n: int) -> int:
    """Total de aparições: similares já no banco + o sonho atual."""
    return n + 1

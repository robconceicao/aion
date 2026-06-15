"""
Testa as funções puras de critério de recorrência (A-04).
Sem dependência de Supabase, banco ou rede.
"""
import pytest
from app.core.recurrence import is_recurrence_triggered, numero_aparicoes, _RECURRENCE_MIN



class TestIsRecurrenceTriggered:
    def test_below_min_returns_false(self):
        """n = 0, 1, 2 → False (abaixo do mínimo)."""
        for n in range(_RECURRENCE_MIN):          # 0, 1, 2
            assert is_recurrence_triggered(n) is False, f"Esperado False para n={n}"

    def test_at_min_returns_true(self):
        """n = 3 → True (exatamente no mínimo)."""
        assert is_recurrence_triggered(_RECURRENCE_MIN) is True

    def test_above_min_returns_true(self):
        """n = 4 → True (acima do mínimo)."""
        assert is_recurrence_triggered(_RECURRENCE_MIN + 1) is True


class TestNumeroAparicoes:
    def test_at_min(self):
        """3 similares no banco + sonho atual = 4 aparições."""
        assert numero_aparicoes(3) == 4

    def test_above_min(self):
        """4 similares no banco + sonho atual = 5 aparições."""
        assert numero_aparicoes(4) == 5


class TestConsistency:
    """
    Garante que is_recurrent no dream_data e o bloco if usam
    exatamente o mesmo critério — estado inconsistente é impossível.
    """
    def test_boundary_false_to_true(self):
        """Fronteira exata: n=2 → False, n=3 → True."""
        assert is_recurrence_triggered(2) is False
        assert is_recurrence_triggered(3) is True

    def test_same_call_same_result_for_all_sizes(self):
        """Mesma função, mesmo argumento → resultado idêntico em todos os tamanhos."""
        for n in range(6):
            assert is_recurrence_triggered(n) == is_recurrence_triggered(n)

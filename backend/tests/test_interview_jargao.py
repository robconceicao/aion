"""
Verificação determinística de zero jargão nas perguntas da entrevista.

O INTERVIEW_SYSTEM_PROMPT já proibia jargão, mas prompt é controle
probabilístico — perguntas com "Divine Child", "Self emergente" e "arquétipo"
chegaram ao usuário em produção. A verificação roda depois da geração.

Política acordada: gera → verifica → regenera UMA vez citando os termos
encontrados → se reprovar de novo, usa o fallback fixo.

100% local — call_claude é mockado, nenhuma chamada de rede.
"""
from __future__ import annotations

import os
import sys
import unittest
from unittest.mock import AsyncMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.services import ai_service  # noqa: E402


BOAS = [
    "No sonho você parou diante da porta azul do corredor mas não entrou. O que você temia encontrar do outro lado?",
    "A mulher de vermelho aparecia sempre de costas. O que nela te incomodava tanto?",
    "Você disse que a água subia devagar. O que na sua vida hoje sobe devagar assim?",
]


def _json(perguntas):
    import json
    return json.dumps({"perguntas": perguntas}, ensure_ascii=False)


class TestDeteccaoDeJargao(unittest.TestCase):
    def test_aprova_perguntas_concretas(self):
        self.assertEqual(ai_service.violacoes_de_jargao(BOAS), [])

    def test_pega_os_termos_relatados_em_producao(self):
        """Os três casos que motivaram esta correção."""
        for termo, pergunta in [
            ("arquetipo", "Que arquétipo essa figura representa para você?"),
            ("self", "O que o Self emergente está pedindo?"),
            ("divine child", "A Divine Child apareceu no sonho — o que ela quer?"),
        ]:
            with self.subTest(termo=termo):
                self.assertIn(termo, ai_service.violacoes_de_jargao([pergunta]))

    def test_ignora_acento_e_caixa(self):
        self.assertIn("individuacao", ai_service.violacoes_de_jargao(
            ["Como sua INDIVIDUAÇÃO avança?"]
        ))
        self.assertIn("psique", ai_service.violacoes_de_jargao(
            ["O que sua Psique tenta integrar?"]
        ))

    def test_casa_por_palavra_inteira_sem_falso_positivo(self):
        """
        Palavra inteira, senão o filtro rejeitaria perguntas legítimas e
        empurraria tudo para o fallback — pior que não filtrar.
        """
        seguras = [
            "Você já conversou com um psicólogo sobre esse sonho recorrente?",
            "Você tirou uma selfie naquele lugar do sonho alguma vez?",
            "O quarto era mais escuro que o corredor?",
        ]
        self.assertEqual(ai_service.violacoes_de_jargao(seguras), [])

    def test_termos_ambiguos_nao_sao_barrados(self):
        """
        Calibragem deliberada: 'sombra', 'complexo', 'anima', 'projeção' e
        'persona' têm uso cotidiano e ficam fora do filtro automático —
        continuam proibidos pelo prompt.
        """
        legitimas = [
            "Havia uma sombra no fim do corredor — você chegou a olhar para ela?",
            "O que te anima quando você lembra dessa cena?",
            "Era um prédio complexo, com muitas portas?",
        ]
        self.assertEqual(ai_service.violacoes_de_jargao(legitimas), [])

    def test_relata_todos_os_termos_encontrados(self):
        v = ai_service.violacoes_de_jargao([
            "Que arquétipo aparece?", "E o monomito?", "E a mandala?",
        ])
        self.assertEqual(set(v), {"arquetipo", "monomito", "mandala"})


class TestFallbackRespeitaAPropriaRegra(unittest.TestCase):
    def test_fallback_passa_no_filtro(self):
        """
        Antes desta correção o fallback usava "psique" — jargão proibido servido
        justamente no caminho de degradação. Este é o teste que impede a
        reincidência.
        """
        self.assertEqual(
            ai_service.violacoes_de_jargao(ai_service.INTERVIEW_FALLBACK_QUESTIONS),
            [],
        )

    def test_fallback_tem_tres_perguntas(self):
        self.assertEqual(len(ai_service.INTERVIEW_FALLBACK_QUESTIONS), 3)


class TestFluxoDeRegeneracao(unittest.IsolatedAsyncioTestCase):
    async def test_saida_limpa_passa_direto_sem_regenerar(self):
        mock = AsyncMock(return_value=_json(BOAS))
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(result, BOAS)
        self.assertEqual(mock.await_count, 1)

    async def test_regenera_uma_vez_e_aceita_a_segunda(self):
        ruins = ["Que arquétipo domina a cena?"] + BOAS[1:]
        mock = AsyncMock(side_effect=[_json(ruins), _json(BOAS)])
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(result, BOAS)
        self.assertEqual(mock.await_count, 2)

    async def test_regeneracao_cita_os_termos_encontrados(self):
        """Sem citar o que reprovou, a segunda tentativa é um chute."""
        ruins = ["Que arquétipo domina a cena?"] + BOAS[1:]
        mock = AsyncMock(side_effect=[_json(ruins), _json(BOAS)])
        with patch.object(ai_service, "call_claude", mock):
            await ai_service.generate_interview_questions("Sonhei com o mar.")

        segunda = mock.await_args_list[1].args[1]
        self.assertIn("REJEITADA", segunda)
        self.assertIn("arquetipo", segunda)

    async def test_duas_reprovacoes_caem_no_fallback(self):
        ruins = ["Que arquétipo domina a cena?"] + BOAS[1:]
        mock = AsyncMock(side_effect=[_json(ruins), _json(ruins)])
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(result, ai_service.INTERVIEW_FALLBACK_QUESTIONS)
        self.assertEqual(mock.await_count, 2, "no maximo uma regeneracao")
        self.assertEqual(ai_service.violacoes_de_jargao(result), [])

    async def test_nao_regenera_mais_de_uma_vez(self):
        """
        O usuário está esperando na tela e cada tentativa dispara a cascata de
        LLM. Duas chamadas é o teto.
        """
        ruins = ["Que arquétipo domina a cena?"] + BOAS[1:]
        mock = AsyncMock(return_value=_json(ruins))
        with patch.object(ai_service, "call_claude", mock):
            await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(mock.await_count, 2)

    async def test_falha_da_ia_cai_no_fallback_sem_repetir(self):
        mock = AsyncMock(side_effect=RuntimeError("todos os provedores falharam"))
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(result, ai_service.INTERVIEW_FALLBACK_QUESTIONS)
        self.assertEqual(mock.await_count, 1, "erro de provedor nao merece retry aqui")

    async def test_lista_vazia_cai_no_fallback(self):
        mock = AsyncMock(return_value=_json([]))
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei com o mar.")

        self.assertEqual(result, ai_service.INTERVIEW_FALLBACK_QUESTIONS)

    async def test_fallback_devolve_copia_nao_a_lista_original(self):
        """Mutação acidental pelo chamador não pode corromper a constante."""
        mock = AsyncMock(side_effect=RuntimeError("falhou"))
        with patch.object(ai_service, "call_claude", mock):
            result = await ai_service.generate_interview_questions("Sonhei.")
        result.append("contaminacao")

        self.assertEqual(len(ai_service.INTERVIEW_FALLBACK_QUESTIONS), 3)


if __name__ == "__main__":
    unittest.main()

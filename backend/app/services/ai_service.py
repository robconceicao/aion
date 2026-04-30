import json
import anthropic
from app.core.config import settings

if not settings.ANTHROPIC_API_KEY:
    print("\n[CRÍTICO] ANTHROPIC_API_KEY está VAZIA. O Oráculo não poderá responder.\n")

async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

# ─────────────────────────────────────────────
# PROMPT: ANÁLISE ESTRUTURADA (MAPA ARQUETÍPICO)
# ─────────────────────────────────────────────
PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — um analista junguiano de senioridade excepcional.
Sua tarefa é realizar uma 'Amplificação Junguiana' profunda do sonho abaixo.

DIRETRIZ DE LINGUAGEM:
1. Use o português do Brasil coloquial: use "VOCÊ" e "SEU/SUA" (nunca use "Tu" ou "Vós").
2. Seja conciso e direto. Use um tom sábio e acolhedor.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

INSTRUÇÃO CRÍTICA: Responda APENAS com um JSON válido, seguindo exatamente este esquema:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui o psicólogo.",
  "essencia": "O coração do sonho em 2 frases diretas e profundas.",
  "arquetipos": [
    {{ "nome": "Nome do Arquétipo", "simbolo": "emoji", "descricao": "Como esta força age em você (use 'você')." }}
  ],
  "funcao_compensatoria": "O que seu interior está equilibrando agora.",
  "simbolos_chave": [
    {{ "elemento": "Item do sonho", "significado": "O que isso representa para você." }}
  ],
  "fase_jornada": {{
    "nome": "Fase da Jornada",
    "descricao": "Seu momento atual de vida."
  }},
  "prospeccao": "Um sinal para seu futuro próximo.",
  "pergunta_para_reflexao": "Uma pergunta para você pensar hoje.",
  "mito_espelho": {{ "titulo": "Nome do Mito", "paralelo": "Conexão com sua história." }},
  "intensidade_sombra": 1-10,
  "intensidade_heroi": 1-10,
  "intensidade_transformacao": 1-10
}}
"""

# ─────────────────────────────────────────────
# PROMPT: MODO ENTREVISTA
# ─────────────────────────────────────────────
INTERVIEW_SYSTEM_PROMPT = """Você é um pesquisador de sonhos clínico do Aion. Sua tarefa é analisar o relato de um sonho e identificar pontos cegos, símbolos potentes ou figuras ambíguas que precisam de mais contexto para uma interpretação real.

DIRETRIZES PARA AS PERGUNTAS:
1. Não interprete ainda. Apenas pergunte.
2. Identifique o símbolo mais forte e peça uma associação pessoal (ex: "O que [X] te lembra na sua vida real agora?").
3. Se houver uma pessoa conhecida no sonho, pergunte como está a relação com ela hoje.
4. Se o cenário for marcante, pergunte se o usuário já viveu algo parecido recentemente.
5. Se houver uma emoção intensa, pergunte a que situação real ela pode estar conectada.
6. Seja empático, breve e use linguagem próxima — "você" e "seu/sua".

FORMATO DE SAÍDA OBRIGATÓRIO:
Responda APENAS com um JSON válido neste formato exato:
{
  "perguntas": [
    "Primeira pergunta aqui?",
    "Segunda pergunta aqui?",
    "Terceira pergunta aqui?"
  ]
}

Gere exatamente 3 perguntas. Nada mais."""

# ─────────────────────────────────────────────
# PROMPT: LEITURA SIMBÓLICA (NARRATIVA)
# ─────────────────────────────────────────────
NARRATIVE_SYSTEM_PROMPT = """Você é Aion. Fale com a pessoa como um amigo sábio — não como um professor ou terapeuta.

Leia o sonho e responda em 3 movimentos curtos, sem títulos ou subtítulos:

Primeiro: diga o que o sonho está revelando sobre o momento de vida da pessoa. Seja direto. Uma ou duas frases.

Segundo: escolha o símbolo mais importante do sonho e explique o que ele significa na vida real dessa pessoa. Se houver um mito ou história que ilumine isso, mencione de passagem — em uma frase simples, sem explicação histórica.

Terceiro: termine com a pergunta exata que será indicada no campo PERGUNTA_FINAL. Não altere uma palavra. Não crie uma pergunta diferente.

Regras absolutas:
- Nunca use: arquétipo, inconsciente, individuação, amplificação, psíquico, Self, compensatório, projeção, ou qualquer termo de psicologia
- Nada de metáforas poéticas exageradas
- Máximo 180 palavras no total
- Use "você" e "seu/sua" — português do Brasil direto
- Não crie seções, títulos ou listas — texto corrido como uma conversa
- A última frase DEVE ser exatamente a PERGUNTA_FINAL fornecida"""


def _build_contexto_estruturado(
    tags_emocao: list = None,
    temas: list = None,
    residuos_diurnos: list = None,
    interview_answers: list = None,
) -> str:
    """Monta o bloco de contexto estruturado para injetar no prompt."""
    lines = []

    if tags_emocao:
        lines.append(f"- EMOÇÕES SENTIDAS NO SONHO: {', '.join(tags_emocao)}")
    if temas:
        lines.append(f"- TEMAS IDENTIFICADOS: {', '.join(temas)}")
    if residuos_diurnos:
        lines.append(f"- CONTEXTO DE VIDA (dia anterior): {', '.join(residuos_diurnos)}")
    if interview_answers:
        lines.append("\nASSOCIAÇÕES PESSOAIS DO SONHADOR (use para personalizar a análise):")
        for item in interview_answers:
            lines.append(f"  Pergunta: {item.get('pergunta', '')}")
            lines.append(f"  Resposta: {item.get('resposta', '')}")

    if not lines:
        return ""

    return "\n\nCONTEXTO ADICIONAL (integre à análise sem repetir literalmente):\n" + "\n".join(lines)


async def generate_interview_questions(dream_text: str) -> list:
    """Gera 3 perguntas cirúrgicas sobre o relato do sonho."""
    print("[AI_SERVICE] Gerando perguntas de entrevista...")
    try:
        message = await async_client.messages.create(
            model="claude-3-5-sonnet-20240620",
            max_tokens=512,
            system=INTERVIEW_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Sonho: {dream_text}"}],
        )
        content = message.content[0].text
        start = content.find('{')
        end = content.rfind('}')
        if start != -1 and end != -1:
            data = json.loads(content[start:end+1])
            return data.get("perguntas", [])
        return []
    except Exception as e:
        print(f"[AI_SERVICE] Erro ao gerar perguntas: {e}")
        raise e


async def analyze_dream(
    dream_text: str,
    tags_emocao: list = None,
    temas: list = None,
    residuos_diurnos: list = None,
    interview_answers: list = None,
    context: dict = None,
) -> dict:
    """Analisa o sonho com todo o contexto disponível."""
    print("[AI_SERVICE] Iniciando análise com Claude.")

    contexto = _build_contexto_estruturado(
        tags_emocao=tags_emocao,
        temas=temas,
        residuos_diurnos=residuos_diurnos,
        interview_answers=interview_answers,
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)

    modelos = [
        "claude-3-5-sonnet-20240620",
    ]

    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}...")
            message = await async_client.messages.create(
                model=model_name,
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt}]
            )
            return _parse_ai_json(message.content[0].text)
        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro com {model_name}: {e}")
            continue

    return _get_error_response(f"Falha técnica: {ultimo_erro}")


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    """Interpretação narrativa ancorada na análise estruturada."""
    context_block = ""

    if analysis_context:
        essencia = analysis_context.get("essencia", "")
        arquetipos = ", ".join(
            [a.get("nome", "") for a in analysis_context.get("arquetipos", [])]
        )
        mito = analysis_context.get("mito_espelho", {}).get("titulo", "")
        fase = analysis_context.get("fase_jornada", {}).get("nome", "")
        pergunta_final = analysis_context.get("pergunta_para_reflexao", "")

        context_block = f"""

CONTEXTO DA ANÁLISE (use para manter coerência — não repita literalmente):
- Essência: {essencia}
- Arquétipos identificados: {arquetipos}
- Mito espelho: {mito}
- Fase da Jornada: {fase}

PERGUNTA_FINAL (copie esta frase exatamente como última frase da sua resposta — não altere nada):
{pergunta_final}"""

    try:
        message = await async_client.messages.create(
            model="claude-3-5-sonnet-20240620",
            max_tokens=1024,
            system=NARRATIVE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Sonho: {dream_text}{context_block}"}],
        )
        return message.content[0].text
    except Exception as e:
        print(f"[AI_SERVICE] Erro na narrativa: {e}")
        raise e


def _parse_ai_json(content: str) -> dict:
    try:
        start = content.find('{')
        end = content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1])
        return json.loads(content.strip())
    except Exception as e:
        print(f"[AI_SERVICE] Falha ao decodificar JSON: {content[:100]}")
        raise ValueError(f"Formato de resposta inválido: {str(e)}")


def _get_error_response(error_msg: str) -> dict:
    print(f"[DEBUG_ORACULO] Erro: {error_msg}")
    return {
        "aviso": "O Oráculo está em silêncio profundo.",
        "essencia": "O silêncio também é uma mensagem. Tente novamente em instantes.",
        "arquetipos": [],
        "funcao_compensatoria": "Aguardando clareza técnica.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Limiar", "descricao": "O Oráculo está se reequilibrando."},
        "prospeccao": "Aguarde o próximo momento.",
        "mito_espelho": {"titulo": "O Silêncio de Jó", "paralelo": "A resposta virá no tempo certo."},
        "pergunta_para_reflexao": "O que o silêncio faz você sentir?",
        "intensidade_sombra": 0,
        "intensidade_heroi": 0,
        "intensidade_transformacao": 0
    }


async def process_voice_input(audio_file):
    pass

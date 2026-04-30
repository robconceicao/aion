import json
import anthropic
from app.core.config import settings

# Cliente assíncrono — essencial para não bloquear o event loop do FastAPI
if not settings.ANTHROPIC_API_KEY:
    print("\n[CRÍTICO] ANTHROPIC_API_KEY está VAZIA. O Oráculo não poderá responder.\n")

async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — um analista junguiano de senioridade excepcional.
Sua tarefa é realizar uma 'Amplificação Junguiana' profunda, mas OBJETIVA e DIRETA do sonho abaixo.

DIRETRIZ DE LINGUAGEM E VELOCIDADE:
1. Use o português do Brasil coloquial: use "VOCÊ" e "SEU/SUA" (nunca use "Tu" ou "Vós").
2. Seja conciso: vá direto ao ponto para que a resposta seja gerada rapidamente.
3. Use um tom sábio e acolhedor, explicando termos técnicos de forma simples.

SONHO: {texto}

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


async def analyze_dream(dream_text: str, context: dict = None) -> dict:
    """Analisa o sonho usando Claude async — não bloqueia o event loop."""
    print(f"[AI_SERVICE] Iniciando análise profissional com Claude.")

    prompt = PROMPT_TEMPLATE.format(texto=dream_text)

    modelos = [
        "claude-sonnet-4-6",
        "claude-sonnet-4-5-20250929",
        "claude-3-5-sonnet-latest",
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
            content = message.content[0].text
            return _parse_ai_json(content)

        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro crítico com {model_name}: {e}")
            continue

    return _get_error_response(f"Falha técnica: {ultimo_erro}")


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    """
    Retorna a interpretação narrativa do sonho.
    Recebe o contexto da análise estruturada para garantir coerência
    e usar exatamente a mesma pergunta para reflexão.
    """
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

    user_content = f"Sonho: {dream_text}{context_block}"

    try:
        message = await async_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=1024,
            system=NARRATIVE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_content}],
        )
        return message.content[0].text
    except Exception as e:
        print(f"[AI_SERVICE] Erro na narrativa: {e}")
        raise e


def _parse_ai_json(content: str) -> dict:
    """Limpa e parseia o JSON de forma robusta, ignorando textos extras."""
    try:
        start = content.find('{')
        end = content.rfind('}')
        if start != -1 and end != -1:
            json_str = content[start:end+1]
            return json.loads(json_str)
        return json.loads(content.strip())
    except Exception as e:
        print(f"[AI_SERVICE] Falha ao decodificar JSON. Conteúdo bruto: {content[:100]}")
        raise ValueError(f"Formato de resposta inválido: {str(e)}")


def _get_error_response(error_msg: str) -> dict:
    print(f"[DEBUG_ORACULO] Gerando resposta de erro: {error_msg}")
    return {
        "aviso": "O Oráculo está em silêncio profundo.",
        "essencia": "O silêncio também é uma mensagem do inconsciente. Tente novamente em instantes.",
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

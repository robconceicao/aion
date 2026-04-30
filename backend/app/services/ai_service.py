import json
import anthropic
from sentence_transformers import SentenceTransformer
from app.core.config import settings

if not settings.ANTHROPIC_API_KEY:
    print("\n[CRÍTICO] ANTHROPIC_API_KEY está VAZIA.\n")

async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

# Modelo de embedding — singleton carregado na primeira chamada
_embedding_model = None

def get_embedding_model() -> SentenceTransformer:
    global _embedding_model
    if _embedding_model is None:
        print("[AI_SERVICE] Carregando modelo de embedding...")
        # Usamos o modelo multilingual para suportar Português nativamente
        _embedding_model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
        print("[AI_SERVICE] Modelo pronto.")
    return _embedding_model


def generate_embedding(text: str) -> list:
    """Gera vetor de 384 dimensões a partir do texto."""
    model = get_embedding_model()
    embedding = model.encode(text, normalize_embeddings=True)
    return embedding.tolist()


# ─── PROMPTS ──────────────────────────────────────────────────

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — analista junguiano de senioridade excepcional.
Realize uma Amplificação Junguiana profunda do sonho abaixo.

DIRETRIZ DE LINGUAGEM:
1. Use "VOCÊ" e "SEU/SUA" — português do Brasil. Nunca "Tu" ou "Vós".
2. Tom sábio, acolhedor e direto.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

INSTRUÇÃO CRÍTICA: Responda APENAS com JSON válido:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui o psicólogo.",
  "essencia": "O coração do sonho em 2 frases diretas e profundas.",
  "arquetipos": [
    {{ "nome": "Nome do Arquétipo", "simbolo": "emoji", "descricao": "Como esta força age em você." }}
  ],
  "funcao_compensatoria": "O que seu interior está equilibrando agora.",
  "simbolos_chave": [
    {{ "elemento": "Item do sonho", "significado": "O que isso representa para você." }}
  ],
  "fase_jornada": {{
    "nome": "Uma destas fases EXATAS: O Mundo Comum | O Chamado | A Recusa do Chamado | O Encontro com o Mentor | A Travessia do Limiar | Provas e Aliados | O Abismo | A Recompensa | O Caminho de Volta | A Ressurreição | O Retorno",
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

RECURRENCE_SYSTEM_PROMPT = """Você é Aion. O usuário tem um padrão de sonhos recorrentes.
Analise a EVOLUÇÃO do símbolo ao longo do tempo — não interprete o sonho atual isoladamente.

DIRETRIZES:
1. Identifique o que MUDOU entre os sonhos anteriores e o atual.
2. Explique que a repetição é um convite para dar atenção a algo não resolvido.
3. Foque no progresso ou estagnação do tema — não repita interpretações antigas.
4. Use "você" e "seu/sua". Tom empático e direto. Máximo 200 palavras.
5. Texto corrido, sem títulos. Termine com uma pergunta sobre a evolução do padrão."""

INTERVIEW_SYSTEM_PROMPT = """Você é um pesquisador de sonhos clínico do Aion.
Analise o relato e identifique pontos cegos que precisam de mais contexto.

DIRETRIZES: Não interprete ainda. Apenas pergunte. Use "você" e "seu/sua".

FORMATO OBRIGATÓRIO — apenas JSON:
{
  "perguntas": ["Primeira pergunta?", "Segunda pergunta?", "Terceira pergunta?"]
}"""

NARRATIVE_SYSTEM_PROMPT = """Você é Aion. Fale como um amigo sábio — não professor ou terapeuta.

Responda em 3 movimentos curtos, sem títulos:

Primeiro: o que o sonho revela sobre o momento de vida da pessoa. 1-2 frases diretas.
Segundo: o símbolo mais importante e seu significado real. Mito de passagem em 1 frase simples.
Terceiro: termine com a PERGUNTA_FINAL exata fornecida. Não altere nada.

Regras absolutas:
- Proibido: arquétipo, inconsciente, individuação, amplificação, psíquico, Self, compensatório, projeção
- Máximo 180 palavras. "você" e "seu/sua". Texto corrido. Última frase = PERGUNTA_FINAL exata."""


# ─── HELPERS ──────────────────────────────────────────────────

def _build_contexto(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao:
        lines.append(f"- EMOÇÕES: {', '.join(tags_emocao)}")
    if temas:
        lines.append(f"- TEMAS: {', '.join(temas)}")
    if residuos_diurnos:
        lines.append(f"- CONTEXTO DO DIA ANTERIOR: {', '.join(residuos_diurnos)}")
    if interview_answers:
        lines.append("\nASSOCIAÇÕES PESSOAIS:")
        for item in interview_answers:
            lines.append(f"  P: {item.get('pergunta', '')}")
            lines.append(f"  R: {item.get('resposta', '')}")
    if not lines:
        return ""
    return "\n\nCONTEXTO ADICIONAL:\n" + "\n".join(lines)


def _parse_ai_json(content: str) -> dict:
    try:
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1])
        return json.loads(content.strip())
    except Exception as e:
        raise ValueError(f"JSON inválido: {str(e)}")


def _get_error_response(error_msg: str) -> dict:
    return {
        "aviso": "O Oráculo está em silêncio profundo.",
        "essencia": "O silêncio também é uma mensagem. Tente novamente.",
        "arquetipos": [], "funcao_compensatoria": "Aguardando.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Mundo Comum", "descricao": "Reequilibrando."},
        "prospeccao": "Aguarde.",
        "mito_espelho": {"titulo": "O Silêncio de Jó", "paralelo": "A resposta virá."},
        "pergunta_para_reflexao": "O que o silêncio faz você sentir?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0,
    }


# ─── FUNÇÕES DE IA ────────────────────────────────────────────

async def analyze_dream(
    dream_text: str,
    tags_emocao=None, temas=None, residuos_diurnos=None,
    interview_answers=None, context: dict = None,
) -> dict:
    contexto = _build_contexto(tags_emocao, temas, residuos_diurnos, interview_answers)
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    # Modelos prioritários (Claude 3.5 Sonnet é o ideal para Jung)
    modelos = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-sonnet-latest", 
        "claude-3-5-sonnet-20240620",
    ]
    
    ultimo_erro = None
    for model_name in modelos:
        try:
            message = await async_client.messages.create(
                model=model_name, max_tokens=2048,
                messages=[{"role": "user", "content": prompt}]
            )
            return _parse_ai_json(message.content[0].text)
        except Exception as e:
            ultimo_erro = str(e)
            continue
    return _get_error_response(f"Falha: {ultimo_erro}")


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    """Analisa evolução de símbolo recorrente ao longo do tempo."""
    history = "\n\nSONHOS ANTERIORES SIMILARES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:200]
        created = (d.get("created_at") or "")[:10]
        history += f"\n[{i}] ({created}): {relato}..."
    try:
        message = await async_client.messages.create(
            model="claude-3-5-sonnet-20241022", max_tokens=512,
            system=RECURRENCE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Sonho atual: {current_dream}{history}"}],
        )
        return message.content[0].text
    except Exception as e:
        print(f"[AI_SERVICE] Erro recorrência: {e}")
        return ""


async def generate_interview_questions(dream_text: str) -> list:
    try:
        message = await async_client.messages.create(
            model="claude-3-5-sonnet-20241022", max_tokens=512,
            system=INTERVIEW_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Sonho: {dream_text}"}],
        )
        content = message.content[0].text
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1]).get("perguntas", [])
        return []
    except Exception as e:
        print(f"[AI_SERVICE] Erro entrevista: {e}")
        raise e


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    context_block = ""
    if analysis_context:
        pergunta = analysis_context.get("pergunta_para_reflexao", "")
        context_block = f"""

CONTEXTO (coerência — não repita):
- Essência: {analysis_context.get('essencia', '')}
- Arquétipos: {', '.join([a.get('nome','') for a in analysis_context.get('arquetipos',[])])}
- Mito: {analysis_context.get('mito_espelho',{}).get('titulo','')}
- Fase: {analysis_context.get('fase_jornada',{}).get('nome','')}

PERGUNTA_FINAL (última frase exata — não altere):
{pergunta}"""
    try:
        message = await async_client.messages.create(
            model="claude-3-5-sonnet-20241022", max_tokens=1024,
            system=NARRATIVE_SYSTEM_PROMPT,
            messages=[{"role": "user", "content": f"Sonho: {dream_text}{context_block}"}],
        )
        return message.content[0].text
    except Exception as e:
        print(f"[AI_SERVICE] Erro narrativa: {e}")
        raise e

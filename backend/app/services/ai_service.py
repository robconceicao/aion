import json
import anthropic
from sentence_transformers import SentenceTransformer
from app.core.config import settings

if not settings.ANTHROPIC_API_KEY:
    print("\n[CRÍTICO] ANTHROPIC_API_KEY está VAZIA.\n")

async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

# Lista de modelos por prioridade para evitar erros 404
AI_MODELS = [
    "claude-3-5-sonnet-20241022", # Sonnet 3.5 New
    "claude-3-5-sonnet-20240620", # Sonnet 3.5 v1
    "claude-3-opus-20240229",    # Opus
]

# Modelo de embedding — singleton carregado na primeira chamada
_embedding_model = None

def get_embedding_model() -> SentenceTransformer:
    global _embedding_model
    if _embedding_model is None:
        print("[AI_SERVICE] Carregando modelo de embedding...")
        _embedding_model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
        print("[AI_SERVICE] Modelo pronto.")
    return _embedding_model


def generate_embedding(text: str) -> list:
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
  "mito_espelho": {{ "titulo": "Nome do Mito", "paralelo": "Conexão com sua histora." }},
  "intensidade_sombra": 1-10,
  "intensidade_heroi": 1-10,
  "intensidade_transformacao": 1-10
}}
"""

RECURRENCE_SYSTEM_PROMPT = """Você é Aion. O usuário tem um padrão de sonhos recorrentes.
Analise a EVOLUÇÃO do símbolo ao longo do tempo — não interprete o sonho atual isoladamente.
Foque no progresso ou estagnação do tema. Use "você" e "seu/sua". Máximo 200 palavras."""

INTERVIEW_SYSTEM_PROMPT = """Você é um pesquisador de sonhos clínico do Aion.
Analise o relato e identifique pontos cegos que precisam de mais contexto.
Não interprete ainda. Apenas pergunte. Use "você" e "seu/sua". APENAS JSON."""

NARRATIVE_SYSTEM_PROMPT = """Você é Aion. Fale como um amigo sábio.
Responda em 3 movimentos curtos, sem títulos. Texto corrido. Máximo 180 palavras.
Termine com a PERGUNTA_FINAL exata fornecida."""


# ─── HELPERS ──────────────────────────────────────────────────

async def call_claude(system_prompt: str, user_content: str, max_tokens=1024):
    """Tenta chamar o Claude com fallback de modelos para evitar erros 404."""
    ultimo_erro = None
    for model_name in AI_MODELS:
        try:
            message = await async_client.messages.create(
                model=model_name,
                max_tokens=max_tokens,
                system=system_prompt,
                messages=[{"role": "user", "content": user_content}]
            )
            return message.content[0].text
        except Exception as e:
            print(f"[AI_SERVICE] Erro no modelo {model_name}: {e}")
            ultimo_erro = e
            continue
    raise ultimo_erro

def _parse_ai_json(content: str) -> dict:
    try:
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1])
        return json.loads(content.strip())
    except Exception as e:
        raise ValueError(f"JSON inválido: {str(e)}")


# ─── FUNÇÕES DE IA ────────────────────────────────────────────

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    from app.services.ai_service import _build_contexto # lazy import
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'), 
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    try:
        content = await call_claude("", prompt, max_tokens=2048)
        return _parse_ai_json(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal análise: {e}")
        from app.services.ai_service import _get_error_response
        return _get_error_response(str(e))


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    history = "\n\nSONHOS ANTERIORES SIMILARES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:200]
        history += f"\n[{i}]: {relato}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Sonho atual: {current_dream}{history}", max_tokens=512)
    except Exception as e:
        print(f"[AI_SERVICE] Erro recorrência: {e}")
        return ""


async def generate_interview_questions(dream_text: str) -> list:
    try:
        content = await call_claude(INTERVIEW_SYSTEM_PROMPT, f"Sonho: {dream_text}", max_tokens=512)
        return _parse_ai_json(content).get("perguntas", [])
    except Exception as e:
        print(f"[AI_SERVICE] Erro entrevista: {e}")
        return ["Como você se sentiu ao acordar?", "O que esse sonho lembra da sua vida?", "Qual era a cor predominante?"]


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    context_block = ""
    if analysis_context:
        pergunta = analysis_context.get("pergunta_para_reflexao", "")
        context_block = f"\n\nCONTEXTO: {analysis_context.get('essencia','')}\nPERGUNTA_FINAL: {pergunta}"
    
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho: {dream_text}{context_block}", max_tokens=1024)
    except Exception as e:
        print(f"[AI_SERVICE] Erro narrativa: {e}")
        return "O Oráculo está processando sua mensagem em silêncio..."

def _build_contexto(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao: lines.append(f"- EMOÇÕES: {', '.join(tags_emocao)}")
    if temas: lines.append(f"- TEMAS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"- CONTEXTO: {', '.join(residuos_diurnos)}")
    if interview_answers:
        for item in interview_answers:
            lines.append(f"  P: {item.get('pergunta', '')}\n  R: {item.get('resposta', '')}")
    return "\n\nCONTEXTO ADICIONAL:\n" + "\n".join(lines) if lines else ""

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

import json
import anthropic
import google.generativeai as genai
import httpx
import re
from app.core.config import settings

# Clientes de IA
async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY) if settings.ANTHROPIC_API_KEY else None

# Configuração Gemini
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)

# Lista de modelos por prioridade (Versões 2026)
AI_MODELS = [
    "claude-sonnet-4-6",
    "claude-haiku-4-5-20251001",
    "claude-3-5-sonnet-20241022",
]

# ─── EMBEDDINGS (VIA GEMINI) ──────────────────────────────────

async def generate_embedding(text: str) -> list:
    """Gera embeddings usando o modelo do Google."""
    if not settings.GEMINI_API_KEY:
        return [0.0] * 768
        
    try:
        # Tentativa com o nome de modelo mais comum
        result = genai.embed_content(
            model="models/text-embedding-004",
            content=text,
            task_type="retrieval_document"
        )
        return result['embedding']
    except Exception as e:
        print(f"[AI_SERVICE] Erro embedding: {e}")
        # Segunda tentativa com nome alternativo
        try:
            result = genai.embed_content(model="models/embedding-001", content=text)
            return result['embedding']
        except:
            return [0.0] * 768


# ─── HELPERS DE IA ────────────────────────────────────────────

async def call_claude(system_prompt: str, user_content: str, max_tokens=1024):
    if not async_client:
        return await call_gemini(system_prompt, user_content)

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
            if "not_found_error" in str(e).lower() or "404" in str(e):
                continue 
            break 
            
    return await call_gemini(system_prompt, user_content)


async def call_gemini(system_prompt: str, user_content: str):
    if not settings.GEMINI_API_KEY:
        raise ValueError("Nenhuma chave de IA disponível.")
    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        full_prompt = f"{system_prompt}\n\nUSUÁRIO: {user_content}"
        response = model.generate_content(full_prompt)
        return response.text
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal no Gemini: {e}")
        raise e


def _parse_ai_json(content: str) -> dict:
    try:
        content = content.strip()
        content = re.sub(r'```json\s*|\s*```', '', content)
        
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            content = content[start:end+1]
        
        # Limpeza de caracteres de controle e quebras de linha dentro de valores
        content = content.replace('\n', ' ').replace('\r', '')
        # Remove vírgulas extras
        content = re.sub(r',\s*([\}\]])', r'\1', content)
        
        return json.loads(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro parse: {e}")
        # Tenta uma limpeza ainda mais agressiva (remove espaços duplos)
        try:
            content = re.sub(r'\s+', ' ', content)
            return json.loads(content)
        except:
            raise ValueError(f"JSON inválido: {str(e)}")


# ─── FUNÇÕES DO AION ──────────────────────────────────────────

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    from app.services.ai_service import PROMPT_TEMPLATE, _build_contexto, _get_error_response
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
        return _get_error_response(str(e))


async def generate_interview_questions(dream_text: str) -> list:
    from app.services.ai_service import INTERVIEW_SYSTEM_PROMPT
    try:
        content = await call_claude(INTERVIEW_SYSTEM_PROMPT, f"Sonho: {dream_text}", max_tokens=512)
        data = _parse_ai_json(content)
        return data.get("perguntas", [])
    except Exception as e:
        return ["Como você se sentiu?", "O que lembra da vida?", "Qual era a cor?"]


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    from app.services.ai_service import RECURRENCE_SYSTEM_PROMPT
    history = "\n\nANTERIORES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        history += f"\n[{i}]: {d.get('relato','')[:150]}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Atual: {current_dream}{history}", max_tokens=512)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    from app.services.ai_service import NARRATIVE_SYSTEM_PROMPT
    context_block = ""
    if analysis_context:
        context_block = f"\n\nCONTEXTO: {analysis_context.get('essencia','')}"
    
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho: {dream_text}{context_block}", max_tokens=1024)
    except Exception as e:
        return "O Oráculo aguarda em silêncio..."


# ─── PROMPTS ──────────────────────────────────────────────────

PROMPT_TEMPLATE = """
Aion, analista junguiano. Amplifique este sonho. 
IMPORTANTE: Seja direto e profundo, evite descrições longas. Máximo 4000 caracteres no total.
Responda APENAS JSON.

SONHO: {texto}
{contexto_estruturado}

JSON:
{{
  "aviso": "Reflexão simbólica...",
  "essencia": "...",
  "arquetipos": [{{ "nome": "...", "simbolo": "...", "descricao": "..." }}],
  "funcao_compensatoria": "...",
  "simbolos_chave": [{{ "elemento": "...", "significado": "..." }}],
  "fase_jornada": {{ "nome": "...", "descricao": "..." }},
  "prospeccao": "...",
  "pergunta_para_reflexao": "...",
  "mito_espelho": {{ "titulo": "...", "paralela": "..." }},
  "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = "Aion. 3 perguntas curtas. JSON: {\"perguntas\": [\"...\", \"...\", \"...\"]}"
RECURRENCE_SYSTEM_PROMPT = "Evolução do símbolo. Máximo 150 palavras."
NARRATIVE_SYSTEM_PROMPT = "Amigo sábio. 3 movimentos. Máximo 150 palavras."

def _build_contexto(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao: lines.append(f"EMOÇÕES: {', '.join(tags_emocao)}")
    if temas: lines.append(f"TEMAS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"ONTEM: {', '.join(residuos_diurnos)}")
    if interview_answers:
        for item in interview_answers:
            lines.append(f"P: {item.get('pergunta','')}\nR: {item.get('resposta','')}")
    return "\nCONTEXTO:\n" + "\n".join(lines) if lines else ""

def _get_error_response(error_msg: str) -> dict:
    return {
        "aviso": "Silêncio profundo.",
        "essencia": "O silêncio é uma mensagem. Tente novamente.",
        "arquetipos": [], "funcao_compensatoria": "Aguardando.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Mundo Comum", "descricao": "Reequilibrando."},
        "prospeccao": "Aguarde.",
        "mito_espelho": {"titulo": "O Silêncio", "paralela": "Aguarde."},
        "pergunta_para_reflexao": "O que o silêncio diz?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0,
    }

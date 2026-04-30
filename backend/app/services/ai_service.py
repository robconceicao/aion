import json
import anthropic
import google.generativeai as genai
import httpx
from app.core.config import settings

# Clientes de IA
async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY) if settings.ANTHROPIC_API_KEY else None

# Configuração Gemini
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)

# Lista de modelos por prioridade (Versões 2026)
AI_MODELS = [
    "claude-sonnet-4-6",          # Sonnet mais recente
    "claude-haiku-4-5-20251001",  # Haiku mais recente
    "claude-3-5-sonnet-20241022", # Fallback 2024
    "claude-3-haiku-20240307",   # Fallback 2024
]

# ─── EMBEDDINGS (VIA REMOTE API - MEMORY SAVER) ────────────────

async def generate_embedding(text: str) -> list:
    """Gera embeddings via Hugging Face API (Gratuito) para economizar RAM."""
    model_id = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    api_url = f"https://api-inference.huggingface.co/pipeline/feature-extraction/{model_id}"
    
    # Nota: Se quiser mais estabilidade, adicione uma HF_TOKEN nas variáveis de ambiente.
    # Mas para uso moderado, a API funciona sem token.
    headers = {}
    
    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(
                api_url, 
                headers=headers, 
                json={"inputs": text, "options": {"wait_for_model": True}},
                timeout=20.0
            )
            if response.status_code == 200:
                return response.json()
            else:
                print(f"[AI_SERVICE] Erro embedding remoto: {response.status_code}")
                # Fallback para zeros se a API falhar (evita crash total)
                return [0.0] * 384
        except Exception as e:
            print(f"[AI_SERVICE] Erro fatal embedding: {e}")
            return [0.0] * 384


# ─── HELPERS DE IA ────────────────────────────────────────────

async def call_claude(system_prompt: str, user_content: str, max_tokens=1024):
    """Tenta chamar o Claude com fallback. Se falhar, tenta o Gemini."""
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
    """Fallback final usando Google Gemini 1.5 Flash."""
    if not settings.GEMINI_API_KEY:
        raise ValueError("Nenhuma chave de IA (Anthropic ou Gemini) disponível.")
    
    print("[AI_SERVICE] Usando fallback Gemini 1.5 Flash...")
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
        content = content.replace("```json", "").replace("```", "").strip()
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1])
        return json.loads(content)
    except Exception as e:
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
        print(f"[AI_SERVICE] Erro entrevista: {e}")
        return ["Como você se sentiu ao acordar?", "O que esse sonho lembra da sua vida?", "Qual era a cor predominante?"]


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    from app.services.ai_service import RECURRENCE_SYSTEM_PROMPT
    history = "\n\nSONHOS ANTERIORES SIMILARES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:200]
        history += f"\n[{i}]: {relato}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Sonho atual: {current_dream}{history}", max_tokens=512)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    from app.services.ai_service import NARRATIVE_SYSTEM_PROMPT
    context_block = ""
    if analysis_context:
        pergunta = analysis_context.get("pergunta_para_reflexao", "")
        context_block = f"\n\nCONTEXTO: {analysis_context.get('essencia','')}\nPERGUNTA_FINAL: {pergunta}"
    
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho: {dream_text}{context_block}", max_tokens=1024)
    except Exception as e:
        return "O Oráculo está processando sua mensagem em silêncio..."


# ─── PROMPTS E AUXILIARES ──────────────────────────────────────

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — analista junguiano de senioridade excepcional.
Realize uma Amplificação Junguiana profunda do sonho abaixo.
Responda APENAS com JSON válido.

DIRETRIZ DE LINGUAGEM:
1. Use "VOCÊ" e "SEU/SUA" — português do Brasil.
2. Tom sábio, acolhedor e direto.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

JSON FORMAT:
{{
  "aviso": "Esta análise é uma reflexão simbólica...",
  "essencia": "...",
  "arquetipos": [{{ "nome": "...", "simbolo": "...", "descricao": "..." }}],
  "funcao_compensatoria": "...",
  "simbolos_chave": [{{ "elemento": "...", "significado": "..." }}],
  "fase_jornada": {{ "nome": "...", "descricao": "..." }},
  "prospeccao": "...",
  "pergunta_para_reflexao": "...",
  "mito_espelho": {{ "titulo": "...", "paralela": "..." }},
  "intensidade_sombra": 5,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = "Você é Aion. Analise o relato e identifique 3 pontos cegos. Responda APENAS JSON: {\"perguntas\": [\"...\", \"...\", \"...\"]}"
RECURRENCE_SYSTEM_PROMPT = "Analise a EVOLUÇÃO do símbolo recorrente. Máximo 200 palavras."
NARRATIVE_SYSTEM_PROMPT = "Fale como um amigo sábio. 3 movimentos curtos. Máximo 180 palavras."

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

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

# ─── EMBEDDINGS (VIA REMOTE API - 768 DIM) ────────────────────

async def generate_embedding(text: str) -> list:
    if not settings.GEMINI_API_KEY:
        return [0.0] * 768
    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key={settings.GEMINI_API_KEY}"
        async with httpx.AsyncClient() as client:
            res = await client.post(url, json={
                "model": "models/embedding-001",
                "content": {"parts": [{"text": text}]}
            })
            if res.status_code == 200:
                return res.json()['embedding']['values']
            return [0.0] * 768
    except:
        return [0.0] * 768


# ─── HELPERS DE IA ────────────────────────────────────────────

async def call_claude(system_prompt: str, user_content: str, max_tokens=3500):
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
    import re
    try:
        # 1. Limpeza básica e remoção de Markdown
        content = content.strip()
        content = re.sub(r'```json\s*|\s*```', '', content)
        
        # 2. Localiza o bloco JSON
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            content = content[start:end+1]
        
        # 3. Resolve problemas de quebra de linha dentro de strings JSON
        # Esta regex procura por quebras de linha que não estão precedendo uma chave ou fechamento
        content = re.sub(r'(?<![:{,])\n(?![}\],])', ' ', content)
        
        # 4. Remove vírgulas extras
        content = re.sub(r',\s*([\}\]])', r'\1', content)
        
        return json.loads(content)
    except Exception as e:
        try:
            # Fallback final: remove TODAS as quebras de linha para sanitizar
            cleaned = re.sub(r'\s+', ' ', content)
            return json.loads(cleaned)
        except:
            print(f"[AI_SERVICE] Falha total parse JSON. Erro: {e}")
            raise ValueError(f"JSON inválido: {str(e)}")


# ─── FUNÇÕES DO AION (ALMA JUNG & CAMPBELL) ───────────────────

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    from app.services.ai_service import PROMPT_TEMPLATE, _build_contexto, _get_error_response
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'), 
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    try:
        # Aumentamos o limite de tokens para permitir análises profundas
        content = await call_claude("", prompt, max_tokens=4000)
        return _parse_ai_json(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal análise: {e}")
        return _get_error_response(str(e))


async def generate_interview_questions(dream_text: str) -> list:
    from app.services.ai_service import INTERVIEW_SYSTEM_PROMPT
    try:
        content = await call_claude(INTERVIEW_SYSTEM_PROMPT, f"Sonho: {dream_text}", max_tokens=1000)
        data = _parse_ai_json(content)
        return data.get("perguntas", [])
    except Exception as e:
        return ["Como você se sentiu?", "O que lembra da vida?", "Qual era a sensação?"]


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    from app.services.ai_service import RECURRENCE_SYSTEM_PROMPT
    history = "\n\nANTERIORES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:300]
        history += f"\n[{i}]: {relato}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Atual: {current_dream}{history}", max_tokens=1200)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    from app.services.ai_service import NARRATIVE_SYSTEM_PROMPT
    context_block = ""
    if analysis_context:
        essencia = analysis_context.get('essencia','')
        arquetipos = str(analysis_context.get('arquetipos',[]))
        pergunta = analysis_context.get('pergunta_para_reflexao', '')
        context_block = f"\n\nESSÊNCIA: {essencia}\nARQUÉTIPOS: {arquetipos}\nPERGUNTA_FINAL: {pergunta}"
    
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho: {dream_text}{context_block}", max_tokens=2000)
    except Exception as e:
        return "O Oráculo aguarda em silêncio sagrado..."


# ─── PROMPTS DEFINITIVOS (EXCELÊNCIA) ─────────────────────────

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique. Você é a união da senioridade de C.G. Jung com a sabedoria narrativa de Joseph Campbell.

SUA MISSÃO: 
Realizar uma Amplificação profunda que conecte os símbolos da PSIQUE (Jung: Sombra, Anima, Individuação) aos estágios do MITO (Campbell: Jornada do Herói).

REGRAS DE RESPOSTA (CRÍTICAS):
1. Use tom poético, iniciático e acolhedor.
2. Seja profundo. Explore o significado oculto sob a superfície.
3. Responda APENAS JSON válido.
4. IMPORTANTE: Não use quebras de linha (Enter) dentro dos valores das strings no JSON. Use '\\n' se precisar pular linha no texto.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

JSON FORMAT:
{{
  "aviso": "Análise simbólica baseada em Jung e Campbell.",
  "essencia": "O núcleo dinâmico do sonho unindo individuação e jornada mítica.",
  "arquetipos": [
    {{ "nome": "...", "simbolo": "...", "descricao": "Papel psicológico e místico deste elemento." }}
  ],
  "funcao_compensatoria": "Como a psique busca o equilíbrio através deste sonho?",
  "simbolos_chave": [
    {{ "elemento": "...", "significado": "Visão junguiana e campbelliana combinadas." }}
  ],
  "fase_jornada": {{ "nome": "...", "descricao": "Localização no Monomito de Campbell." }},
  "prospeccao": "O sinal do Self para o futuro.",
  "pergunta_para_reflexao": "Uma questão para levar ao Mundo Comum.",
  "mito_espelho": {{ "titulo": "...", "paralela": "O mito que reflete esta jornada." }},
  "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = "Você é Aion. Analise o relato e identifique 3 pontos cegos sob a ótica de Jung e Campbell. JSON: {\"perguntas\": [\"...\", \"...\", \"...\"]}"
RECURRENCE_SYSTEM_PROMPT = "Analise a evolução dos símbolos como capítulos de uma saga mítica em desenvolvimento. Máximo 250 palavras."
NARRATIVE_SYSTEM_PROMPT = "Fale como um mestre que une Jung e Campbell. Transforme a análise em um texto corrido, fluido e profundo que sirva de espelho para o Mapa Arquetípico do sonhador. Use uma linguagem acolhedora e sábia. IMPORTANTE: Encerre o texto obrigatoriamente com a PERGUNTA_FINAL fornecida no contexto. Máximo 300 palavras."

def _build_contexto(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao: lines.append(f"EMOÇÕES: {', '.join(tags_emocao)}")
    if temas: lines.append(f"TEMAS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"CONTEÚDO DIURNO: {', '.join(residuos_diurnos)}")
    if interview_answers:
        for item in interview_answers:
            lines.append(f"P: {item.get('pergunta', '')} | R: {item.get('resposta', '')}")
    return "\nCONTEXTO ADICIONAL:\n" + "\n".join(lines) if lines else ""

def _get_error_response(error_msg: str) -> dict:
    return {
        "aviso": "O Oráculo está em silêncio profundo.",
        "essencia": "O silêncio também é uma mensagem. Tente novamente.",
        "arquetipos": [], "funcao_compensatoria": "Aguardando.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Mundo Comum", "descricao": "Reequilibrando."},
        "prospeccao": "Aguarde.",
        "mito_espelho": {"titulo": "O Silêncio", "paralela": "Aguarde."},
        "pergunta_para_reflexao": "O que o silêncio faz você sentir?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0,
    }

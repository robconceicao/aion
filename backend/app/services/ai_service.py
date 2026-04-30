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
    """Gera embeddings via Hugging Face para manter 768 dimensões com estabilidade."""
    model_id = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    # Nota: Embora o modelo seja 384 nativo, vamos garantir que o banco aceite.
    # Como o seu banco foi alterado para 768, vou usar o modelo do Google fixado.
    if not settings.GEMINI_API_KEY:
        return [0.0] * 768
        
    try:
        # Forçando o uso do modelo via REST direto para evitar erros do SDK
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

async def call_claude(system_prompt: str, user_content: str, max_tokens=2500):
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
        # 1. Limpeza básica
        content = content.strip()
        # 2. Extrai apenas o que está entre as primeiras e últimas chaves
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            content = content[start:end+1]
        
        # 3. Remove blocos de código se ainda restarem
        content = re.sub(r'```json\s*|\s*```', '', content)
        
        # 4. Remove vírgulas extras antes de fechar chaves ou colchetes
        content = re.sub(r',\s*([\}\]])', r'\1', content)
        
        # 5. Tenta o parse direto primeiro (mais seguro)
        return json.loads(content)
    except Exception as e:
        # 6. Fallback agressivo: remove quebras de linha que não estão entre aspas
        try:
            # Substitui quebras de linha por espaços para não quebrar a estrutura
            content_flat = content.replace('\n', ' ').replace('\r', ' ')
            return json.loads(content_flat)
        except:
            print(f"[AI_SERVICE] Falha total no parse. Erro: {e}")
            raise ValueError(f"JSON inválido: {str(e)}")


# ─── FUNÇÕES DO AION (ALMA RESTAURADA) ────────────────────────

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    from app.services.ai_service import PROMPT_TEMPLATE, _build_contexto, _get_error_response
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'), 
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    try:
        # Claude Sonnet é o preferencial para a profundidade junguiana
        content = await call_claude("", prompt, max_tokens=3000)
        return _parse_ai_json(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal análise: {e}")
        return _get_error_response(str(e))


async def generate_interview_questions(dream_text: str) -> list:
    from app.services.ai_service import INTERVIEW_SYSTEM_PROMPT
    try:
        content = await call_claude(INTERVIEW_SYSTEM_PROMPT, f"Sonho: {dream_text}", max_tokens=800)
        data = _parse_ai_json(content)
        return data.get("perguntas", [])
    except Exception as e:
        return ["Como você se sentiu nesse cenário?", "O que esse sonho lembra da sua história?", "Qual era a sensação predominante?"]


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    from app.services.ai_service import RECURRENCE_SYSTEM_PROMPT
    history = "\n\nSONHOS ANTERIORES SIMILARES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:250]
        history += f"\n[{i}]: {relato}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Sonho atual: {current_dream}{history}", max_tokens=1000)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    from app.services.ai_service import NARRATIVE_SYSTEM_PROMPT
    context_block = ""
    if analysis_context:
        context_block = f"\n\nESSÊNCIA: {analysis_context.get('essencia','')}\nARQUÉTIPOS: {str(analysis_context.get('arquetipos',[]))}"
    
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho: {dream_text}{context_block}", max_tokens=1500)
    except Exception as e:
        return "O Oráculo processa sua jornada em silêncio sagrado..."


# ─── PROMPTS (JUNG & CAMPBELL INTEGRADOS) ─────────────────────

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — analista junguiano e mitologista campbelliano.
Sua missão é realizar uma Amplificação Profunda que una a Psicologia Analítica de Jung com a Mitologia Comparada de Joseph Campbell.

DIRETRIZES DE PERSONA:
1. Use "VOCÊ" — português do Brasil.
2. Tom sábio, poético, acolhedor e iniciático.
3. Integre a dinâmica da PSIQUE (Jung: Sombra, Anima/Animus, Individuação) com a dinâmica do MITO (Campbell: Jornada do Herói, Chamado, Travessia do Limiar).

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

Responda APENAS com JSON válido seguindo este formato rigoroso:
{{
  "aviso": "Esta análise é uma reflexão simbólica baseada na união de C.G. Jung e Joseph Campbell...",
  "essencia": "O núcleo dinâmico do sonho, unindo o processo de individuação à jornada mítica.",
  "arquetipos": [
    {{ "nome": "...", "simbolo": "...", "descricao": "A força arquetípica segundo Jung e seu papel na jornada segundo Campbell." }}
  ],
  "funcao_compensatoria": "Como a psique busca o equilíbrio e qual 'etapa' da jornada está sendo sinalizada?",
  "simbolos_chave": [
    {{ "elemento": "...", "significado": "Significado simbólico (Jung) e mitológico (Campbell)." }}
  ],
  "fase_jornada": {{ "nome": "...", "descricao": "Localize o sonhador no Monomito de Campbell (ex: Ventre da Baleia, Estrada de Provas)." }},
  "prospeccao": "O que o Self sinaliza como próximo passo na grande travessia?",
  "pergunta_para_reflexao": "Uma questão para o sonhador levar ao seu 'Mundo Comum'.",
  "mito_espelho": {{ "titulo": "...", "paralela": "O mito ou lenda que serve de espelho para esta dinâmica." }},
  "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = "Você é Aion. Analise o relato e identifique 3 pontos cegos sob a ótica de Jung e Campbell. JSON: {\"perguntas\": [\"...\", \"...\", \"...\"]}"
RECURRENCE_SYSTEM_PROMPT = "Analise a evolução dos símbolos como capítulos de uma saga mítica em desenvolvimento. Máximo 250 palavras."
NARRATIVE_SYSTEM_PROMPT = "Fale como um mestre que une Jung e Campbell. Transforme a análise em uma narrativa de jornada em 3 atos curtos e profundos. Máximo 220 palavras."

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
        "mito_espelho": {"titulo": "O Silêncio", "paralela": "Aguarde."},
        "pergunta_para_reflexao": "O que o silêncio faz você sentir?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0,
    }

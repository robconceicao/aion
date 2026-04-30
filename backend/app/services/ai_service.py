import json
import anthropic
from app.core.config import settings

if not settings.ANTHROPIC_API_KEY:
    print("\n[CRÍTICO] ANTHROPIC_API_KEY está VAZIA. O Oráculo não poderá responder.\n")

try:
    # Passa uma chave dummy se estiver vazia apenas para não crashar o Uvicorn no boot
    api_key_safe = settings.ANTHROPIC_API_KEY if settings.ANTHROPIC_API_KEY else "sk-ant-dummy-key-to-prevent-crash"
    async_client = anthropic.AsyncAnthropic(api_key=api_key_safe)
except Exception as e:
    print(f"\n[CRÍTICO] Falha ao iniciar cliente Anthropic: {e}\n")
    async_client = None

# ─────────────────────────────────────────────
# PROMPT: ANÁLISE ESTRUTURADA (MAPA ARQUETÍPICO)
# ─────────────────────────────────────────────
PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — um analista junguiano de senioridade excepcional.
Sua tarefa é realizar uma 'Amplificação Junguiana' profunda do sonho abaixo.

DIRETRIZ DE LINGUAGEM:
1. Use o português do Brasil coloquial: use "VOCÊ" e "SEU/SUA".
2. Seja conciso e direto. Use um tom sábio e acolhedor.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

INSTRUÇÃO CRÍTICA: Responda APENAS com um JSON válido, seguindo exatamente este esquema:

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
    "nome": "Fase da Jornada",
    "descricao": "Seu momento atual de vida."
  }},
  "prospeccao": "Um sinal para seu futuro próximo.",
  "pergunta_para_reflexao": "Uma pergunta para você pensar hoje.",
  "mito_espelho": {{ "titulo": "Nome do Mito", "paralelo": "Conexão com sua história." }},
  "intensidade_sombra": 5,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = """Você é um pesquisador de sonhos clínico do Aion. Sua tarefa é analisar o relato de um sonho e identificar pontos cegos, símbolos potentes ou figuras ambíguas que precisam de mais contexto para uma interpretação real.

DIRETRIZES PARA AS PERGUNTAS:
1. Não interprete ainda. Apenas pergunte.
2. Identifique o símbolo mais forte e peça uma associação pessoal.
3. Se houver uma pessoa conhecida no sonho, pergunte como está a relação com ela hoje.

Responda APENAS com um JSON válido neste formato exato:
{
  "perguntas": [
    "Primeira pergunta aqui?",
    "Segunda pergunta aqui?",
    "Terceira pergunta aqui?"
  ]
}
Gere exatamente 3 perguntas."""

NARRATIVE_SYSTEM_PROMPT = """Você é Aion. Fale com a pessoa como um amigo sábio.

Leia o sonho e responda em 3 movimentos curtos, sem títulos:
Primeiro: diga o que o sonho está revelando.
Segundo: escolha o símbolo mais importante e explique.
Terceiro: termine com a pergunta exata que será indicada no campo PERGUNTA_FINAL.

Regras absolutas:
- Nunca use: arquétipo, inconsciente, individuação, amplificação, psíquico, Self
- A última frase DEVE ser exatamente a PERGUNTA_FINAL fornecida"""


def _build_contexto_estruturado(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao: lines.append(f"- EMOÇÕES SENTIDAS NO SONHO: {', '.join(tags_emocao)}")
    if temas: lines.append(f"- TEMAS IDENTIFICADOS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"- CONTEXTO DE VIDA: {', '.join(residuos_diurnos)}")
    if interview_answers:
        lines.append("\nASSOCIAÇÕES PESSOAIS:")
        for item in interview_answers:
            lines.append(f"  Pergunta: {item.get('pergunta', '')}")
            lines.append(f"  Resposta: {item.get('resposta', '')}")
    if not lines: return ""
    return "\n\nCONTEXTO ADICIONAL:\n" + "\n".join(lines)


async def generate_interview_questions(dream_text: str) -> list:
    print("[AI_SERVICE] Gerando perguntas de entrevista (Claude)...")
    
    # Adicionamos "anthropic/claude-3.5-sonnet" caso seja OpenRouter
    modelos = [
        "claude-sonnet-4-6",
        "claude-haiku-4-5-20251001"
    ]
    
    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}...")
            message = await async_client.messages.create(
                model=model_name,
                max_tokens=512,
                system=INTERVIEW_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": f"Sonho: {dream_text}"}],
            )
            content = message.content[0].text
            start = content.find('{')
            end = content.rfind('}')
            if start != -1 and end != -1:
                return json.loads(content[start:end+1]).get("perguntas", [])
            return []
        except Exception as e:
            ultimo_erro = str(e)
            continue
            
    print(f"[AI_SERVICE] Todos os modelos falharam. Erro: {ultimo_erro}")
    return []


async def analyze_dream(dream_text: str, tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None, context=None) -> dict:
    contexto = _build_contexto_estruturado(tags_emocao, temas, residuos_diurnos, interview_answers)
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    modelos = ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
    
    ultimo_erro = None
    for model_name in modelos:
        try:
            message = await async_client.messages.create(
                model=model_name,
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt}]
            )
            return _parse_ai_json(message.content[0].text)
        except Exception as e:
            ultimo_erro = str(e)
            continue
            
    return _get_error_response(f"Falha técnica: {ultimo_erro}")


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    context_block = ""
    if analysis_context:
        essencia = analysis_context.get("essencia", "")
        arquetipos = ", ".join([a.get("nome", "") for a in analysis_context.get("arquetipos", [])])
        mito = analysis_context.get("mito_espelho", {}).get("titulo", "")
        fase = analysis_context.get("fase_jornada", {}).get("nome", "")
        pergunta_final = analysis_context.get("pergunta_para_reflexao", "")
        context_block = f"\n\nCONTEXTO:\n- Essência: {essencia}\n- Arquétipos: {arquetipos}\n- Mito: {mito}\n- Fase: {fase}\n\nPERGUNTA_FINAL (copie exato):\n{pergunta_final}"

    modelos = ["claude-sonnet-4-6", "claude-haiku-4-5-20251001"]
    
    ultimo_erro = None
    for model_name in modelos:
        try:
            message = await async_client.messages.create(
                model=model_name,
                max_tokens=1024,
                system=NARRATIVE_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": f"Sonho: {dream_text}{context_block}"}],
            )
            return message.content[0].text
        except Exception as e:
            ultimo_erro = str(e)
            continue
            
    return "As vozes do inconsciente silenciaram temporariamente."

def _parse_ai_json(content: str) -> dict:
    try:
        start = content.find('{')
        end = content.rfind('}')
        if start != -1 and end != -1:
            return json.loads(content[start:end+1])
        return json.loads(content.strip())
    except Exception as e:
        raise ValueError(f"Formato de resposta inválido: {e}")

def _get_error_response(error_msg: str) -> dict:
    return {
        "aviso": "O Oráculo está em silêncio.", "essencia": "O silêncio também é uma mensagem.",
        "arquetipos": [], "funcao_compensatoria": "Aguardando clareza técnica.", "simbolos_chave": [],
        "fase_jornada": {"nome": "O Limiar", "descricao": "Recalibrando conexões."},
        "prospeccao": "Aguarde.", "mito_espelho": {"titulo": "O Silêncio", "paralelo": "Aguarde."},
        "pergunta_para_reflexao": "O que esse silêncio diz?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0
    }

async def process_voice_input(audio_file):
    pass

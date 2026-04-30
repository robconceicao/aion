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

def _parse_ai_json(content: str) -> dict:
    """Limpa e parseia o JSON de forma robusta, ignorando textos extras."""
    try:
        # Tenta encontrar o início e fim do JSON real
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
    # Se o erro for de autenticação (401), avisa explicitamente
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


NARRATIVE_SYSTEM_PROMPT = """Você é Aion, o Oráculo. Sua missão é traduzir sonhos complexos em uma linguagem SIMPLES, DIRETA e ACOLHEDORA. 

Evite termos técnicos complicados ou metáforas exageradas. Imagine que você está explicando o sonho para um amigo que não conhece psicologia.

Sua resposta deve seguir este fluxo:

1. **O que este sonho diz sobre você agora** — De forma clara, diga qual a principal mensagem ou sentimento que o sonho revela. Seja direto.
2. **O significado prático dos símbolos** — Explique os símbolos principais (como Jung faria) mas usando palavras do dia a dia. Relacione o símbolo com o seu momento de vida ou suas emoções atuais.
3. **A sabedoria universal (Mitos)** — Traga um exemplo rápido de um mito ou história antiga que ajude a ilustrar o seu momento, mas explique POR QUE isso é importante para você agora.
4. **Uma provocação para o seu dia** — Termine com uma pergunta simples e poderosa que faça a pessoa olhar para sua vida real.

Tom: Sábio, mas muito acessível. Objetivo, mas caloroso.
Comprimento: Curto a médio (máximo 200 palavras).
Diretriz de Linguagem: Use "VOCÊ", "SEU/SUA". Português do Brasil coloquial e direto."""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    """
    Retorna uma interpretação narrativa e poética do sonho.
    Recebe o contexto da análise estruturada para garantir coerência entre as duas leituras.
    """
    # Constrói o contexto da análise para garantir que a narrativa seja coerente
    context_block = ""
    if analysis_context:
        essencia = analysis_context.get("essencia", "")
        arquetipos = ", ".join(
            [a.get("nome", "") for a in analysis_context.get("arquetipos", [])]
        )
        mito = analysis_context.get("mito_espelho", {}).get("titulo", "")
        fase = analysis_context.get("fase_jornada", {}).get("nome", "")
        context_block = f"""

CONTEXTO DA ANÁLISE SIMBÓLICA (use para manter coerência, não repita):
- Essência identificada: {essencia}
- Arquétipos presentes: {arquetipos}
- Mito espelho: {mito}
- Fase da Jornada: {fase}
"""

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

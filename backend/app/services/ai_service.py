import json
import anthropic
from app.core.config import settings

# Cliente oficial da Anthropic (Claude)
client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — um analista junguiano de senioridade excepcional e profundo conhecedor da mitologia comparada. 
Sua tarefa é realizar uma 'Amplificação Junguiana' profunda e profissional do relato do sonho abaixo.

DIRETRIZ DE LINGUAGEM:
Use um tom poético, misterioso e tecnicamente preciso, mas NUNCA deixe o usuário confuso. Se usar um termo como 'Sombra', 'Anima' ou 'Individuação', explique o significado dentro do contexto do sonho de forma simples. O objetivo é ser profundo sem ser arrogante.

SONHO: {texto}

INSTRUÇÃO CRÍTICA: Responda APENAS com um JSON válido, seguindo exatamente este esquema:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui o acompanhamento profissional de um psicólogo.",
  "essencia": "Uma síntese oracular, poética e profunda da alma que este sonho está tecendo (2-3 frases).",
  "arquetipos": [
    {{ 
      "nome": "Nome do Arquétipo (ex: A Sombra, O Velho Sábio)", 
      "simbolo": "emoji condizente", 
      "descricao": "Como esta força psíquica está se manifestando e o que ela quer de você." 
    }}
  ],
  "funcao_compensatoria": "Explique com clareza o que o seu inconsciente está tentando equilibrar em relação à sua vida consciente atual.",
  "simbolos_chave": [
    {{ 
      "elemento": "Item ou ação do sonho", 
      "significado": "A amplificação simbólica (ex: a água representa o mergulho no emocional)." 
    }}
  ],
  "fase_jornada": {{
    "nome": "Estágio da Jornada do Herói (ex: O Chamado à Aventura)",
    "descricao": "Por que você se encontra neste estágio específico da sua vida agora."
  }},
  "prospeccao": "O que o sonho sinaliza sobre o futuro desenvolvimento da sua mente (função prospectiva).",
  "pergunta_para_reflexao": "Uma pergunta poderosa e direta que leve o sonhador a olhar para o que ele mais precisa.",
  "mito_espelho": {{ 
    "titulo": "Nome de um Mito ou Lenda Universal", 
    "paralelo": "A conexão direta entre essa história milenar e o seu momento atual." 
  }},
  "intensidade_sombra": 1-10,
  "intensidade_heroi": 1-10,
  "intensidade_transformacao": 1-10
}}
"""

async def analyze_dream(dream_text: str, context: dict = None) -> dict:
    """Analisa o sonho usando Claude (Anthropic), priorizando qualidade e profundidade."""
    print(f"[AI_SERVICE] Iniciando análise profissional com Claude.")
    
    prompt = PROMPT_TEMPLATE.format(texto=dream_text)

    # Modelos Claude (Sonnet é mais profundo, Haiku é mais rápido)
    modelos = [
        "claude-3-5-sonnet-20241022",
        "claude-3-5-haiku-20241022"
    ]

    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}")
            message = client.messages.create(
                model=model_name,
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt}]
            )

            content = message.content[0].text
            return _parse_ai_json(content)

        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro com {model_name}: {ultimo_erro}")
            continue

    return _get_error_response(f"Erro na conexão com o Oráculo: {ultimo_erro}")

def _parse_ai_json(content: str) -> dict:
    """Limpa e parseia o JSON da resposta da IA."""
    try:
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0]
        elif "```" in content:
            content = content.split("```")[1].split("```")[0]
        
        return json.loads(content.strip())
    except Exception as e:
        print(f"[AI_SERVICE] Erro ao parsear JSON: {e}")
        raise e

def _get_error_response(error_msg: str) -> dict:
    return {
        "aviso": "Instabilidade momentânea no Oráculo.",
        "essencia": "O silêncio também é uma mensagem do inconsciente.",
        "arquetipos": [],
        "funcao_compensatoria": "Tente novamente em breve.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Limiar", "descricao": "Aguardando clareza."},
        "prospeccao": "Aguarde um momento.",
        "mito_espelho": {"titulo": "O Silêncio", "paralelo": "A resposta virá no tempo certo."},
        "pergunta_para_reflexao": "O que você sente nesta espera?",
        "intensidade_sombra": 0,
        "intensidade_heroi": 0,
        "intensidade_transformacao": 0
    }

async def process_voice_input(audio_file):
    pass

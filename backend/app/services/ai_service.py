import json
import anthropic
from app.core.config import settings

# Cliente oficial da Anthropic (Claude)
client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

PROMPT_TEMPLATE = """
Atue como Aion, um mentor sábio e profundo que conhece a alma humana, mas que fala de forma simples e clara para que qualquer pessoa entenda.
Sua missão é analisar o sonho abaixo usando os conceitos de Carl Jung e Joseph Campbell, mas SEM usar termos técnicos difíceis (como 'psicopompa', 'catatimia', etc.).

Se precisar usar um conceito complexo, explique-o de forma comum. Use um tom acolhedor, gramaticalmente correto, mas acessível ao grande público.

SONHO: {texto}

INSTRUÇÃO CRÍTICA: Responda APENAS com um JSON válido, seguindo exatamente este esquema:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui o trabalho de um psicólogo.",
  "essencia": "O que o sonho quer te dizer, explicado de forma clara e profunda em 2 frases.",
  "arquetipos": [
    {{ "nome": "Nome do Personagem/Força", "simbolo": "emoji", "descricao": "Quem é essa parte de você que apareceu no sonho." }}
  ],
  "funcao_compensatoria": "Como o seu interior está tentando equilibrar sua vida atual.",
  "simbolos_chave": [
    {{ "elemento": "Elemento do sonho", "significado": "O que isso representa na sua vida real." }}
  ],
  "fase_jornada": {{
    "nome": "Onde você está no seu desafio atual",
    "descricao": "Explicação simples de como o sonho mostra seu momento de vida."
  }},
  "prospeccao": "Um conselho ou sinal para o seu futuro próximo.",
  "pergunta_para_reflexao": "Uma pergunta simples que faça a pessoa pensar sobre sua vida.",
  "mito_espelho": {{ "titulo": "Uma história ou lenda conhecida", "paralelo": "Como essa história antiga se parece com o seu sonho hoje." }},
  "intensidade_sombra": 7,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 8
}}
"""

async def analyze_dream(dream_text: str, context: dict = None) -> dict:
    """Analisa o sonho usando Claude (Anthropic), priorizando qualidade e profundidade."""
    print(f"[AI_SERVICE] Iniciando análise profissional com Claude.")
    
    prompt = PROMPT_TEMPLATE.format(texto=dream_text)

    # Modelos Claude (Haiku é mais rápido para análise imediata, Sonnet é mais profundo)
    modelos = [
        "claude-3-5-haiku-20241022",
        "claude-3-5-sonnet-20241022"
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

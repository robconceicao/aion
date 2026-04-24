import json
from google import genai
from google.genai import types
from app.core.config import settings

# Usa a API v1 (estável) em vez de v1beta (padrão do SDK)
client = genai.Client(
    api_key=settings.GEMINI_API_KEY,
    http_options={"api_version": "v1"}
)

PROMPT_TEMPLATE = """
Atue como Aion, um analista junguiano especialista em mitologia comparada. 
Analise o seguinte sonho sob a ótica de Carl Jung e Joseph Campbell.

SONHO: {texto}

ESTRUTURA DA RESPOSTA — responda APENAS em JSON válido, sem markdown, sem blocos de código, exatamente neste formato:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui acompanhamento profissional.",
  "essencia": "Essência oracular do sonho em 2-3 frases poéticas.",
  "arquetipos": [
    {{ "nome": "Nome do Arquétipo", "simbolo": "🌑", "descricao": "Como aparece no sonho." }}
  ],
  "funcao_compensatoria": "O que o inconsciente está equilibrando.",
  "simbolos_chave": [
    {{ "elemento": "Elemento do sonho", "significado": "Significado simbólico junguiano." }}
  ],
  "fase_jornada": {{
    "nome": "Fase da Jornada do Herói",
    "descricao": "Como o sonho se encaixa nesta fase."
  }},
  "prospeccao": "O que o sonho antecipa.",
  "pergunta_para_reflexao": "Uma pergunta poderosa e específica.",
  "mito_espelho": {{ "titulo": "Nome do Mito Relacionado", "paralelo": "Paralelo simbólico com o sonho." }},
  "intensidade_sombra": 7,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 8
}}
"""

async def analyze_dream(dream_text: str, context: dict = None) -> dict:
    """Analisa o sonho usando o novo SDK google-genai."""
    print(f"[AI_SERVICE] Iniciando análise. Chave configurada: {'Sim' if settings.GEMINI_API_KEY else 'NÃO!'}")

    modelos = [
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-1.5-flash",
    ]

    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}")
            prompt = PROMPT_TEMPLATE.format(texto=dream_text)
            
            response = client.models.generate_content(
                model=model_name,
                contents=prompt
            )
            content = response.text
            print(f"[AI_SERVICE] Resposta recebida de {model_name}!")

            # Limpa marcações de markdown se presentes
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]

            resultado = json.loads(content.strip())
            print(f"[AI_SERVICE] JSON parseado com sucesso!")
            return resultado

        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro com {model_name}: {ultimo_erro}")
            continue

    # Fallback caso todos os modelos falhem
    print(f"[AI_SERVICE] TODOS OS MODELOS FALHARAM. Último erro: {ultimo_erro}")
    return {
        "aviso": f"O Oráculo encontrou turbulência técnica. Erro: {ultimo_erro[:150] if ultimo_erro else 'Desconhecido'}",
        "essencia": "O silêncio também é uma mensagem do inconsciente.",
        "arquetipos": [],
        "funcao_compensatoria": "Não foi possível determinar.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Limiar", "descricao": "Uma passagem está sendo tentada."},
        "prospeccao": "Tente novamente em alguns instantes.",
        "mito_espelho": {"titulo": "A Espera", "paralelo": "Como Jó, o silêncio precede a revelação."},
        "pergunta_para_reflexao": "O que este sonho faz você sentir agora?",
        "intensidade_sombra": 0,
        "intensidade_heroi": 0,
        "intensidade_transformacao": 0
    }

async def process_voice_input(audio_file):
    pass

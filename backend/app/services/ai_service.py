import json
import google.generativeai as genai
from app.core.config import settings

# Configuração usando a chave do ambiente de produção (Render)
genai.configure(api_key=settings.GEMINI_API_KEY)

PROMPT_TEMPLATE = """
Atue como Aion, um analista junguiano especialista em mitologia comparada. 
Analise o seguinte sonho sob a ótica de Carl Jung e Joseph Campbell.

SONHO: {texto}

ESTRUTURA DA RESPOSTA — responda APENAS em JSON válido, exatamente neste formato, sem markdown:

{{
  "aviso": "Esta análise é uma reflexão simbólica e não substitui acompanhamento profissional.",
  "essencia": "Essência oracular do sonho em 2-3 frases poéticas.",
  "arquetipos": [
    {{ "nome": "Nome do Arquétipo", "simbolo": "🌑", "descricao": "Breve análise de como aparece no sonho." }}
  ],
  "funcao_compensatoria": "O que o inconsciente está equilibrando em relação à consciência.",
  "simbolos_chave": [
    {{ "elemento": "Elemento do sonho", "significado": "Significado simbólico junguiano." }}
  ],
  "fase_jornada": {{
    "nome": "Fase da Jornada do Herói",
    "descricao": "Explicação de como o sonho se encaixa nesta fase."
  }},
  "prospeccao": "O que o sonho antecipa ou prepara o sonhador para enfrentar.",
  "pergunta_para_reflexao": "Uma pergunta poderosa e específica para o sonhador refletir.",
  "mito_espelho": {{ "titulo": "Nome do Mito Relacionado", "paralelo": "Paralelo simbólico com o sonho." }},
  "intensidade_sombra": 7,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 8
}}
"""

async def analyze_dream(dream_text: str, context: dict = None) -> dict:
    """Analisa o sonho usando o Gemini e retorna o JSON da interpretação."""
    print(f"[AI_SERVICE] Iniciando análise do sonho. Chave configurada: {'Sim' if settings.GEMINI_API_KEY else 'NÃO!'}")
    
    modelos = [
        "gemini-1.5-flash",
        "gemini-1.5-pro",
        "gemini-pro"
    ]
    
    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}")
            model = genai.GenerativeModel(model_name)
            prompt = PROMPT_TEMPLATE.format(texto=dream_text)
            response = model.generate_content(prompt)
            content = response.text
            
            # Limpa marcações de código markdown se presentes
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            
            resultado = json.loads(content.strip())
            print(f"[AI_SERVICE] Análise concluída com sucesso usando {model_name}!")
            return resultado
            
        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro com {model_name}: {ultimo_erro}")
            continue
    
    # Fallback final caso todos os modelos falhem
    print(f"[AI_SERVICE] TODOS OS MODELOS FALHARAM. Último erro: {ultimo_erro}")
    return {
        "aviso": f"O Oráculo encontrou uma turbulência. Erro: {ultimo_erro[:100]}",
        "essencia": "O silêncio também é uma mensagem do inconsciente.",
        "arquetipos": [],
        "funcao_compensatoria": "Não foi possível determinar a compensação.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Limiar", "descricao": "Uma passagem está sendo tentada."},
        "prospeccao": "Tente novamente em alguns instantes.",
        "mito_espelho": {"titulo": "A Espera", "paralelo": "Como Jó, o silêncio precede a revelação."},
        "pergunta_para_reflexao": "O que este sonho faz você sentir agora, mesmo sem a análise?",
        "intensidade_sombra": 0,
        "intensidade_heroi": 0,
        "intensidade_transformacao": 0
    }

async def process_voice_input(audio_file):
    pass

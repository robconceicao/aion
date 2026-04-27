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

    # Modelos Claude (Tentando dos mais novos para os mais estáveis)
    modelos = [
        "claude-3-5-sonnet-latest",
        "claude-3-5-sonnet-20241022",
        "claude-3-5-sonnet-20240620",
        "claude-3-5-haiku-latest",
        "claude-3-5-haiku-20241022",
        "claude-3-haiku-20240307",
        "claude-3-opus-20240229"
    ]

    # DIAGNÓSTICO: Listar modelos disponíveis na conta para debug
    try:
        print("[DEBUG_CONTA] Verificando modelos disponíveis para esta chave...")
        available = client.models.list()
        print(f"[DEBUG_CONTA] Modelos que sua conta PODE ver: {[m.id for m in available]}")
    except Exception as e:
        print(f"[DEBUG_CONTA] Falha ao listar modelos (provável problema na chave): {e}")

    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}...")
            message = client.messages.create(
                model=model_name,
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt}]
            )

            content = message.content[0].text
            return _parse_ai_json(content)

        except Exception as e:
            ultimo_erro = str(e)
            print(f"[AI_SERVICE] Erro crítico com {model_name}: {ultimo_erro}")
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

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
    """Analisa o sonho usando Claude (Anthropic)."""
    print(f"[AI_SERVICE] Iniciando análise com Claude. Chave configurada: {'Sim' if settings.ANTHROPIC_API_KEY else 'NAO!'}")

    # Descobre dinamicamente os modelos disponíveis nesta conta
    modelos = []
    try:
        print("[AI_SERVICE] Listando modelos disponíveis na conta...")
        page = client.models.list()
        todos = list(page)
        print(f"[AI_SERVICE] Total de modelos encontrados: {len(todos)}")
        for m in todos:
            model_id = m.id if hasattr(m, 'id') else str(m)
            print(f"[AI_SERVICE] >> Modelo: {model_id}")
            if "claude" in model_id.lower():
                modelos.append(model_id)
        modelos.sort(reverse=True)
    except Exception as e:
        print(f"[AI_SERVICE] Erro ao listar modelos: {e}")

    if not modelos:
        # Tenta modelos Claude 4 (geração atual em 2025/2026)
        modelos = [
            "claude-opus-4-5",
            "claude-sonnet-4-5",
            "claude-haiku-4-5",
            "claude-opus-4",
            "claude-sonnet-4",
            "claude-haiku-4",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
        ]

    print(f"[AI_SERVICE] Modelos a tentar: {modelos[:5]}")

    ultimo_erro = None
    for model_name in modelos:
        try:
            print(f"[AI_SERVICE] Tentando modelo: {model_name}")
            prompt = PROMPT_TEMPLATE.format(texto=dream_text)

            message = client.messages.create(
                model=model_name,
                max_tokens=2048,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )

            content = message.content[0].text
            print(f"[AI_SERVICE] Resposta recebida de {model_name}!")

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

    print(f"[AI_SERVICE] TODOS OS MODELOS FALHARAM. Ultimo erro: {ultimo_erro}")
    return {
        "aviso": f"O Oráculo encontrou turbulência. Erro: {ultimo_erro[:100] if ultimo_erro else 'Desconhecido'}",
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

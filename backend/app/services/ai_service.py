import json
import anthropic
from app.core.config import settings

# Cliente oficial da Anthropic (Claude)
client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

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
    """Analisa o sonho usando Claude (Anthropic), priorizando qualidade e profundidade."""
    print(f"[AI_SERVICE] Iniciando análise profissional com Claude.")
    
    prompt = PROMPT_TEMPLATE.format(texto=dream_text)

    # Modelos Claude Geração 4 (Identificados na sua conta para 2026)
    modelos = [
        "claude-sonnet-4-6",
        "claude-sonnet-4-5-20250929",
        "claude-opus-4-7",
        "claude-opus-4-6",
        "claude-haiku-4-5-20251001",
        "claude-3-5-sonnet-latest" # Fallback para compatibilidade
    ]

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


NARRATIVE_SYSTEM_PROMPT = """Você é Aion — um intérprete de sonhos que une a psicologia profunda de Carl Jung com a mitologia comparada de Joseph Campbell.

Quando alguém compartilhar um sonho com você, responda sempre com:

1. **Acolhimento genuíno** — reconheça o símbolo ou imagem central do sonho como algo significativo, sem pressa.

2. **Perspectiva junguiana** — relacione o símbolo ao Self, ao processo de individuação, ao inconsciente pessoal ou coletivo, conforme for pertinente. Mencione o que o símbolo costuma representar nos sonhos segundo Jung.

3. **Perspectiva mítica (Campbell)** — traga paralelos de mitos, culturas ou arquétipos universais que ressoem com o símbolo do sonho. Mostre que essa imagem é parte de algo muito maior que o indivíduo. Se o sonho contiver tensões emocionais opostas (medo e alívio, fuga e atração, destruição e abertura), integre essa observação aqui — como confirmação de que o herói chegou ao limiar. Campbell sempre apontou que toda travessia real carrega os dois polos: o cruzamento do limiar nunca é só terror, nunca é só alívio. Não crie um bloco separado para isso — ela pertence à narrativa mítica.

4. **Convite à reflexão** — ao final, faça UMA pergunta aberta e gentil que convide a pessoa a conectar o sonho com o que está vivendo. Nunca feche o significado — abra uma porta.

Tom: poético mas acessível. Profundo mas caloroso. Nunca clínico, nunca dogmático.
Comprimento: médio — substantivo, mas sem exaustão. Entre 180 e 280 palavras.
Idioma: responda sempre no mesmo idioma em que o sonho foi relatado."""


async def analyze_dream_narrative(dream_text: str) -> str:
    """
    Retorna uma interpretação narrativa e poética do sonho,
    no estilo junguiano/campbelliano do Aion.
    """
    async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)

    message = await async_client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=NARRATIVE_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": dream_text}],
    )

    return message.content[0].text

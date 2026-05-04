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
    if not settings.GEMINI_API_KEY:
        return [0.0] * 768
    try:
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

async def call_claude(system_prompt: str, user_content: str, max_tokens=3500):
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
            
    return await call_deepseek(system_prompt, user_content)


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


async def call_deepseek(system_prompt: str, user_content: str, max_tokens=3500):
    if not settings.DEEPSEEK_API_KEY:
        return await call_gemini(system_prompt, user_content)
    try:
        url = "https://api.deepseek.com/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content}
            ],
            "max_tokens": max_tokens,
            "temperature": 0.7,
            "response_format": {"type": "json_object"} if "JSON" in system_prompt else {"type": "text"}
        }
        async with httpx.AsyncClient() as client:
            res = await client.post(url, headers=headers, json=payload, timeout=60.0)
            res.raise_for_status()
            return res.json()["choices"][0]["message"]["content"]
    except Exception as e:
        print(f"[AI_SERVICE] Erro no DeepSeek: {e}")
        return await call_gemini(system_prompt, user_content)


def _parse_ai_json(content: str) -> dict:
    import re
    try:
        # 1. Limpeza básica e remoção de Markdown
        content = content.strip()
        content = re.sub(r'```json\s*|\s*```', '', content)
        
        # 2. Localiza o bloco JSON
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            content = content[start:end+1]
        
        # 3. Resolve problemas de quebra de linha dentro de strings JSON
        # Esta regex procura por quebras de linha que não estão precedendo uma chave ou fechamento
        content = re.sub(r'(?<![:{,])\n(?![}\],])', ' ', content)
        
        # 4. Remove vírgulas extras
        content = re.sub(r',\s*([\}\]])', r'\1', content)
        
        return json.loads(content)
    except Exception as e:
        try:
            # Fallback final: remove TODAS as quebras de linha para sanitizar
            cleaned = re.sub(r'\s+', ' ', content)
            return json.loads(cleaned)
        except:
            print(f"[AI_SERVICE] Falha total parse JSON. Erro: {e}")
            raise ValueError(f"JSON inválido: {str(e)}")


# ─── FUNÇÕES DO AION (ALMA JUNG & CAMPBELL) ───────────────────

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    from app.services.ai_service import PROMPT_TEMPLATE, _build_contexto, _get_error_response
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'), 
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    
    try:
        # Aumentamos o limite de tokens para permitir análises profundas
        content = await call_claude("", prompt, max_tokens=4000)
        return _parse_ai_json(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal análise: {e}")
        return _get_error_response(str(e))


async def generate_interview_questions(dream_text: str) -> list:
    from app.services.ai_service import INTERVIEW_SYSTEM_PROMPT
    try:
        content = await call_claude(INTERVIEW_SYSTEM_PROMPT, f"Sonho: {dream_text}", max_tokens=1000)
        data = _parse_ai_json(content)
        return data.get("perguntas", [])
    except Exception as e:
        return ["Como você se sentiu?", "O que lembra da vida?", "Qual era a sensação?"]


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    from app.services.ai_service import RECURRENCE_SYSTEM_PROMPT
    history = "\n\nANTERIORES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:300]
        history += f"\n[{i}]: {relato}..."
    
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Atual: {current_dream}{history}", max_tokens=1200)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    from app.services.ai_service import NARRATIVE_SYSTEM_PROMPT
    context_block = ""
    if analysis_context:
        essencia    = analysis_context.get('essencia', '')
        arquetipos  = analysis_context.get('arquetipos', [])
        simbolos    = analysis_context.get('simbolos_chave', [])
        funcao      = analysis_context.get('funcao_compensatoria', '')
        fase        = analysis_context.get('fase_jornada', {})
        prospeccao  = analysis_context.get('prospeccao', '')
        mito        = analysis_context.get('mito_espelho', {})
        pergunta    = analysis_context.get('pergunta_para_reflexao', '')

        # Formata arquetipos e simbolos de forma legível
        arq_txt = '; '.join([f"{a.get('nome','')}: {a.get('descricao','')}" for a in arquetipos]) if isinstance(arquetipos, list) else str(arquetipos)
        sim_txt = '; '.join([f"{s.get('elemento','')}: {s.get('significado','')}" for s in simbolos]) if isinstance(simbolos, list) else str(simbolos)
        fase_txt = f"{fase.get('nome','')} — {fase.get('descricao','')}" if isinstance(fase, dict) else str(fase)
        mito_txt = f"{mito.get('titulo','')} — {mito.get('paralela','')}" if isinstance(mito, dict) else str(mito)

        context_block = (
            f"\n\nESSÊNCIA DO SONHO: {essencia}"
            f"\nPERSONAGENS INTERIORES: {arq_txt}"
            f"\nSÍMBOLOS PRINCIPAIS: {sim_txt}"
            f"\nO QUE A PSIQUE BUSCA: {funcao}"
            f"\nMOMENTO DA JORNADA: {fase_txt}"
            f"\nSINAL PARA O FUTURO: {prospeccao}"
            f"\nECO MÍTICO: {mito_txt}"
            f"\nPERGUNTA_FINAL: {pergunta}"
        )

    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho relatado: {dream_text}{context_block}", max_tokens=900)
    except Exception as e:
        return "O Oráculo aguarda em silêncio sagrado..."


# ─── PROMPTS DEFINITIVOS (EXCELÊNCIA) ─────────────────────────

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique. Você é a união da senioridade de C.G. Jung com a sabedoria narrativa de Joseph Campbell.

SUA MISSÃO:
Realizar uma análise técnica rigorosa do material onírico, seguindo o método clínico junguiano-campbelliano. Antes de gerar a resposta, percorra obrigatoriamente este processo interno:

① COMPENSAÇÃO (Jung): Identifique que atitude consciente unilateral o sonho está compensando. Qual homeostase psíquica o inconsciente busca restaurar?

② ESTRUTURA DRAMÁTICA: Leia o sonho como uma peça de 4 atos:
   - Exposição (cenário, personagens, tempo)
   - Desenvolvimento (o conflito surge)
   - Perícope/Clímax (o momento decisivo)
   - Lise/Solução (a mensagem final do inconsciente)

③ AMPLIFICAÇÃO ARQUETÍPICA (não associação livre): Mantenha o foco na imagem do sonho. Para cada símbolo, busque o paralelo mítico universal que ilumina a experiência pessoal.

④ COMPONENTES PSÍQUICOS: Classifique as figuras do sonho com precisão:
   - SOMBRA: Figuras do mesmo sexo, antagonistas, traços negados ou inferiores.
   - ANIMA/ANIMUS (Sizígia): Figuras do sexo oposto, relação com a interioridade e criatividade.
   - VELHO SÁBIO / GRANDE MÃE: Figuras de autoridade/cuidado com sabedoria transpessoal.
   - SELF: Símbolos de totalidade (mandalas, círculos, pedras preciosas, figuras luminosas ou crísticas).

⑤ JORNADA DO HERÓI (Campbell): Localize o sonhador com precisão no Monomito. Que desafio interno pede mudança? Que forças internas podem ajudar?

⑥ FUNÇÃO PROSPECTIVA (Jung): Não apenas o porquê passado — mas para onde este sonho está conduzindo o desenvolvimento futuro da personalidade?

REGRAS DE RESPOSTA (CRÍTICAS):
1. Use tom poético, iniciático e acolhedor.
2. Seja profundo. Explore o significado oculto sob a superfície.
3. Responda APENAS JSON válido.
4. IMPORTANTE: Não use quebras de linha (Enter) dentro dos valores das strings no JSON. Use '\\n' se precisar pular linha no texto.

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

JSON FORMAT:
{{
  "aviso": "Análise simbólica baseada em Jung e Campbell.",
  "essencia": "O núcleo dinâmico do sonho: que compensação ele traz e qual é sua estrutura dramática central (Exposição → Clímax → Lise).",
  "arquetipos": [
    {{ "nome": "...", "simbolo": "...", "descricao": "Componente psíquico preciso (Sombra, Anima/Animus, Velho Sábio ou Self) e seu papel neste sonho." }}
  ],
  "funcao_compensatoria": "Que atitude consciente unilateral o sonho compensa? Como a psique busca a homeostase e o equilíbrio entre consciente e inconsciente?",
  "simbolos_chave": [
    {{ "elemento": "...", "significado": "Amplificação arquetípica: o que este símbolo significa pessoalmente e qual seu paralelo no mito ou conto universal." }}
  ],
  "fase_jornada": {{ "nome": "...", "descricao": "Estágio preciso do Monomito de Campbell, o que ele exige do herói agora e quais forças internas podem auxiliá-lo." }},
  "prospeccao": "Função prospectiva (Jung): para onde este sonho está conduzindo o desenvolvimento da personalidade? O que está sendo preparado para o futuro?",
  "pergunta_para_reflexao": "Uma questão que integra o aprendizado simbólico à vida prática do sonhador agora.",
  "mito_espelho": {{ "titulo": "...", "paralela": "O mito ou conto que amplifica arquetipicamente esta jornada e por que seu paralelo ressoa nesta experiência." }},
  "intensidade_sombra": 5, "intensidade_heroi": 5, "intensidade_transformacao": 5
}}
"""

INTERVIEW_SYSTEM_PROMPT = "Você é Aion. Analise o relato e identifique 3 pontos cegos sob a ótica de Jung e Campbell. JSON: {\"perguntas\": [\"...\", \"...\", \"...\"]}"
RECURRENCE_SYSTEM_PROMPT = "Analise a evolução dos símbolos como capítulos de uma saga mítica em desenvolvimento. Máximo 250 palavras."
NARRATIVE_SYSTEM_PROMPT = """Você é um psicólogo especialista em Carl Jung e Joseph Campbell. Sua missão é falar DIRETAMENTE com a pessoa que sonhou — como um terapeuta sábio, acolhedor e próximo — traduzindo a linguagem simbólica do sonho para a vida prática do cliente.

DIRETRIZES DE LINGUAGEM (INVIOLÁVEIS):
- Fale na segunda pessoa: \"Você...\", \"Seu sonho...\", \"Olhe para...\"
- PROIBIDO jargão técnico. Nunca use: arquétipo, Self, individuação, inconsciente coletivo, anima, animus, complexo. Substitua por linguagem do dia a dia.
- Use metáforas vivas: o sonho como uma peça de teatro que sua mente criou, como um conto de fadas onde você é o herói, como um mapa do tesouro interior.
- Figuras ou situações assustadoras: apresente-as como energias escondidas com potencial, não como ameaças.
- Foco no \"O QUÊ FAZER AGORA\", não só na análise do passado.
- Tom: caloroso, direto, confiável — como um terapeuta que você conhece há anos.

ESTRUTURA OBRIGATÓRIA (texto corrido, sem títulos ou listas):
1. Acolhida: Valide o sonho como uma mensagem importante criada pela própria mente do sonhador.
2. Leitura dos Símbolos: Explique em linguagem simples e metafórica o que os personagens, lugares e situações do sonho representam na vida do cliente.
3. A Jornada do Herói: Mostre que o sonhador É o herói desta história, e onde ele está nessa aventura — que desafio interno pede mudança, que forças interiores podem ajudá-lo.
4. Encerramento: Finalize OBRIGATORIAMENTE com a PERGUNTA_FINAL exatamente como fornecida no contexto, sem alterações.

RESTRIÇÕES:
- Máximo 380 palavras. Texto corrido, sem listas ou subtítulos.
- IMPORTANTE: Não use quebras de linha (Enter) dentro do texto. Use apenas parágrafos separados por \\n."""

def _build_contexto(tags_emocao=None, temas=None, residuos_diurnos=None, interview_answers=None) -> str:
    lines = []
    if tags_emocao: lines.append(f"EMOÇÕES: {', '.join(tags_emocao)}")
    if temas: lines.append(f"TEMAS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"CONTEÚDO DIURNO: {', '.join(residuos_diurnos)}")
    if interview_answers:
        for item in interview_answers:
            lines.append(f"P: {item.get('pergunta', '')} | R: {item.get('resposta', '')}")
    return "\nCONTEXTO ADICIONAL:\n" + "\n".join(lines) if lines else ""

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

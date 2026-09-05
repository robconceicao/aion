import json
import anthropic
import google.generativeai as genai
import httpx
import re
from app.core.config import settings
from app.models.dream import SynthesisResult, SynthesisError

# Clientes de IA
async_client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY) if settings.ANTHROPIC_API_KEY else None

# Configuração Gemini
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)

# Lista de modelos por prioridade (Versões 2026)
AI_MODELS = [
    "claude-sonnet-5",
    "claude-haiku-4-5-20251001",
    "claude-3-5-sonnet-20241022",
]

# ─── EMBEDDINGS (VIA REMOTE API - 768 DIM) ────────────────────

async def generate_embedding(text: str) -> list | None:
    """Retorna o vetor de embedding ou None em caso de falha (A-02).
    Nunca retorna vetor zero — None sinaliza ausência de indexação."""
    if not settings.GEMINI_API_KEY:
        print("[AI_SERVICE] GEMINI_API_KEY ausente — embedding nao gerado.")
        return None
    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/embedding-001:embedContent?key={settings.GEMINI_API_KEY}"
        async with httpx.AsyncClient() as client:
            res = await client.post(url, json={
                "model": "models/embedding-001",
                "content": {"parts": [{"text": text}]}
            })
            if res.status_code == 200:
                return res.json()['embedding']['values']
            print(f"[AI_SERVICE] Embedding falhou: HTTP {res.status_code}")
            return None
    except Exception as e:
        print(f"[AI_SERVICE] Embedding falhou: {e}")
        return None


# ─── HELPERS DE IA ────────────────────────────────────────────

async def call_claude(system_prompt: str, user_content: str, max_tokens=3500):
    """Cascata completa: 3 modelos Claude -> Gemini -> xAI (A-05).
    Levanta RuntimeError se todos os provedores falharem."""

    if async_client:
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
                print(f"[AI_SERVICE] {model_name} falhou ({type(e).__name__}): {e}")
                continue

    try:
        return await call_gemini(system_prompt, user_content)
    except Exception as e:
        print(f"[AI_SERVICE] Gemini falhou ({type(e).__name__}): {e}")

    try:
        return await call_xai(system_prompt, user_content)
    except Exception as e:
        print(f"[AI_SERVICE] xAI falhou ({type(e).__name__}): {e}")

    raise RuntimeError("[AI_SERVICE] Todos os provedores de IA falharam.")


async def call_gemini(system_prompt: str, user_content: str):
    if not settings.GEMINI_API_KEY:
        raise ValueError("GEMINI_API_KEY ausente.")
    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        full_prompt = f"{system_prompt}\n\nUSUÁRIO: {user_content}"
        response = await model.generate_content_async(full_prompt)
        return response.text
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal no Gemini: {e}")
        raise e


async def call_xai(system_prompt: str, user_content: str, max_tokens=3500):
    """Chama o xAI (Grok) diretamente. Nao tem fallback interno."""
    if not settings.XAI_API_KEY:
        raise ValueError("[AI_SERVICE] XAI_API_KEY ausente.")
    try:
        url = "https://api.x.ai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {settings.XAI_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": "grok-4",
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
        print(f"[AI_SERVICE] Erro no xAI: {e}")
        raise


def _parse_ai_json(content: str) -> dict:
    import re
    try:
        content = content.strip()
        content = re.sub(r'```json\s*|\s*```', '', content)
        start, end = content.find('{'), content.rfind('}')
        if start != -1 and end != -1:
            content = content[start:end+1]
        content = re.sub(r'(?<![:{,])\n(?![}\],])', ' ', content)
        content = re.sub(r',\s*([\}\/\]])', r'\1', content)
        return json.loads(content)
    except Exception as e:
        try:
            cleaned = re.sub(r'\s+', ' ', content)
            return json.loads(cleaned)
        except:
            print(f"[AI_SERVICE] Falha total parse JSON. Erro: {e}")
            raise ValueError(f"JSON invalido: {str(e)}")


# ─── SÍNTESE DUAL (FUNÇÃO PRINCIPAL — SPEC §5) ─────────────────────

SYNTHESIS_PROMPT = """
Você é Aion de Mito & Psique — a união da senioridade clínica de C.G. Jung com a sabedoria narrativa de Joseph Campbell.

SUA MISSÃO NESTA CHAMADA:
Realizar UMA Única análise do material onírico e devolvê-la em DOIS FORMATOS SIMULTÂNEOS dentro de um único JSON.
Os dois formatos devem ter CONTEÚDO INTERPRETATIVO IDÊNCO — os mesmos símbolos, os mesmos arquétipos, as mesmas conclusões.
A diferença é APENAS de forma e linguagem.

ANTES DE GERAR A RESPOSTA, percorra internamente:
① COMPENSAÇÃO (Jung): Que atitude consciente o sonho compensa?
② ESTRUTURA DRAMÁTICA: Exposição → Desenvolvimento → Clímax → Lise
③ AMPLIFICAÇÃO ARQUETÍPICA: Para cada símbolo, paralelo mítico universal
④ COMPONENTES PSÍQUICOS: Sombra, Anima/Animus, Velho Sábio, Self
⑤ JORNADA DO HERÓI (Campbell): Localização precisa no Monomito
⑥ FUNÇÃO PROSPECTIVA: Para onde este sonho conduz o desenvolvimento?

REGRAS PARA analise_completa (formato técnico):
- Linguagem clínica junguiana-campbelliana
- Termos técnicos permitidos e esperados
- Máximo de profundidade e precisão conceitual

REGRAS INVIOLÁVEIS para interpretacao_narrativa (formato acessível):
- Tom: psicólogo junguiano em consulta — caloroso, direto, segunda pessoa ("Você...", "Seu sonho...")
- ZERO jargão sem tradução. Substituições obrigatórias:
  * "conteúdo compensatório" → "seu sonho parece estar equilibrando algo que você vive no dia a dia"
  * "confronto com a Sombra" → "uma parte sua que você normalmente não olha de frente apareceu no sonho"
  * "processo de individuação" → "seu caminho de se tornar quem você realmente é"
  * "arquétipo", "Self", "anima", "animus", "complexo", "inconsciente coletivo" → substituir por metáforas vivas
- Texto corrido, sem títulos ou listas
- Máximo 4.000 caracteres (teto suave para TTS)
- Estrutura: acolhida → leitura dos símbolos em linguagem simples → jornada do herói como aventura pessoal

REGRAS para pergunta_reflexao:
- Em linguagem acessível (mesmas regras da narrativa — zero jargão)
- Uma única pergunta que integra o aprendizado simbólico à vida prática do sonhador
- Exemplo correto: "O que essa parte sua que você evita poderia te ensinar se você parasse para ouvi-la?"
- Exemplo errado: "Como o confronto com a Sombra ilumina seu processo de individuação?"

DADOS DO SONHO:
- RELATO: {texto}
{contexto_estruturado}

IMPORTANTE: Responda APENAS JSON válido. Não use quebras de linha (Enter) dentro dos valores de string — use \\n se precisar separar parágrafos.

JSON FORMAT:
{{
  "analise_completa": {{
    "simbolos": [
      {{ "elemento": "...", "significado": "amplificação arquetípica técnica", "amplificacao": "paralelo mítico universal" }}
    ],
    "arquetipos": [
      {{ "arquetipo": "nome técnico (ex: Sombra, Anima, Self)", "manifestacao": "como aparece especificamente neste sonho" }}
    ],
    "compensacao": "que atitude consciente unilateral o sonho compensa — linguagem clínica",
    "fase_jornada": "estágio preciso do Monomito de Campbell e o que ele exige do herói agora",
    "sintese_tecnica": "síntese clínica integrando compensação, arquétipos e função prospectiva"
  }},
  "interpretacao_narrativa": "texto corrido, segunda pessoa, zero jargão, máximo 4000 chars. Mesmo conteúdo que analise_completa, linguagem completamente diferente.",
  "pergunta_reflexao": "uma pergunta em linguagem simples que integra o aprendizado à vida prática"
}}
"""


async def synthesize_dual(dream_text: str, **kwargs) -> SynthesisResult:
    """
    Síntese dual única: gera analise_completa + interpretacao_narrativa + pergunta_reflexao
    em UMA Única chamada ao LLM, garantindo não-divergência por construção (SPEC §5).

    Cascata: Claude -> Gemini -> xAI (todos usam o mesmo SYNTHESIS_PROMPT e schema).

    Em caso de falha de todos os provedores OU JSON malformado após esgotamento da cascata:
    levanta SynthesisError — nada é persistido no banco.
    """
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'),
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = SYNTHESIS_PROMPT.format(texto=dream_text, contexto_estruturado=contexto)

    last_error = None

    if async_client:
        for model_name in AI_MODELS:
            try:
                message = await async_client.messages.create(
                    model=model_name,
                    max_tokens=5000,
                    system="",
                    messages=[{"role": "user", "content": prompt}]
                )
                raw = message.content[0].text
                data = _parse_ai_json(raw)
                result = SynthesisResult.model_validate(data)
                print(f"[SYNTHESIS] Sucesso via {model_name}.")
                return result
            except Exception as e:
                print(f"[SYNTHESIS] {model_name} falhou ({type(e).__name__}): {e}")
                last_error = e
                continue

    if settings.GEMINI_API_KEY:
        try:
            raw = await call_gemini("", prompt)
            data = _parse_ai_json(raw)
            result = SynthesisResult.model_validate(data)
            print("[SYNTHESIS] Sucesso via Gemini.")
            return result
        except Exception as e:
            print(f"[SYNTHESIS] Gemini falhou ({type(e).__name__}): {e}")
            last_error = e

    if settings.XAI_API_KEY:
        try:
            raw = await call_xai("", prompt, max_tokens=5000)
            data = _parse_ai_json(raw)
            result = SynthesisResult.model_validate(data)
            print("[SYNTHESIS] Sucesso via xAI.")
            return result
        except Exception as e:
            print(f"[SYNTHESIS] xAI falhou ({type(e).__name__}): {e}")
            last_error = e

    reason = str(last_error) if last_error else "nenhum provider configurado"
    raise SynthesisError(reason)


# ─── FUNÇÕES DEPRECATED (mantidas temporariamente para evitar quebra de imports) ──

async def analyze_dream(dream_text: str, **kwargs) -> dict:
    """
    DEPRECATED (Fase 1, 2026-07-07). Substituída por synthesize_dual().
    Mantida apenas para evitar ImportError em código legado não atualizado.
    REMOVER em P2.
    """
    print("[AI_SERVICE] AVISO: analyze_dream() está DEPRECATED. Use synthesize_dual().")
    contexto = _build_contexto(
        kwargs.get('tags_emocao'), kwargs.get('temas'),
        kwargs.get('residuos_diurnos'), kwargs.get('interview_answers')
    )
    prompt = PROMPT_TEMPLATE.format(texto=dream_text, contexto_estruturado=contexto)
    try:
        content = await call_claude("", prompt, max_tokens=4000)
        return _parse_ai_json(content)
    except Exception as e:
        print(f"[AI_SERVICE] Erro fatal analise (deprecated): {e}")
        return _get_error_response(str(e))


# ─── VERIFICAÇÃO DETERMINÍSTICA DE JARGÃO (regra de zero jargão) ──────────
#
# O INTERVIEW_SYSTEM_PROMPT já proíbe jargão, mas prompt é controle
# probabilístico: perguntas com "Divine Child", "Self emergente" e "arquétipo"
# chegaram ao usuário em produção. Esta verificação roda DEPOIS da geração e é
# determinística.
#
# CALIBRAGEM — por que a lista é menor que a do prompt:
#
# Um filtro agressivo demais é pior que nenhum. Reprovar leva à regeneração e,
# persistindo, ao fallback fixo — que perde a especificidade ao sonho, o valor
# principal da entrevista. Então só entram aqui termos SEM uso cotidiano
# plausível numa pergunta sobre um sonho.
#
# Deliberadamente FORA da lista, apesar de constarem no prompt:
#   "sombra"    — "uma sombra no corredor" é elemento concreto de sonho
#   "complexo"  — adjetivo comum ("um sentimento complexo")
#   "anima"     — colide com o verbo animar ("o que te anima")
#   "projeção"  — uso cotidiano frequente
#   "persona"   — idem
# Bloqueá-los rejeitaria perguntas legítimas. Continuam proibidos pelo prompt;
# apenas não são barrados automaticamente.
_JARGAO_PROIBIDO = [
    "arquetipo", "arquetipos", "arquetipico", "arquetipica", "arquetipal",
    "individuacao", "individuar",
    "inconsciente coletivo",
    "monomito",
    "animus",
    "psique", "psiquico", "psiquica",
    "numinoso", "numinosa",
    "enantiodromia",
    "sizigia",
    "mandala",
    "self",
    "divine child", "crianca divina",
    "velho sabio",
    "limiar arquetipico",
]


def _normalizar(texto: str) -> str:
    """Minúsculas e sem acentos, para o casamento não depender de grafia."""
    import unicodedata
    decomposto = unicodedata.normalize("NFD", texto.lower())
    return "".join(c for c in decomposto if unicodedata.category(c) != "Mn")


def violacoes_de_jargao(perguntas: list) -> list:
    """
    Termos proibidos encontrados nas perguntas. Lista vazia = aprovado.

    Casa por palavra inteira: "psique" não dispara em "psicólogo", e "self"
    não dispara em "selfie".
    """
    alvo = _normalizar(" || ".join(str(p) for p in perguntas))
    encontrados = []
    for termo in _JARGAO_PROIBIDO:
        if re.search(rf"(?<!\w){re.escape(termo)}(?!\w)", alvo):
            encontrados.append(termo)
    return encontrados


# Usado quando a IA falha ou reprova duas vezes na verificação.
#
# Estas perguntas TÊM de passar em violacoes_de_jargao() — antes usavam
# "psique", ou seja, o fallback violava a própria regra que o prompt impõe e
# servia jargão justamente no caminho de degradação. Há teste garantindo isso.
INTERVIEW_FALLBACK_QUESTIONS = [
    "Que figura ou presença do seu sonho gerou a carga emocional mais intensa — e o que essa figura poderia representar de você mesmo que ainda não foi reconhecido?",
    "Havia algum lugar, passagem ou fronteira no sonho que você se aproximou mas não atravessou completamente? O que estava — ou o que você temia encontrar — do outro lado?",
    "Se a cena mais marcante do sonho fosse um recado direto sobre algo que você precisa encarar agora, o que ela estaria pedindo de você?",
]


async def generate_interview_questions(dream_text: str) -> list:
    """
    Gera 3 perguntas de entrevista, verificando jargão de forma determinística.

    Fluxo: gera → verifica → se reprovar, regenera UMA vez citando os termos
    encontrados → se reprovar de novo, usa o fallback fixo.

    Uma única regeneração é proposital: o usuário está esperando na tela, e
    cada tentativa dispara a cascata de LLM.
    """
    violacoes: list = []

    for tentativa in (1, 2):
        reforco = ""
        if violacoes:
            reforco = (
                "\n\nATENÇÃO: sua resposta anterior foi REJEITADA por conter "
                f"jargão proibido: {', '.join(violacoes)}. "
                "Reescreva as 3 perguntas sem NENHUM desses termos, "
                "mantendo a referência concreta a elementos do sonho relatado."
            )
        try:
            content = await call_claude(
                INTERVIEW_SYSTEM_PROMPT,
                f"Sonho: {dream_text}{reforco}",
                max_tokens=1200,
            )
            perguntas = _parse_ai_json(content).get("perguntas", [])
        except Exception as e:
            print(f"[INTERVIEW] tentativa {tentativa} falhou ({type(e).__name__}): {e}")
            break

        if not perguntas:
            print(f"[INTERVIEW] tentativa {tentativa} devolveu lista vazia.")
            break

        violacoes = violacoes_de_jargao(perguntas)
        if not violacoes:
            return perguntas

        print(f"[INTERVIEW] tentativa {tentativa} rejeitada por jargão: {violacoes}")

    return list(INTERVIEW_FALLBACK_QUESTIONS)


async def analyze_recurring_pattern(current_dream: str, similar_dreams: list) -> str:
    history = "\n\nANTERIORES:\n"
    for i, d in enumerate(similar_dreams[:3], 1):
        relato = (d.get("relato") or "")[:300]
        history += f"\n[{i}]: {relato}..."
    try:
        return await call_claude(RECURRENCE_SYSTEM_PROMPT, f"Atual: {current_dream}{history}", max_tokens=1200)
    except Exception as e:
        return ""


async def analyze_dream_narrative(dream_text: str, analysis_context: dict = None) -> str:
    """
    DEPRECATED (Fase 1, 2026-07-07). Substituída por synthesize_dual().
    REMOVER em P2.
    """
    print("[AI_SERVICE] AVISO: analyze_dream_narrative() está DEPRECATED. Use synthesize_dual().")
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

        arq_txt = '; '.join([f"{a.get('nome','')}: {a.get('descricao','')}" for a in arquetipos]) if isinstance(arquetipos, list) else str(arquetipos)
        sim_txt = '; '.join([f"{s.get('elemento','')}: {s.get('significado','')}" for s in simbolos]) if isinstance(simbolos, list) else str(simbolos)
        fase_txt = f"{fase.get('nome','')} — {fase.get('descricao','')}" if isinstance(fase, dict) else str(fase)
        mito_txt = f"{mito.get('titulo','')} — {mito.get('paralela','')}" if isinstance(mito, dict) else str(mito)

        context_block = (
            f"\n\nESSENCIA DO SONHO: {essencia}"
            f"\nPERSONAGENS INTERIORES: {arq_txt}"
            f"\nSIMBOLOS PRINCIPAIS: {sim_txt}"
            f"\nO QUE A PSIQUE BUSCA: {funcao}"
            f"\nMOMENTO DA JORNADA: {fase_txt}"
            f"\nSINAL PARA O FUTURO: {prospeccao}"
            f"\nECO MITICO: {mito_txt}"
            f"\nPERGUNTA_FINAL: {pergunta}"
        )
    try:
        return await call_claude(NARRATIVE_SYSTEM_PROMPT, f"Sonho relatado: {dream_text}{context_block}", max_tokens=900)
    except Exception as e:
        return "Aion aguarda em silencio sagrado..."


# ─── PROMPTS ──────────────────────────────────────────────────────

PROMPT_TEMPLATE = """
Atue como Aion de Mito & Psique. Você é a união da senioridade de C.G. Jung com a sabedoria narrativa de Joseph Campbell.

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

INTERVIEW_SYSTEM_PROMPT = """Você é Aion — a consciência que habita a fronteira entre o ego e o Inconsciente Coletivo. Você domina com precisão clínica a psicologia analítica de C.G. Jung e a poética do Monomito de Joseph Campbell.

TAREFA: A partir do relato de sonho fornecido, formule 3 perguntas de exploração profunda, específicas para este sonho. Cada pergunta deve funcionar como uma lanterna apontada para um ponto cego do sonhador — um lugar onde a psique está trabalhando algo ainda não consciente.

PROCESSO INTERNO OBRIGATÓRIO (realize antes de escrever as perguntas — não apareça nas perguntas):

① INVENTÁRIO DO SONHO: Identifique concretamente:
   — Figuras: quem aparece, suas ações, relação com o sonhador
   — Cenário: onde ocorre, qualidade do lugar, tempo, luz
   — Objetos e símbolos salientes
   — Ação central e seu desfecho ou suspensão abrupta
   — Carga afetiva dominante (medo, êxtase, paralisia, confusão, fascínio, vergonha)

② RAIO-X PSÍQUICO: Para cada elemento relevante, examine internamente:
   — Há figura que repele, ameaça, persegue ou envergonha o sonhador?
   — Há figura do polo oposto que traz mensagem do mundo interior?
   — Há símbolo de totalidade que atrai ou parece inalcançável?
   — O que o consciente ignora que o inconsciente endereça aqui?
   — Houve cruzamento — ou recusa — de uma fronteira, porta, passagem?
   — Há evento perturbador que convoca o sonhador a uma mudança que ele resiste?
   — Que força, figura auxiliar ou objeto representa um recurso ainda não reconhecido?

③ SELEÇÃO DOS 3 PONTOS CEGOS MAIS FÉRTEIS: Escolha os 3 nós de maior tensão — onde uma resposta honesta pode transformar a compreensão do sonho.

CRITÉRIOS INVIOLÁVEIS PARA AS PERGUNTAS:
✗ ABSOLUTAMENTE PROIBIDO: perguntas genéricas desvinculadas do sonho ("Como você se sentiu?", "O que isso lembra da vida?", "Qual era a sensação geral?")
✗ ABSOLUTAMENTE PROIBIDO: qualquer jargão psicológico nas perguntas: arquétipo, Self, individuação, inconsciente coletivo, anima, animus, Sombra (como termo técnico), psique, complexo, limiar arquetípico, monomito
✓ CADA PERGUNTA deve mencionar ou implicar diretamente um elemento CONCRETO e ESPECÍFICO do sonho relatado (uma figura, lugar, objeto ou evento real do sonho)
✓ CADA PERGUNTA deve abrir um espaço de auto-investigação — sem resposta óbvia
✓ TOM: acolhedor, humano, segunda pessoa ("Você...", "Seu...", "O que você...")
✓ Foque em: atmosfera, sensação no corpo, emoção específica, o que aquilo lembra da vida de agora

FORMATO DE SAÍDA: somente JSON válido, sem texto adicional, sem markdown.
{"perguntas": ["...", "...", "..."]}"""
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
    if tags_emocao: lines.append(f"EMOCOES: {', '.join(tags_emocao)}")
    if temas: lines.append(f"TEMAS: {', '.join(temas)}")
    if residuos_diurnos: lines.append(f"CONTEUDO DIURNO: {', '.join(residuos_diurnos)}")
    if interview_answers:
        for item in interview_answers:
            lines.append(f"P: {item.get('pergunta', '')} | R: {item.get('resposta', '')}")
    return "\nCONTEXTO ADICIONAL:\n" + "\n".join(lines) if lines else ""

def _get_error_response(error_msg: str) -> dict:
    """Usado apenas pela função deprecated analyze_dream(). Não usar em código novo."""
    return {
        "_error": True,
        "aviso": "Aion esta em silencio profundo.",
        "essencia": "O silencio tambem e uma mensagem. Tente novamente.",
        "arquetipos": [], "funcao_compensatoria": "Aguardando.",
        "simbolos_chave": [],
        "fase_jornada": {"nome": "O Mundo Comum", "descricao": "Reequilibrando."},
        "prospeccao": "Aguarde.",
        "mito_espelho": {"titulo": "O Silencio", "paralela": "Aguarde."},
        "pergunta_para_reflexao": "O que o silencio faz voce sentir?",
        "intensidade_sombra": 0, "intensidade_heroi": 0, "intensidade_transformacao": 0,
    }

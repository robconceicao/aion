import os
import time
import json
from supabase import create_client, Client
import anthropic
from dotenv import load_dotenv

# 1. Configurações Iniciais
load_dotenv()

# Credenciais Supabase
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_KEY")
if not url or not key:
    print("[ERRO]: SUPABASE_URL ou SUPABASE_KEY não encontrados.")
else:
    supabase: Client = create_client(url, key)

# Credenciais Claude (Anthropic)
api_key = os.getenv("ANTHROPIC_API_KEY")
if not api_key:
    print("[ERRO]: ANTHROPIC_API_KEY não encontrada.")
    exit(1)

client = anthropic.Anthropic(api_key=api_key)

PROMPT_TEMPLATE = """
Atue como Aion, o Oráculo de Mito & Psique — um analista junguiano de senioridade excepcional e profundo conhecedor da jornada do herói de Joseph Campbell.

Sua tarefa é realizar uma 'Amplificação Junguiana' do relato do sonho abaixo. Não se limite a descrever; conecte os elementos a imagens universais, arquétipos e dinâmicas psíquicas (Persona, Sombra, Anima/Animus, Self).

Responda APENAS com um JSON válido, sem qualquer texto adicional ou blocos de markdown, seguindo exatamente este esquema:
{{
  "aviso": "Uma breve nota ética e compassiva sobre a natureza simbólica da análise.",
  "essencia": "Uma síntese poética e profunda (2-3 frases) do 'mythos' que este sonho está tecendo.",
  "arquetipos": [
    {{ 
      "nome": "Nome do Arquétipo (ex: A Sombra, O Mentor, O Puer Aeternus)", 
      "simbolo": "emoji", 
      "descricao": "Como esta força está se manifestando no sonho." 
    }}
  ],
  "funcao_compensatoria": "Explique o que o inconsciente está tentando equilibrar em relação à atitude consciente do sonhador.",
  "simbolos_chave": [
    {{ 
      "elemento": "O objeto ou ação", 
      "significado": "A amplificação simbólica (ex: a água não é apenas água, é o fluxo do inconsciente)." 
    }}
  ],
  "fase_jornada": {{ 
    "nome": "Um dos 12 estágios da Jornada do Herói", 
    "descricao": "Por que o sonhador se encontra neste estágio específico agora." 
  }},
  "prospeccao": "O que este sonho sinaliza sobre o futuro desenvolvimento da psique (função prospectiva).",
  "pergunta_para_reflexao": "Uma pergunta que leve o sonhador a olhar para onde ele mais teme.",
  "mito_espelho": {{ 
    "titulo": "Nome de um Mito, Conto de Fadas ou Lenda Universal", 
    "paralelo": "A conexão direta entre a história milenar e o sonho atual." 
  }},
  "intensidade_sombra": 1-10,
  "intensidade_heroi": 1-10,
  "intensidade_transformacao": 1-10
}}

RELATO DO SONHO: "{relato}"
"""

def processar_novo_sonho():
    print("\n=== INICIANDO PROCESSAMENTO: MITO & PSIQUE (AION) ===")
    
    try:
        res = supabase.table("sonhos").select("*").is_("interpretacao", "null").limit(1).execute()
        
        if not res.data:
            print("Nenhum sonho novo encontrado para análise.")
            return

        sonho_data = res.data[0]
        sonho_id = sonho_data['id']
        relato_usuario = sonho_data['relato']

        modelos = [
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
        ]

        
        sucesso = False
        for model_name in modelos:
            try:
                print(f"Tentando análise com o modelo: {model_name}...")
                
                prompt = PROMPT_TEMPLATE.format(relato=relato_usuario)
                message = client.messages.create(
                    model=model_name,
                    max_tokens=2048,
                    messages=[{"role": "user", "content": prompt}]
                )
                
                content = message.content[0].text
                
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0]
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0]
                
                analise_json = json.loads(content.strip())
                supabase.table("sonhos").update({"interpretacao": analise_json}).eq("id", sonho_id).execute()
                
                print("=" * 40)
                print(f"SUCESSO! Análise salva com {model_name}.")
                print("=" * 40)
                sucesso = True
                break

            except Exception as e:
                print(f"Erro com {model_name}: {e}")
                continue
        
        if not sucesso:
            print("[ERRO FINAL]: Nenhum modelo conseguiu processar o sonho.")

    except Exception as e:
        print(f"\n[ERRO CRÍTICO]: {e}")

if __name__ == "__main__":
    print("O Oráculo está em vigília... (Modo Worker Ativo)")
    while True:
        processar_novo_sonho()
        time.sleep(30)

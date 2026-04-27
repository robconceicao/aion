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
Atue como Aion, o Mentor de Mito & Psique — um guia sábio e acolhedor que traduz as mensagens do inconsciente de forma simples, mas profunda.
Sua tarefa é explicar o significado do sonho abaixo usando os conceitos de Carl Jung e Joseph Campbell, mas SEM usar termos acadêmicos ou difíceis (como 'psicopompa', 'catatimia', etc.). 

Fale de forma que uma pessoa leiga entenda perfeitamente o que o sonho dela significa. Mantenha um tom gramaticalmente correto, mas próximo e humano.

Responda APENAS com um JSON válido, seguindo exatamente este esquema:
{{
  "aviso": "Esta análise é uma conversa simbólica e não substitui o acompanhamento de um profissional de saúde.",
  "essencia": "Uma explicação simples e profunda (2 frases) sobre o que este sonho está tecendo na sua vida.",
  "arquetipos": [
    {{ 
      "nome": "Nome do Personagem ou Força (ex: O Lado Oculto, O Sábio, O Guerreiro)", 
      "simbolo": "emoji", 
      "descricao": "Como esta força está agindo no seu sonho e na sua vida." 
    }}
  ],
  "funcao_compensatoria": "O que o seu interior está tentando equilibrar em relação ao que você está vivendo agora.",
  "simbolos_chave": [
    {{ 
      "elemento": "O objeto ou ação do sonho", 
      "significado": "O que isso representa na sua vida real de forma simples." 
    }}
  ],
  "fase_jornada": {{ 
    "nome": "O seu momento atual na vida (ex: O Chamado, O Desafio)", 
    "descricao": "Por que você se encontra nesta fase específica agora." 
  }},
  "prospeccao": "Um conselho ou sinal sobre o que pode acontecer no seu amadurecimento.",
  "pergunta_para_reflexao": "Uma pergunta simples para você levar para o seu dia a dia.",
  "mito_espelho": {{ 
    "titulo": "Uma história ou lenda antiga que se parece com a sua", 
    "paralelo": "Como a sua vida hoje se conecta com essa história milenar." 
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
        time.sleep(5)

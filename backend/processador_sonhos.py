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
Atue como Aion, o Oráculo de Mito & Psique — analista junguiano e especialista em mitologia campbelliana.
Analise o relato abaixo e responda APENAS com um JSON válido, sem markdown, seguindo exatamente este esquema:
{{
  "aviso": "Aviso compassivo lembrando que é reflexão simbólica.",
  "essencia": "2-3 frases poéticas sobre o sonho.",
  "arquetipos": [{{ "nome": "...", "simbolo": "emoji", "descricao": "..." }}],
  "funcao_compensatoria": "Equilíbrio psíquico.",
  "simbolos_chave": [{{ "elemento": "...", "significado": "..." }}],
  "fase_jornada": {{ "nome": "...", "descricao": "..." }},
  "prospeccao": "O que o sonho antecipa.",
  "pergunta_para_reflexao": "Uma pergunta poderosa.",
  "mito_espelho": {{ "titulo": "...", "paralelo": "..." }},
  "intensidade_sombra": 7,
  "intensidade_heroi": 5,
  "intensidade_transformacao": 8
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
            "claude-3-5-haiku-20241022",
            "claude-3-haiku-20240307",
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

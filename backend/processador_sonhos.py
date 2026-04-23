import os
import time
import json
from supabase import create_client, Client
from google import genai
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

# Credenciais Gemini - novo SDK
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("[ERRO]: GEMINI_API_KEY não encontrada.")
    exit(1)

# Inicializa o novo cliente do SDK
client = genai.Client(api_key=api_key)

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
        # A. Busca no Supabase o sonho pendente (interpretacao é null)
        res = supabase.table("sonhos").select("*").is_("interpretacao", "null").limit(1).execute()
        
        if not res.data:
            print("Nenhum sonho novo encontrado para análise.")
            return

        sonho_data = res.data[0]
        sonho_id = sonho_data['id']
        relato_usuario = sonho_data['relato']

        # B. Tentativa com modelos disponíveis (novo SDK)
        modelos = [
            "gemini-2.0-flash",
            "gemini-2.0-flash-lite",
            "gemini-1.5-flash",
        ]
        
        sucesso = False
        for model_name in modelos:
            try:
                print(f"Tentando análise com o modelo: {model_name}...")
                
                prompt = PROMPT_TEMPLATE.format(relato=relato_usuario)
                response = client.models.generate_content(
                    model=model_name,
                    contents=prompt
                )
                content = response.text
                
                # Limpeza de markdown
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0]
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0]
                
                analise_json = json.loads(content.strip())

                # C. Atualiza o Supabase com a análise
                supabase.table("sonhos").update({"interpretacao": analise_json}).eq("id", sonho_id).execute()
                
                print("=" * 40)
                print(f"SUCESSO! Análise salva no Supabase com {model_name}.")
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

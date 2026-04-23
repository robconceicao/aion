import os
import time
import json
from supabase import create_client, Client
import google.generativeai as genai
from dotenv import load_dotenv

# 1. Configurações Iniciais e Carga de Ambiente
load_dotenv()

# Credenciais Supabase
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_KEY")
if not url or not key:
    print("[ERRO]: SUPABASE_URL ou SUPABASE_KEY não encontrados no .env")
else:
    supabase: Client = create_client(url, key)

# Credenciais Gemini (Lógica Robusta: busca múltiplas chaves possíveis)
api_key = os.getenv("GEMINI_API_KEY") or os.getenv("API_KEY_INVENT_EXPERT")
if not api_key:
    print("[ERRO]: GEMINI_API_KEY não encontrada no .env")
    exit(1)

# Inicializa usando o SDK estável
genai.configure(api_key=api_key)

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

        # C. Tentativa inteligente entre os modelos de elite
        modelos_disponiveis = [m.name for m in genai.list_models()]
        
        prioridade = [
            "models/gemini-2.5-flash",
            "models/gemini-3-flash-preview",
            "models/gemini-2.0-flash",
            "models/gemini-flash-latest"
        ]
        
        sucesso = False
        for target_model in prioridade:
            if target_model not in modelos_disponiveis:
                continue
                
            try:
                print(f"Tentando análise com o modelo: {target_model}...")
                
                # Instruções Oraculares
                prompt = f"""
                Atue como Aion, o Oráculo de Mito & Psique — analista junguiano e especialista em mitologia campbelliana.
                Analise o relato abaixo e responda APENAS com um JSON válido seguindo exatamente este esquema:
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
                  "intensidade_sombra": 0-10,
                  "intensidade_heroi": 0-10,
                  "intensidade_transformacao": 0-10
                }}

                RELATO DO SONHO: "{relato_usuario}"
                """

                model = genai.GenerativeModel(target_model)
                response = model.generate_content(prompt)
                content = response.text
                
                # Limpeza de markdown
                if "```json" in content:
                    content = content.split("```json")[1].split("```")[0]
                elif "```" in content:
                    content = content.split("```")[1].split("```")[0]
                
                analise_json = json.loads(content.strip())

                # D. Atualiza o Supabase
                supabase.table("sonhos").update({"interpretacao": analise_json}).eq("id", sonho_id).execute()
                
                print("\n" + "="*40)
                print(f"SUCESSO! ANÁLISE SALVA NO SUPABASE.")
                print(f"Modelo que respondeu: {target_model}")
                print("="*40)
                sucesso = True
                break

            except Exception as e:
                error_msg = str(e)
                if "429" in error_msg:
                    print(f"Limite de cota atingido para {target_model}. Tentando próximo modelo...")
                    continue
                elif "503" in error_msg:
                    print(f"Modelo {target_model} ocupado. Tentando próximo...")
                    continue
                else:
                    print(f"Erro inesperado no modelo {target_model}: {error_msg}")
                    continue
        
        if not sucesso:
            print("[ERRO FINAL]: Nenhum modelo conseguiu processar o sonho no momento.")

    except Exception as e:
        print(f"\n[ERRO CRÍTICO]: {e}")

if __name__ == "__main__":
    # Modo Worker: O Aion agora fica "vigiando" o banco e processa sonhos automaticamente
    print("O Oráculo está em vigília... (Modo Worker Ativo)")
    while True:
        processar_novo_sonho()
        time.sleep(30) # Verifica novos sonhos a cada 30 segundos

import os
from google import genai
from dotenv import load_dotenv

# Carrega a chave do arquivo .env
load_dotenv()
api_key = os.getenv("GEMINI_API_KEY")

# Inicializa o novo cliente
client = genai.Client(api_key=api_key)

def analisar_sonho(texto_do_sonho):
    print("Conectando ao inconsciente coletivo (Gemini)...")
    
    # O "Prompt" é o segredo para a ótica de Jung e Campbell
    instrucoes = f"""
    Atue como Aion, um analista junguiano especialista em mitologia comparada. 
    Analise o seguinte sonho sob a ótica de Carl Jung e Joseph Campbell.
    
    SONHO: {texto_do_sonho}
    
    ESTRUTURA DA RESPOSTA — responda APENAS em JSON válido, exatamente neste formato:

    {{
      "aviso": "Frase de isenção de responsabilidade (não substitui terapia).",
      "essencia": "Essência oracular do sonho.",
      "arquetipos": [
        {{ "nome": "Nome", "simbolo": "unicode", "descricao": "Breve análise." }}
      ],
      "funcao_compensatoria": "O que o inconsciente está equilibrando.",
      "simbolos_chave": [
        {{ "elemento": "Item", "significado": "Significado simbólico." }}
      ],
      "fase_jornada": {{
        "nome": "Fase da Jornada do Herói",
        "descricao": "Explicação breve."
      }},
      "prospeccao": "O que o sonho antecipa.",
      "pergunta_para_reflexao": "Uma pergunta poderosa.",
      "mito_espelho": {{ "titulo": "Mito relacionado", "paralelo": "Paralelo simbólico." }},
      "intensidade_sombra": 0,
      "intensidade_heroi": 0,
      "intensidade_transformacao": 0
    }}
    """

    try:
        # Hierarquia de elite baseada na sua lista de modelos disponíveis
        modelos_tentativa = [
            "models/gemini-1.5-flash", 
            "models/gemini-1.5-pro",
            "models/gemini-pro"
        ]
        
        for model_name in modelos_tentativa:
            try:
                print(f"Tentando modelo: {model_name}...")
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(instrucoes)
                return response.text
            except Exception as e:
                error_msg = str(e)
                if "429" in error_msg:
                    print(f"Modelo {model_name} atingiu a cota. Tentando próximo...")
                    continue
                elif "503" in error_msg:
                    print(f"Modelo {model_name} ocupado. Tentando próximo...")
                    continue
                
                # Se for o último modelo e falhar por outro motivo, propaga o erro
                if model_name == modelos_tentativa[-1]:
                    raise e
                continue

    except Exception as e:
        return f"Erro na conexão: {e}"

# Teste rápido
if __name__ == "__main__":
    relato = input("Descreva o sonho para análise: ")
    resultado = analisar_sonho(relato)
    print("\n--- ANÁLISE ---")
    print(resultado)
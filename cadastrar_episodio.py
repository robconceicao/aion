"""
Cadastrador de Episódios — Canal Mito & Psique
================================================
Como usar:
  1. Edite a lista EPISODIOS abaixo com os dados do(s) seu(s) episódio(s).
  2. Execute: python cadastrar_episodio.py
  3. O script exibe o resultado de cada cadastro.

Dependência: pip install requests (geralmente já instalada)
"""

import json
import requests

API_URL = "https://aion-vvx7.onrender.com/episodes/"

# ─── Edite aqui seus episódios ─────────────────────────────────────────────
EPISODIOS = [
    {
        "number": 1,
        "title_main": "O Mito do Herói",
        "title_secondary": "A Jornada de Campbell e o Inconsciente",
        "myths_symbols": ["Jornada do Herói", "Iniciação", "Threshold Guardian"],
        "description": "Exploramos como a estrutura monomítica de Joseph Campbell se manifesta nos sonhos e na psique individual.",
    },
    # Adicione mais episódios abaixo no mesmo formato:
    # {
    #     "number": 2,
    #     "title_main": "A Sombra",
    #     "title_secondary": "O Lado Oculto da Psique Junguiana",
    #     "myths_symbols": ["Sombra", "Duplo", "Mr. Hyde"],
    #     "description": "Jung e o encontro inevitável com tudo que rejeitamos em nós mesmos.",
    # },
]
# ───────────────────────────────────────────────────────────────────────────


def cadastrar(ep: dict) -> None:
    numero = ep.get("number")
    titulo = ep.get("title_main")

    print(f"\n🌑 Cadastrando EP. {numero:02d} — {titulo}...")

    try:
        response = requests.post(
            API_URL,
            json=ep,
            timeout=30,
            headers={"Content-Type": "application/json"},
        )

        if response.status_code == 201:
            dados = response.json()
            print(f"   ✅ Criado com sucesso! ID: {dados.get('_id', '—')}")

        elif response.status_code == 409:
            print(f"   ⚠️  Episódio {numero} já existe no banco. Nenhuma alteração feita.")
            print(f"      (Use PUT /episodes/{numero} para atualizar)")

        else:
            print(f"   ❌ Erro {response.status_code}: {response.text}")

    except requests.ConnectionError:
        print("   ❌ Sem conexão com o servidor. Verifique se o backend está rodando.")
    except requests.Timeout:
        print("   ❌ Timeout — o servidor demorou demais para responder. Tente novamente.")
    except Exception as e:
        print(f"   ❌ Erro inesperado: {e}")


def listar_episodios() -> None:
    print("\n📋 Episódios cadastrados no canal:")
    try:
        response = requests.get(API_URL, timeout=15)
        episodios = response.json()

        if not episodios:
            print("   (nenhum episódio cadastrado ainda)")
            return

        for ep in episodios:
            tags = ", ".join(ep.get("myths_symbols", []))
            print(f"   EP. {ep['number']:02d} | {ep['title_main']}")
            print(f"         {ep['title_secondary']}")
            if tags:
                print(f"         [{tags}]")
    except Exception as e:
        print(f"   Erro ao listar: {e}")


if __name__ == "__main__":
    print("=" * 55)
    print("  AION — Cadastrador de Episódios do Canal")
    print("=" * 55)

    for ep in EPISODIOS:
        cadastrar(ep)

    listar_episodios()

    print("\nConcluído.")

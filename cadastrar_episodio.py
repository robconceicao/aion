"""
Cadastrador de Episódios — Canal Mito & Psique
================================================
Como usar:
  1. Edite a lista EPISODIOS abaixo com os dados do(s) seu(s) episódio(s).
  2. Certifique-se de que o backend está configurado com as credenciais corretas do Supabase.
  3. Execute: python cadastrar_episodio.py
  4. Insira seu e-mail e senha de administrador quando solicitado.
  5. O script realiza o login no Supabase, obtém o token JWT e faz o cadastro de forma segura.
"""

import json
import os
import requests
import getpass

# Defina a URL do seu servidor backend
API_URL = "https://aion-vvx7.onrender.com/episodes/"
# Caso queira testar localmente, descomente a linha abaixo:
# API_URL = "http://localhost:8000/episodes/"

# ─── Edite aqui seus episódios ─────────────────────────────────────────────
EPISODIOS = [
    {
        "number": 1,
        "title_main": "O Mito do Herói",
        "title_secondary": "A Jornada de Campbell e o Inconsciente",
        "myths_symbols": ["Jornada do Herói", "Iniciação", "Threshold Guardian"],
        "description": "Exploramos como a estrutura monomítica de Joseph Campbell se manifesta nos sonhos e na psique individual.",
    },
]
# ───────────────────────────────────────────────────────────────────────────


def carregar_credenciais_supabase():
    """Tenta carregar a URL e a chave anônima do Supabase a partir do .env do backend."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    paths = [
        os.path.join(base_dir, "backend", ".env"),
        os.path.join(base_dir, ".env"),
        "backend/.env",
        ".env"
    ]
    supabase_url = None
    supabase_key = None
    
    for p in paths:
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        if "=" in line:
                            k, v = line.split("=", 1)
                            if k.strip() == "SUPABASE_URL":
                                supabase_url = v.strip()
                            elif k.strip() == "SUPABASE_KEY":
                                supabase_key = v.strip()
                if supabase_url and supabase_key:
                    break
            except Exception as e:
                print(f"⚠️  Erro ao ler arquivo {p}: {e}")
                
    return supabase_url, supabase_key


def obter_token_jwt(supabase_url: str, supabase_key: str) -> str:
    """Solicita credenciais do administrador e obtém o token JWT do Supabase Auth."""
    print("\n🔐 Autenticação de Administrador")
    print(f"Usando Supabase: {supabase_url}")
    
    email = input("E-mail: ").strip()
    senha = getpass.getpass("Senha: ").strip()
    
    url = f"{supabase_url}/auth/v1/token?grant_type=password"
    headers = {
        "apikey": supabase_key,
        "Content-Type": "application/json"
    }
    payload = {
        "email": email,
        "password": senha
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=15)
        if response.status_code == 200:
            data = response.json()
            token = data.get("access_token")
            print("✅ Autenticado com sucesso!")
            return token
        else:
            err_msg = response.json().get("error_description", response.text)
            print(f"❌ Falha na autenticação ({response.status_code}): {err_msg}")
            return None
    except Exception as e:
        print(f"❌ Erro de conexão com o Supabase: {e}")
        return None


def cadastrar(ep: dict, token: str) -> None:
    numero = ep.get("number")
    titulo = ep.get("title_main")

    print(f"\n🌑 Cadastrando EP. {numero:02d} — {titulo}...")

    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {token}"
    }

    try:
        response = requests.post(
            API_URL,
            json=ep,
            timeout=30,
            headers=headers,
        )

        if response.status_code in [200, 201]:
            dados = response.json()
            print(f"   ✅ Criado com sucesso! ID: {dados.get('id', '—')}")

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

        if not episodios or not isinstance(episodios, list):
            print("   (nenhum episódio cadastrado ainda ou formato inválido)")
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

    sub_url, sub_key = carregar_credenciais_supabase()
    if not sub_url or not sub_key:
        print("❌ Erro: Não foi possível carregar as credenciais do Supabase a partir do arquivo .env.")
        print("Certifique-se de que backend/.env existe e contém SUPABASE_URL e SUPABASE_KEY.")
        exit(1)

    token = obter_token_jwt(sub_url, sub_key)
    if not token:
        print("❌ Erro: Não foi possível obter o token JWT de administrador. Operação abortada.")
        exit(1)

    for ep in EPISODIOS:
        cadastrar(ep, token)

    listar_episodios()

    print("\nConcluído.")

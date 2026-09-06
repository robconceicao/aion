#!/bin/bash
set -euo pipefail

echo "=== INICIANDO BUILD DIRETO (AION) ==="

# Configurações de Caminho
# No Vercel: buildCommand faz `cd frontend && bash build.sh` → PWD = frontend/
PROJECT_ROOT=$PWD
REPO_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"

# 1. Escolher o Flutter SDK
#
# Antes daqui o caminho era fixo em $PROJECT_ROOT/flutter, então rodar este
# script na máquina de quem já tem Flutter instalado baixava um SDK inteiro
# dentro do repositório — centenas de MB duplicados que ainda por cima faziam
# `flutter analyze` varrer o SDK e reportar milhares de erros que não são do
# projeto.
#
# Ordem de precedência, do mais explícito ao último recurso:
#   1) FLUTTER_SDK do ambiente — override manual, vale sobre tudo
#   2) o flutter que já estiver no PATH — o caso da máquina do dev
#   3) clone em $PROJECT_ROOT/flutter — o caso do Vercel, onde não há nenhum
if [ -n "${FLUTTER_SDK:-}" ]; then
  FLUTTER_BIN=$FLUTTER_SDK/bin/flutter
  if [ ! -f "$FLUTTER_BIN" ]; then
    echo "ERRO: FLUTTER_SDK=$FLUTTER_SDK não contém bin/flutter." >&2
    exit 1
  fi
  echo "Flutter SDK definido pelo ambiente: $FLUTTER_SDK"
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
  FLUTTER_SDK="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"
  echo "Usando o Flutter já instalado: $FLUTTER_SDK"
else
  FLUTTER_SDK=$PROJECT_ROOT/flutter
  FLUTTER_BIN=$FLUTTER_SDK/bin/flutter
  if [ ! -f "$FLUTTER_BIN" ]; then
    echo "Nenhum Flutter no PATH. Baixando para $FLUTTER_SDK..."
    rm -rf "$FLUTTER_SDK"
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_SDK"
    echo "Download concluído."
  else
    echo "Usando o Flutter do repositório: $FLUTTER_SDK"
  fi
fi

# Adicionar ao PATH para esta sessão
export PATH="$FLUTTER_SDK/bin:$PATH"

# Verificar se o comando agora funciona
echo "Verificando versão do Flutter..."
$FLUTTER_BIN --version

# 2. Configurações de ambiente
export FLUTTER_ALLOW_HTTP=true
export NO_PROXY=localhost,127.0.0.1

# 3. Supabase defines (obrigatório — sem isso a web fica em tela branca)
#    Prioridade:
#      1) Env vars (Vercel / CI)
#         - SUPABASE_URL
#         - SUPABASE_ANON_KEY (preferido) ou SUPABASE_KEY (legado no projeto Vercel)
#      2) --dart-define-from-file=dart_define.json (local)
DEFINE_ARGS=()

# Preferir ANON_KEY; aceitar SUPABASE_KEY como fallback (já existe no Vercel).
SUPABASE_ANON_EFFECTIVE="${SUPABASE_ANON_KEY:-${SUPABASE_KEY:-}}"

if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_EFFECTIVE}" ]; then
  if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
    echo "Usando SUPABASE_URL + SUPABASE_ANON_KEY do ambiente (CI/Vercel)."
  else
    echo "Usando SUPABASE_URL + SUPABASE_KEY (legado) do ambiente — mapeado para ANON_KEY no build."
  fi
  # Não imprime valores (secrets). Flutter espera o nome SUPABASE_ANON_KEY.
  DEFINE_ARGS+=(--dart-define="SUPABASE_URL=${SUPABASE_URL}")
  DEFINE_ARGS+=(--dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_EFFECTIVE}")
elif [ -f "$REPO_ROOT/dart_define.json" ]; then
  echo "Usando dart_define.json na raiz do repositório."
  DEFINE_ARGS+=(--dart-define-from-file="$REPO_ROOT/dart_define.json")
elif [ -f "$PROJECT_ROOT/dart_define.json" ]; then
  echo "Usando dart_define.json em frontend/."
  DEFINE_ARGS+=(--dart-define-from-file="$PROJECT_ROOT/dart_define.json")
else
  echo "ERROR: SUPABASE_URL e chave anon não configurados."
  echo "No Vercel: Project Settings → Environment Variables → adicione:"
  echo "  SUPABASE_URL"
  echo "  SUPABASE_ANON_KEY  (ou SUPABASE_KEY com a anon key pública)"
  echo "Local: copie dart_define.example.json → dart_define.json e preencha."
  exit 1
fi

echo "Limpando caches..."
$FLUTTER_BIN clean || true

echo "Instalando dependências..."
$FLUTTER_BIN pub get

echo "Iniciando compilação WEB (com dart-defines do Supabase)..."
$FLUTTER_BIN build web --release --base-href / --no-source-maps "${DEFINE_ARGS[@]}"

echo "=== BUILD FINALIZADO COM SUCESSO! ==="

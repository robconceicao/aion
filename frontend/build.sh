#!/bin/bash
set -e

echo "=== INICIANDO BUILD DIRETO (AION) ==="

# Configurações de Caminho
PROJECT_ROOT=$PWD
FLUTTER_SDK=$PROJECT_ROOT/flutter
FLUTTER_BIN=$FLUTTER_SDK/bin/flutter

# 1. Garantir Flutter SDK
if [ ! -f "$FLUTTER_BIN" ]; then
  echo "Flutter não encontrado em $FLUTTER_BIN. Iniciando download..."
  rm -rf "$FLUTTER_SDK"
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_SDK"
  echo "Download concluído."
fi

# Adicionar ao PATH para esta sessão
export PATH="$FLUTTER_SDK/bin:$PATH"

# Verificar se o comando agora funciona
echo "Verificando versão do Flutter..."
$FLUTTER_BIN --version

# 2. Configurações de ambiente
export FLUTTER_ALLOW_HTTP=true
export NO_PROXY=localhost,127.0.0.1

echo "Limpando caches..."
$FLUTTER_BIN clean || true

echo "Instalando dependências..."
$FLUTTER_BIN pub get

echo "Iniciando compilação WEB..."
$FLUTTER_BIN build web --release --base-href / --no-source-maps

echo "=== BUILD FINALIZADO COM SUCESSO! ==="


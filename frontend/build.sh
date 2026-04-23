#!/bin/bash
set -e

# Configurações iniciais
FLUTTER_PATH="$PWD/flutter"
export PATH="$FLUTTER_PATH/bin:$PATH"

echo "=== INICIANDO BUILD DIRETO (AION) ==="

# 1. Garantir Flutter SDK
if [ ! -d "$FLUTTER_PATH" ]; then
  echo "Baixando Flutter..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_PATH"
fi

# 2. Configurações para evitar erro de Root e Memória
export FLUTTER_ALLOW_HTTP=true
export NO_PROXY=localhost,127.0.0.1

echo "Limpando caches anteriores..."
flutter clean || true

echo "Instalando dependências..."
flutter pub get

echo "Iniciando compilação WEB (Modo Standard)..."
# Removendo --web-renderer e --no-tree-shake-icons para evitar erro de opção
# Deixando apenas o básico que funciona em qualquer versão
flutter build web --release --base-href / --no-source-maps

echo "=== BUILD FINALIZADO! ==="

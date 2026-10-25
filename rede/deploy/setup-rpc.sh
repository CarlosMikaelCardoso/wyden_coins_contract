#!/usr/bin/env bash
# ==============================================================================
# setup-rpc.sh
# Script utilitário para extrair e iniciar o nó RPC / Gateway.
# Uso: ./setup-rpc.sh rpc-node.tar.gz
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

PACKAGE_TAR="${1:-rpc-node.tar.gz}"

if [[ ! -f "${PACKAGE_TAR}" ]]; then
  echo "Uso: $(basename "${0}") <arquivo_rpc-node.tar.gz>"
  echo "Exemplo: $(basename "${0}") rpc-node.tar.gz"
  exit 1
fi

echo "📦 Extraindo ${PACKAGE_TAR}..."
tar -xzf "${PACKAGE_TAR}"

cd "rpc-node"
echo "🚀 Iniciando nó RPC / Gateway (Portas 8545 e 8645)..."
./run.sh

sleep 5
./check.sh

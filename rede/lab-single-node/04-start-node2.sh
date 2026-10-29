#!/usr/bin/env bash
# ==============================================================================
# 04-start-node2.sh (lab-single-node)
# Inicializa o Nó 2 (Validador 2) na porta P2P 30304 e RPC 8542.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

NODE_DIR="${REDE_DIR}/dist/node2"

if [[ ! -d "${NODE_DIR}" ]]; then
  echo "❌ Diretório ${NODE_DIR} não encontrado. Execute ./02-generate-network.sh primeiro."
  exit 1
fi

echo "================================================================="
echo "   INICIANDO NÓ 2 (VALIDADOR 2)                                 "
echo "================================================================="

cd "${NODE_DIR}"
./run.sh

echo "Aguardando 4 segundos para conexão P2P com o Nó 1..."
sleep 4

./check.sh

#!/usr/bin/env bash
# ==============================================================================
# 03-start-node1.sh (lab-single-node)
# Inicializa o Nó 1 (Validador 1 / Bootnode) na porta P2P 30303 e RPC 8541.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

NODE_DIR="${REDE_DIR}/dist/node1"

if [[ ! -d "${NODE_DIR}" ]]; then
  echo "❌ Diretório ${NODE_DIR} não encontrado. Execute ./02-generate-network.sh primeiro."
  exit 1
fi

echo "================================================================="
echo "   INICIANDO NÓ 1 (VALIDADOR 1 / BOOTNODE)                      "
echo "================================================================="

cd "${NODE_DIR}"
./run.sh

echo "Aguardando 4 segundos para inicialização do contêiner..."
sleep 4

./check.sh

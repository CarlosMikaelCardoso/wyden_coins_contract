#!/usr/bin/env bash
# ==============================================================================
# 05-start-node3.sh (lab-single-node)
# Inicializa o Nó 3 (Validador 3) na porta P2P 30305 e RPC 8543.
# Nota: Com 3 validadores online, o consenso QBFT atinge a maioria qualificada (2F+1)
# e a produção contínua de blocos é iniciada!
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

NODE_DIR="${REDE_DIR}/dist/node3"

if [[ ! -d "${NODE_DIR}" ]]; then
  echo "❌ Diretório ${NODE_DIR} não encontrado. Execute ./02-generate-network.sh primeiro."
  exit 1
fi

echo "================================================================="
echo "   INICIANDO NÓ 3 (VALIDADOR 3) - ATIVAÇÃO DO QUORUM QBFT       "
echo "================================================================="

cd "${NODE_DIR}"
./run.sh

echo "Aguardando 4 segundos para formação de quorum QBFT..."
sleep 4

./check.sh

echo ""
echo "✨ [QUORUM QBFT ALCANÇADO]: 3 nós validadores conectados!"
echo "A blockchain agora está produzindo blocos ativamente a cada 2 segundos."

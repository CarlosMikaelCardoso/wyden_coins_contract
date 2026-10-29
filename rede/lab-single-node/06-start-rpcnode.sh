#!/usr/bin/env bash
# ==============================================================================
# 06-start-rpcnode.sh (lab-single-node)
# Inicializa o Nó 4 (Gateway RPC / Membro) na porta 8545 e WebSockets 8645.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

NODE_DIR="${REDE_DIR}/dist/rpc-node"

if [[ ! -d "${NODE_DIR}" ]]; then
  echo "❌ Diretório ${NODE_DIR} não encontrado. Execute ./02-generate-network.sh primeiro."
  exit 1
fi

echo "================================================================="
echo "   INICIANDO NÓ 4 (GATEWAY RPC / CONSULTAS / DAPPS)             "
echo "================================================================="

cd "${NODE_DIR}"
./run.sh

echo "Aguardando 4 segundos para conexão P2P e ativação do endpoint RPC..."
sleep 4

./check.sh

echo ""
echo "🌐 Gateway RPC pronto para conexões externas:"
echo "   - JSON-RPC HTTP : http://127.0.0.1:8545"
echo "   - WebSockets    : ws://127.0.0.1:8645"

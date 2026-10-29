#!/usr/bin/env bash
# ==============================================================================
# 07-check-network.sh (lab-single-node)
# Realiza diagnóstico consolidado de todos os 4 nós locais e do endpoint RPC.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   DIAGNÓSTICO CONSOLIDADO DA REDE LOCAL (4 NÓS)                "
echo "================================================================="

echo "📦 Status dos Contêineres Besu:"
docker ps --filter "name=besu" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Consultando RPC do Gateway (http://127.0.0.1:8545)..."
"${REDE_DIR}/scripts/check-node.sh" --port 8545

echo ""
echo "🏛️ Validadores Ativos no Consenso QBFT:"
curl -s -X POST --data '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" http://127.0.0.1:8545 | jq .

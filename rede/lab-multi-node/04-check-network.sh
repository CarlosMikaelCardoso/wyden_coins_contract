#!/usr/bin/env bash
# ==============================================================================
# 04-check-network.sh (lab-multi-node)
# Realiza diagnóstico remoto do nó RPC (VM 4) a partir de qualquer computador.
# Uso: ./04-check-network.sh --rpc-ip <rpc-ip>
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

RPC_IP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rpc-ip) RPC_IP="$2"; shift 2 ;;
    *)
      if [[ -z "${RPC_IP}" ]]; then
        RPC_IP="$1"
        shift
      else
        shift
      fi
      ;;
  esac
done

if [[ -z "${RPC_IP}" ]]; then
  echo -n "Digite o IP da VM 4 (Gateway RPC) [<rpc-ip>]: "
  read -r RPC_IP || true
  RPC_IP="${RPC_IP:-127.0.0.1}"
fi

echo "================================================================="
echo "   DIAGNÓSTICO DA REDE MULTI-NODE (GATEWAY: http://${RPC_IP}:8545)"
echo "================================================================="

"${REDE_DIR}/scripts/check-node.sh" --host "${RPC_IP}" --port 8545

echo ""
echo "🏛️ Validadores Ativos no Consenso QBFT:"
curl -s -X POST --data '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" "http://${RPC_IP}:8545" | jq .

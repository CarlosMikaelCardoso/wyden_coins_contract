#!/usr/bin/env bash
# ==============================================================================
# check-node.sh
# Utilitário para verificar a saúde, peers e bloco atual de um nó Besu via JSON-RPC.
# ==============================================================================
RPC_PORT="8545"
RPC_HOST="127.0.0.1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--port)
      RPC_PORT="$2"
      shift 2
      ;;
    -h|--host)
      RPC_HOST="$2"
      shift 2
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        RPC_PORT="$1"
        shift
      else
        shift
      fi
      ;;
  esac
done

RPC_URL="http://${RPC_HOST}:${RPC_PORT}"

echo "================================================================="
echo "   DIAGNÓSTICO DO NÓ HYPERLEDGER BESU (${RPC_URL})               "
echo "================================================================="

# 1. Verifica conectividade RPC
NET_VERSION=$(curl -s -X POST --connect-timeout 3 --max-time 5 \
  --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  -H "Content-Type: application/json" "${RPC_URL}" 2>/dev/null | jq -r .result 2>/dev/null || echo "")

if [[ -z "${NET_VERSION}" || "${NET_VERSION}" == "null" ]]; then
  echo "❌ Não foi possível comunicar com o endpoint JSON-RPC em ${RPC_URL}."
  echo "Verifique se o nó está rodando (docker ps) e se o RPC está habilitado na porta ${RPC_PORT}."
  exit 1
fi

echo "✓ Conexão estabelecida com sucesso!"
echo "   Chain ID          : ${NET_VERSION}"

# 2. Peers conectados
PEERS_HEX=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  -H "Content-Type: application/json" "${RPC_URL}" | jq -r .result)
PEERS_DEC=$(( ${PEERS_HEX} ))
echo "   Peers Conectados  : ${PEERS_DEC} (${PEERS_HEX})"

# 3. Bloco atual
BLOCK_HEX=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" "${RPC_URL}" | jq -r .result)
BLOCK_DEC=$(( ${BLOCK_HEX} ))
echo "   Bloco Atual       : ${BLOCK_DEC} (${BLOCK_HEX})"

# 4. Status de Sincronização
SYNC=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  -H "Content-Type: application/json" "${RPC_URL}" | jq -r .result)
echo "   Sincronizando?    : ${SYNC}"

# 5. Lista de Validadores QBFT
VALIDATORS=$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" "${RPC_URL}" 2>/dev/null | jq -r '.result[]?' 2>/dev/null || echo "")

if [[ -n "${VALIDATORS}" ]]; then
  echo "   Validadores QBFT  :"
  for v in ${VALIDATORS}; do
    echo "     ↳ ${v}"
  done
fi

echo "================================================================="

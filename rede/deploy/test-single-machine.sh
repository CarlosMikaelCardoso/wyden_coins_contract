#!/usr/bin/env bash
# ==============================================================================
# test-single-machine.sh
# Validação completa da rede Besu QBFT (4 nós) em uma única máquina física ou virtual
# Testa a integridade dos scripts e contêineres antes da distribuição em múltiplos nós.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   VALIDAÇÃO DA REDE BESU COMPLETA EM MÁQUINA ÚNICA             "
echo "   (VM 1: Bootnode, VM 2: Validador, VM 3: Validador, VM 4: RPC) "
echo "================================================================="

# 1. Parar e limpar contêineres antigos
echo "🧹 [1/5] Limpando instâncias Besu antigas..."
docker rm -f node1 node2 node3 node4 node5 node6 rpcnode \
             besu-node1 besu-node2 besu-node3 besu-rpcnode 2>/dev/null || true

# 2. Gerar chaves e gênese para localhost
echo ""
echo "⚙️  [2/5] Gerando chaves criptográficas e gênese QBFT..."
"${REDE_DIR}/core/01-generate-network.sh" --bootnode-ip 127.0.0.1

# 3. Empacotar nós em modo single-machine (portas incrementais)
echo ""
echo "📦 [3/5] Empacotando nós com portas incrementais locais..."
"${REDE_DIR}/core/02-package-nodes.sh" --single-machine

# 4. Inicializar os 4 nós sequencialmente utilizando seus scripts .sh autônomos
echo ""
echo "🚀 [4/5] Executando o script run.sh de cada nó..."

echo "   ↳ Iniciando Nó 1 (Validador 1 / Bootnode na porta 30303)..."
(cd "${REDE_DIR}/dist/node1" && ./run.sh)
sleep 2

echo "   ↳ Iniciando Nó 2 (Validador 2 na porta 30304)..."
(cd "${REDE_DIR}/dist/node2" && ./run.sh)
sleep 2

echo "   ↳ Iniciando Nó 3 (Validador 3 na porta 30305)..."
(cd "${REDE_DIR}/dist/node3" && ./run.sh)
sleep 2

echo "   ↳ Iniciando Nó 4 (Gateway RPC na porta 30306 | RPC 8545)..."
(cd "${REDE_DIR}/dist/rpc-node" && ./run.sh)

echo ""
echo "⏳ Aguardando os nós Besu subirem e a interface RPC responder (porta 8545)..."
MAX_ATTEMPTS=30
attempt=1
while [[ ${attempt} -le ${MAX_ATTEMPTS} ]]; do
  if curl -s -X POST --connect-timeout 1 --max-time 2 \
       --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
       -H "Content-Type: application/json" http://127.0.0.1:8545 2>/dev/null | grep -q "result"; then
    echo "✓ Interface RPC ativa e respondendo! (Tentativa ${attempt})"
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done

# Aguarda mais 4 segundos para avanço contínuo do consenso QBFT
sleep 4

# 5. Diagnóstico de saúde e validação dos 4 nós
echo ""
echo "🔍 [5/5] Executando diagnóstico com check.sh em cada nó..."
echo "--- Status Nó 1 ---"
(cd "${REDE_DIR}/dist/node1" && ./check.sh)

echo ""
echo "--- Status Nó 2 ---"
(cd "${REDE_DIR}/dist/node2" && ./check.sh)

echo ""
echo "--- Status Nó 3 ---"
(cd "${REDE_DIR}/dist/node3" && ./check.sh)

echo ""
echo "--- Status Nó 4 (Gateway RPC) ---"
(cd "${REDE_DIR}/dist/rpc-node" && ./check.sh)

echo ""
echo "================================================================="
echo "   VALIDAÇÃO GERAL DA REDE (JSON-RPC 8545)                       "
echo "================================================================="
"${REDE_DIR}/scripts/check-node.sh" --port 8545

echo ""
echo "🎉 Todos os scripts .sh e contêineres foram validados com sucesso!"
echo "A rede está ativa e produzindo blocos normalmente."
echo "Para parar a rede de teste: ${REDE_DIR}/scripts/stop-node.sh"
echo "================================================================="

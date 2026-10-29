#!/usr/bin/env bash
# ==============================================================================
# 02-generate-network.sh (lab-single-node)
# Gera chaves criptográficas, bloco gênese QBFT e pacotes dos nós locais.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   ETAPA 2: GERAÇÃO CRIPTOGRÁFICA E GÊNESE QBFT                 "
echo "================================================================="

# 1. Gera chaves criptográficas para 3 validadores e o bloco gênese (localhost)
"${REDE_DIR}/core/01-generate-network.sh" --bootnode-ip 127.0.0.1

echo ""
echo "================================================================="
echo "   ETAPA 3: EMPACOTAMENTO DOS NÓS COM PORTAS LOCAIS DEDICADAS    "
echo "================================================================="

# 2. Empacota os nós com mapeamento de portas incrementais para máquina única
"${REDE_DIR}/core/02-package-nodes.sh" --single-machine

echo ""
echo "✓ Configurações dos nós geradas com sucesso em dist/!"
echo "  - Nó 1 (Bootnode): P2P 30303, RPC 8541"
echo "  - Nó 2 (Validador): P2P 30304, RPC 8542"
echo "  - Nó 3 (Validador): P2P 30305, RPC 8543"
echo "  - Nó 4 (Gateway RPC): P2P 30306, RPC 8545 (Padrão para DApps)"

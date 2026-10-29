#!/usr/bin/env bash
# ==============================================================================
# 08-stop-network.sh (lab-single-node)
# Encerra e remove todos os contêineres Besu em execução na máquina local.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   ENCERRANDO TODOS OS NÓS BESU LOCAIS                          "
echo "================================================================="

"${REDE_DIR}/scripts/stop-node.sh"

echo ""
echo "Para limpar também as pastas de banco de dados e recriar a rede do zero:"
echo "  rm -rf ${REDE_DIR}/dist/*/data/DATABASE ${REDE_DIR}/dist/*/data/caches"

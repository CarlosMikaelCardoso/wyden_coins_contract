#!/usr/bin/env bash
# ==============================================================================
# 05-stop-network.sh (lab-multi-node)
# Para o nó Besu em execução na máquina atual.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   ENCERRANDO NÓ BESU LOCAL                                     "
echo "================================================================="

"${REDE_DIR}/scripts/stop-node.sh"

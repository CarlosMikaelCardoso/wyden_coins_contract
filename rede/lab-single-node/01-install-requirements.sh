#!/usr/bin/env bash
# ==============================================================================
# 01-install-requirements.sh (lab-single-node)
# Verifica e instala os pré-requisitos necessários (Docker e Docker Compose).
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   ETAPA 1: VERIFICAÇÃO DE PRÉ-REQUISITOS (DOCKER / COMPOSE)    "
echo "================================================================="

"${REDE_DIR}/scripts/install-docker.sh"

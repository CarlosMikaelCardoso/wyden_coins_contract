#!/usr/bin/env bash
# ==============================================================================
# 01-install-requirements.sh (lab-multi-node)
# Instala e valida os pré-requisitos (Docker e Docker Compose) em qualquer VM.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

echo "================================================================="
echo "   ETAPA 1: INSTALAÇÃO DE PRÉ-REQUISITOS NA VM (DOCKER)         "
echo "================================================================="

"${REDE_DIR}/scripts/install-docker.sh"

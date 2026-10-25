#!/usr/bin/env bash
# ==============================================================================
# setup-validator.sh
# Script utilitário para extrair e iniciar um nó validador em uma máquina secundária.
# Uso: ./setup-validator.sh node2.tar.gz
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

PACKAGE_TAR="${1:-}"

if [[ -z "${PACKAGE_TAR}" || ! -f "${PACKAGE_TAR}" ]]; then
  echo "Uso: $(basename "${0}") <arquivo_nodeX.tar.gz>"
  echo "Exemplo: $(basename "${0}") node2.tar.gz"
  exit 1
fi

NODE_FOLDER=$(tar -tzf "${PACKAGE_TAR}" | head -1 | cut -f1 -d"/")

echo "📦 Extraindo ${PACKAGE_TAR}..."
tar -xzf "${PACKAGE_TAR}"

cd "${NODE_FOLDER}"
echo "🚀 Iniciando nó ${NODE_FOLDER}..."
./run.sh

sleep 5
./check.sh

#!/usr/bin/env bash
# ==============================================================================
# stop-node.sh
# Para qualquer container Besu em execução e opcionalmente limpa dados.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

CLEAN_DATA="${1:-false}"

echo "🛑 Parando contêineres Besu locais..."
CONTAINERS=$(docker ps -a --filter "name=besu" --format "{{.ID}}")

if [[ -n "${CONTAINERS}" ]]; then
  docker stop ${CONTAINERS} || true
  docker rm ${CONTAINERS} || true
  echo "✓ Contêineres Besu encerrados e removidos."
else
  echo "ℹ️  Nenhum contêiner Besu em execução encontrado."
fi

if [[ "${CLEAN_DATA}" == "--clean" || "${CLEAN_DATA}" == "-c" ]]; then
  echo "⚠️  Limpando diretórios de dados temporários..."
  rm -rf /tmp/besu-data*
fi

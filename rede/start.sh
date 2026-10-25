#!/usr/bin/env bash
# ==============================================================================
# start.sh (Wrapper de Compatibilidade)
# Redireciona a execução para a nova arquitetura modular Multi-Node (Ilíada/RNP)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🚀 [Besu Multi-Node] Redirecionando para o orquestrador do coordenador..."
exec "${SCRIPT_DIR}/deploy/setup-coordinator.sh" "$@"

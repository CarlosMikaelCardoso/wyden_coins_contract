#!/usr/bin/env bash
# ==============================================================================
# stop.sh (Wrapper de Compatibilidade)
# Redireciona a parada da rede para o utilitário scripts/stop-node.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "🛑 [Besu Multi-Node] Parando nós Besu..."
exec "${SCRIPT_DIR}/scripts/stop-node.sh" "$@"

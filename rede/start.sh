#!/usr/bin/env bash
# ==============================================================================
# start.sh (Wrapper de Execução da Rede)
# - Modo Padrão: Multi-VMs (Coordenador + Pacotes em dist/)
# - Modo Local : Validação Completa da Rede em Máquina Única (--local / --single-machine)
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  if [[ "$arg" == "--single-machine" || "$arg" == "--local" || "$arg" == "-l" ]]; then
    echo "🧪 [Besu] Redirecionando para validação local em máquina única..."
    exec "${SCRIPT_DIR}/deploy/test-single-machine.sh" "$@"
  fi
done

echo "🚀 [Besu Multi-Node] Redirecionando para o orquestrador do coordenador..."
exec "${SCRIPT_DIR}/deploy/setup-coordinator.sh" "$@"

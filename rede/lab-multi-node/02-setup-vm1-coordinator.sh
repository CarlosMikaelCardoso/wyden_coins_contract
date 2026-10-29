#!/usr/bin/env bash
# ==============================================================================
# 02-setup-vm1-coordinator.sh (lab-multi-node)
# Executado na VM 1: Gera a rede, empacota os nós distribuídos e inicia o Nó 1.
# Uso: ./02-setup-vm1-coordinator.sh --bootnode-ip <node1-ip>
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

BOOTNODE_IP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--bootnode-ip)
      BOOTNODE_IP="$2"
      shift 2
      ;;
    *)
      if [[ -z "${BOOTNODE_IP}" ]]; then
        BOOTNODE_IP="$1"
        shift
      else
        shift
      fi
      ;;
  esac
done

if [[ -z "${BOOTNODE_IP}" ]]; then
  echo "🔍 Nenhum IP foi especificado via --bootnode-ip."
  echo -n "Digite o IP da VM 1 (Coordenadora / Bootnode) [<node1-ip>]: "
  read -r INPUT_IP || true
  BOOTNODE_IP="${INPUT_IP:-127.0.0.1}"
fi

echo "================================================================="
echo "   CONFIGURAÇÃO DA VM 1 (COORDENADORA / BOOTNODE)                "
echo "================================================================="
echo "IP do Bootnode informado: ${BOOTNODE_IP}"
echo ""

"${REDE_DIR}/deploy/setup-coordinator.sh" --bootnode-ip "${BOOTNODE_IP}"

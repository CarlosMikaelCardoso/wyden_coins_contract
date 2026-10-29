#!/usr/bin/env bash
# ==============================================================================
# setup-coordinator.sh
# Inicializa a Máquina Coordenadora: Gera a rede, empacota os nós e inicia o Nó 1.
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
  echo "🔍 Nenhum IP foi passado. Detectando IP da interface de rede principal..."
  BOOTNODE_IP=$(ip -o route get to 8.8.8.8 2>/dev/null | awk '{print $7}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
fi

echo "================================================================="
echo "   SETUP DA MÁQUINA COORDENADORA (BOOTNODE + VALIDADOR 1)        "
echo "================================================================="
echo "IP do Bootnode: ${BOOTNODE_IP}"
echo "-----------------------------------------------------------------"

# 1. Gerar rede
"${REDE_DIR}/core/01-generate-network.sh" --bootnode-ip "${BOOTNODE_IP}"

# 2. Empacotar nós
"${REDE_DIR}/core/02-package-nodes.sh"

# 3. Iniciar o Nó 1
echo ""
echo "🚀 [Iniciando Nó 1 na Máquina Coordenadora]..."
cd "${REDE_DIR}/dist/node1"
./run.sh

# Aguarda 5 segundos para o container subir
sleep 5
./check.sh

echo ""
echo "================================================================="
echo "🎉 Máquina 1 (Coordenadora) inicializada com sucesso!"
echo "Os pacotes para as outras máquinas estão disponíveis em:"
echo "   ${REDE_DIR}/dist/"
echo ""
echo "Exemplo de envio para as demais VMs (4 VMs):"
echo "   scp ${REDE_DIR}/dist/node2.tar.gz <usuario>@<node2-ip>:~/"
echo "   scp ${REDE_DIR}/dist/node3.tar.gz <usuario>@<node3-ip>:~/"
echo "   scp ${REDE_DIR}/dist/rpc-node.tar.gz <usuario>@<rpc-ip>:~/"
echo "================================================================="

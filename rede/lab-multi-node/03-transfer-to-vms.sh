#!/usr/bin/env bash
# ==============================================================================
# 03-transfer-to-vms.sh (lab-multi-node)
# Executado na VM 1: Transfere os pacotes dos nós para as VMs 2, 3 e 4 via SCP.
# Uso:
#   ./03-transfer-to-vms.sh --node2-ip <node2-ip> --node3-ip <node3-ip> --rpc-ip <rpc-ip> --user <usuario>
# Ou interativamente:
#   ./03-transfer-to-vms.sh
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"

NODE2_IP=""
NODE3_IP=""
RPC_IP=""
SSH_USER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node2-ip) NODE2_IP="$2"; shift 2 ;;
    --node3-ip) NODE3_IP="$2"; shift 2 ;;
    --rpc-ip)   RPC_IP="$2"; shift 2 ;;
    -u|--user)  SSH_USER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "${SSH_USER}" ]]; then
  echo -n "Nome de usuário SSH [<usuario>]: "
  read -r SSH_USER || true
  SSH_USER="${SSH_USER:-$USER}"
fi

if [[ -z "${NODE2_IP}" ]]; then
  echo -n "IP da VM 2 (Validador 2) [<node2-ip>]: "
  read -r NODE2_IP || true
fi

if [[ -z "${NODE3_IP}" ]]; then
  echo -n "IP da VM 3 (Validador 3) [<node3-ip>]: "
  read -r NODE3_IP || true
fi

if [[ -z "${RPC_IP}" ]]; then
  echo -n "IP da VM 4 (Gateway RPC) [<rpc-ip>]: "
  read -r RPC_IP || true
fi

echo "================================================================="
echo "   TRANSFERINDO PACOTES PARA AS VMS REMOTAS                     "
echo "================================================================="

if [[ -n "${NODE2_IP}" ]]; then
  echo "📤 [1/3] Enviando node2.tar.gz para VM 2 (${SSH_USER}@${NODE2_IP})..."
  scp "${REDE_DIR}/dist/node2.tar.gz" "${REDE_DIR}/deploy/setup-validator.sh" "${SSH_USER}@${NODE2_IP}:~/"
fi

if [[ -n "${NODE3_IP}" ]]; then
  echo "📤 [2/3] Enviando node3.tar.gz para VM 3 (${SSH_USER}@${NODE3_IP})..."
  scp "${REDE_DIR}/dist/node3.tar.gz" "${REDE_DIR}/deploy/setup-validator.sh" "${SSH_USER}@${NODE3_IP}:~/"
fi

if [[ -n "${RPC_IP}" ]]; then
  echo "📤 [3/3] Enviando rpc-node.tar.gz para VM 4 (${SSH_USER}@${RPC_IP})..."
  scp "${REDE_DIR}/dist/rpc-node.tar.gz" "${REDE_DIR}/deploy/setup-rpc.sh" "${SSH_USER}@${RPC_IP}:~/"
fi

echo ""
echo "✓ Transferência concluída com sucesso!"
echo "Próximos passos nas máquinas de destino:"
echo "  - Na VM 2: ssh ${SSH_USER}@${NODE2_IP} 'tar -xzf node2.tar.gz && cd node2 && ./run.sh'"
echo "  - Na VM 3: ssh ${SSH_USER}@${NODE3_IP} 'tar -xzf node3.tar.gz && cd node3 && ./run.sh'"
echo "  - Na VM 4: ssh ${SSH_USER}@${RPC_IP}   'tar -xzf rpc-node.tar.gz && cd rpc-node && ./run.sh'"

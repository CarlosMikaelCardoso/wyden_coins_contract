#!/usr/bin/env bash
# ==============================================================================
# 01-generate-network.sh
# Gera a gênese QBFT, pares de chaves dos nós e arquivo de permissões da rede.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"
CONFIGS_DIR="${REDE_DIR}/configs"
BUILD_DIR="${REDE_DIR}/build"

BOOTNODE_IP=""
P2P_PORT="30303"

function show_help() {
  cat <<EOF
Uso: $(basename "${0}") [OPÇÕES]

Opções:
  -b, --bootnode-ip <IP>     (Obrigatório) Endereço IP acessível do Nó 1 (Bootnode).
  -p, --port <PORTA>         (Opcional) Porta P2P do Bootnode (default: 30303).
  -h, --help                 Exibe esta mensagem de ajuda.

Exemplo:
  $(basename "${0}") --bootnode-ip <ip-bootnode>
EOF
}

# Parse argumentos
while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--bootnode-ip)
      BOOTNODE_IP="$2"
      shift 2
      ;;
    -p|--port)
      P2P_PORT="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      if [[ -z "${BOOTNODE_IP}" ]]; then
        BOOTNODE_IP="$1"
        shift
      else
        echo "Opção desconhecida: $1"
        show_help
        exit 1
      fi
      ;;
  esac
done

if [[ -z "${BOOTNODE_IP}" ]]; then
  echo "⚠️  [AVISO] Nenhum IP de Bootnode foi fornecido. Tentando detectar o IP local..."
  BOOTNODE_IP=$(ip -o route get to 8.8.8.8 2>/dev/null | awk '{print $7}' || hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")
  echo "👉 IP detectado: ${BOOTNODE_IP}"
fi

echo "================================================================="
echo "   GERAÇÃO DA REDE HYPERLEDGER BESU (QBFT - MULTI-NODE)          "
echo "================================================================="
echo "Bootnode IP : ${BOOTNODE_IP}"
echo "Porta P2P   : ${P2P_PORT}"
echo "Gênese      : ${CONFIGS_DIR}/genesis_QBFT.json"
echo "Diretório   : ${BUILD_DIR}"
echo "-----------------------------------------------------------------"

# Limpar builds antigos
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Copia template do genesis para o build dir
cp "${CONFIGS_DIR}/genesis_QBFT.json" "${BUILD_DIR}/genesis_QBFT.json"

echo "⚙️  [1/4] Gerando chaves criptográficas e genesis.json via Besu Docker..."
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v "${BUILD_DIR}:/data" \
  hyperledger/besu:25.5.0 \
  operator generate-blockchain-config \
  --config-file=/data/genesis_QBFT.json \
  --to=/data/networkFiles \
  --private-key-file-name=key

cp "${BUILD_DIR}/networkFiles/genesis.json" "${BUILD_DIR}/genesis.json"

echo "🔑 [2/4] Identificando chaves geradas e calculando Enodes..."
KEYS_DIR="${BUILD_DIR}/networkFiles/keys"
node_index=1
nodes_allowlist=()
accounts_allowlist=()
bootnode_enode=""

# Ordena as pastas de chaves (0x...)
for key_folder in $(ls -d "${KEYS_DIR}"/0x* | sort); do
  account_id="$(basename "${key_folder}")"
  pub_key=$(cat "${key_folder}/key.pub" | sed 's/^0x//')
  
  # Cria pasta organizada para o nó
  NODE_DATA_DIR="${BUILD_DIR}/nodes/node${node_index}/data"
  mkdir -p "${NODE_DATA_DIR}"
  cp "${key_folder}/key" "${NODE_DATA_DIR}/key"
  cp "${key_folder}/key.pub" "${NODE_DATA_DIR}/key.pub"
  echo "${account_id}" > "${BUILD_DIR}/nodes/node${node_index}/address.txt"

  # O nó 1 é o Bootnode de referência
  if [[ ${node_index} -eq 1 ]]; then
    bootnode_enode="enode://${pub_key}@${BOOTNODE_IP}:${P2P_PORT}"
    echo "${bootnode_enode}" > "${BUILD_DIR}/bootnode.enode"
    nodes_allowlist+=("\"${bootnode_enode}\"")
  fi

  accounts_allowlist+=("\"${account_id}\"")
  echo "   ↳ Node ${node_index}: ${account_id}"
  node_index=$((node_index + 1))
done

echo "📝 [3/4] Gerando arquivo permissions_config.toml..."
cat <<EOF > "${BUILD_DIR}/permissions_config.toml"
# Allowlist de nós da rede
nodes-allowlist=[
  $(IFS=,; echo "${nodes_allowlist[*]}")
]

# Allowlist de contas autorizadas (Deployer + Validadores)
accounts-allowlist=[
  "0xfe3b557e8fb62b89f4916b721be55ceb828dbd73",
  $(IFS=,; echo "${accounts_allowlist[*]}")
]
EOF

echo "✅ [4/4] Gênese gerada com sucesso!"
echo "-----------------------------------------------------------------"
echo "Bootnode Enode: $(cat "${BUILD_DIR}/bootnode.enode")"
echo "Genesis Path  : ${BUILD_DIR}/genesis.json"
echo "Próximo passo : Executar ./core/02-package-nodes.sh para empacotar os nós."
echo "================================================================="

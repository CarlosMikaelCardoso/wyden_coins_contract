#!/usr/bin/env bash
# ==============================================================================
# 02-package-nodes.sh
# Empacota os arquivos de configuração para cada máquina individual (estilo Ilíada).
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
REDE_DIR="$(cd "${SCRIPT_DIR}/.." &>/dev/null && pwd -P)"
BUILD_DIR="${REDE_DIR}/build"
DIST_DIR="${REDE_DIR}/dist"
DOCKER_COMPOSE_TEMPLATE="${REDE_DIR}/docker/docker-compose.node.yaml"

if [[ ! -f "${BUILD_DIR}/genesis.json" || ! -f "${BUILD_DIR}/bootnode.enode" ]]; then
  echo "❌ [ERRO] Arquivos de rede não encontrados em ${BUILD_DIR}."
  echo "Execute primeiro: ./core/01-generate-network.sh"
  exit 1
fi

BOOTNODE_ENODE=$(cat "${BUILD_DIR}/bootnode.enode")
BOOTNODE_IP=$(echo "${BOOTNODE_ENODE}" | sed -n 's/.*@\([^:]*\):.*/\1/p')

SINGLE_MACHINE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --single-machine|--local|-l)
      SINGLE_MACHINE=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

echo "================================================================="
echo "   EMPACOTAMENTO DOS NÓS HYPERLEDGER BESU PARA MULTI-MÁQUINAS   "
echo "================================================================="
echo "Bootnode Enode : ${BOOTNODE_ENODE}"
echo "Modo           : $( [[ "${SINGLE_MACHINE}" == "true" ]] && echo "Single Machine (Validação Local com Portas Incrementais)" || echo "Multi-VMs (Portas Padrão 30303/8545 por Máquina)" )"
echo "Destino        : ${DIST_DIR}"
echo "-----------------------------------------------------------------"

rm -rf "${DIST_DIR}"
mkdir -p "${DIST_DIR}"

# Função auxiliar para criar scripts locais de run, stop e check em cada pacote
function write_helper_scripts() {
  local target_dir="${1}"
  local node_label="${2}"
  local rpc_port="${3:-}"

  # run.sh
  cat <<'EOF' > "${target_dir}/run.sh"
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "🚀 Iniciando nó Besu..."
# Garante permissões adequadas no diretório data para o usuário do Besu (uid 1000)
mkdir -p data
docker compose -f docker-compose.yaml up -d
echo "✓ Nó iniciado em segundo plano com sucesso!"
echo "Para verificar os logs: docker compose logs -f"
echo "Para verificar o status: ./check.sh"
EOF
  chmod +x "${target_dir}/run.sh"

  # stop.sh
  cat <<'EOF' > "${target_dir}/stop.sh"
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
echo "🛑 Parando nó Besu..."
docker compose -f docker-compose.yaml down
echo "✓ Nó parado com sucesso."
EOF
  chmod +x "${target_dir}/stop.sh"

  # check.sh
  cat <<EOF > "${target_dir}/check.sh"
#!/usr/bin/env bash
cd "\$(dirname "\$0")"

RPC_PORT="${rpc_port:-8545}"
RPC_URL="http://127.0.0.1:\${RPC_PORT}"

echo "======================================================"
echo "   DIAGNÓSTICO DO NÓ: ${node_label}                   "
echo "======================================================"

if ! docker ps | grep -q "\$(grep 'NODE_NAME=' .env | cut -d= -f2)"; then
  echo "❌ O contêiner do nó não está em execução."
  exit 1
fi

echo "📦 Contêiner em execução:"
docker ps --filter "name=\$(grep 'NODE_NAME=' .env | cut -d= -f2)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🌐 Verificando interface JSON-RPC (\${RPC_URL})..."
PEERS=\$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' -H "Content-Type: application/json" "\${RPC_URL}" 2>/dev/null | jq -r .result 2>/dev/null || echo "")

if [[ -n "\${PEERS}" && "\${PEERS}" != "null" ]]; then
  DECIMAL_PEERS=\$(( \${PEERS} ))
  BLOCK=\$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' -H "Content-Type: application/json" "\${RPC_URL}" | jq -r .result)
  DECIMAL_BLOCK=\$(( \${BLOCK} ))
  SYNCING=\$(curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' -H "Content-Type: application/json" "\${RPC_URL}" | jq -r .result)

  echo "   [✓] Peers conectados : \${DECIMAL_PEERS}"
  echo "   [✓] Bloco atual      : \${DECIMAL_BLOCK} (\${BLOCK})"
  echo "   [✓] Sincronização    : \${SYNCING}"
else
  echo "   [ℹ] RPC não habilitado localmente neste nó (ou porta \${RPC_PORT} inacessível)."
  echo "   [i] Consultando logs recentes do P2P:"
  docker compose logs --tail=10
fi
echo "======================================================"
EOF
  chmod +x "${target_dir}/check.sh"
}

# 1. Empacotar Validadores
VALIDATOR_COUNT=$(ls -d "${BUILD_DIR}/nodes/node"* 2>/dev/null | wc -l)
echo "Identificados ${VALIDATOR_COUNT} nós validadores para empacotamento."

for i in $(seq 1 "${VALIDATOR_COUNT}"); do
  NODE_NAME="node${i}"
  NODE_PKG_DIR="${DIST_DIR}/${NODE_NAME}"
  mkdir -p "${NODE_PKG_DIR}/data"

  # Determinar portas com base no modo de implantação
  if [[ "${SINGLE_MACHINE}" == "true" ]]; then
    CURRENT_P2P_PORT=$(( 30303 + i - 1 )) # 30303, 30304, 30305
    CURRENT_RPC_PORT=$(( 8540 + i ))       # 8541, 8542, 8543
  else
    CURRENT_P2P_PORT=30303
    CURRENT_RPC_PORT=8545
  fi

  # Copiar arquivos comuns
  cp "${BUILD_DIR}/genesis.json" "${NODE_PKG_DIR}/genesis.json"
  cp "${BUILD_DIR}/permissions_config.toml" "${NODE_PKG_DIR}/permissions_config.toml"
  cp "${DOCKER_COMPOSE_TEMPLATE}" "${NODE_PKG_DIR}/docker-compose.yaml"

  # Copiar chaves privadas específicas do nó
  cp "${BUILD_DIR}/nodes/${NODE_NAME}/data/key" "${NODE_PKG_DIR}/data/key"
  cp "${BUILD_DIR}/nodes/${NODE_NAME}/data/key.pub" "${NODE_PKG_DIR}/data/key.pub"

  # Definir argumentos de inicialização
  if [[ ${i} -eq 1 ]]; then
    # Node 1 é o Bootnode (não precisa de --bootnodes)
    cat <<EOF > "${NODE_PKG_DIR}/.env"
NODE_NAME=besu-${NODE_NAME}
BESU_IMAGE=hyperledger/besu:24.7.0
BESU_LOGGING=INFO
P2P_PORT=${CURRENT_P2P_PORT}
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=${CURRENT_P2P_PORT} --p2p-host=${BOOTNODE_IP} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=127.0.0.1 --rpc-http-port=${CURRENT_RPC_PORT} --rpc-http-api=ETH,NET,WEB3,QBFT
EOF
    write_helper_scripts "${NODE_PKG_DIR}" "Validador 1 (Bootnode)" "${CURRENT_RPC_PORT}"
  else
    # Demais nós conectam ao Bootnode
    cat <<EOF > "${NODE_PKG_DIR}/.env"
NODE_NAME=besu-${NODE_NAME}
BESU_IMAGE=hyperledger/besu:24.7.0
BESU_LOGGING=INFO
P2P_PORT=${CURRENT_P2P_PORT}
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=${CURRENT_P2P_PORT} --bootnodes=${BOOTNODE_ENODE} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=127.0.0.1 --rpc-http-port=${CURRENT_RPC_PORT} --rpc-http-api=ETH,NET,WEB3,QBFT
EOF
    write_helper_scripts "${NODE_PKG_DIR}" "Validador ${i}" "${CURRENT_RPC_PORT}"
    
    # Criar tar.gz para envio fácil
    tar -czf "${DIST_DIR}/${NODE_NAME}.tar.gz" -C "${DIST_DIR}" "${NODE_NAME}"
  fi

  echo "📦 Criado pacote para: ${NODE_NAME} (P2P: ${CURRENT_P2P_PORT}, RPC: ${CURRENT_RPC_PORT})"
done

# 2. Empacotar Nó RPC / Gateway (Sem chaves de validador, apenas sincroniza e expõe APIs)
RPC_PKG_DIR="${DIST_DIR}/rpc-node"
mkdir -p "${RPC_PKG_DIR}/data"

if [[ "${SINGLE_MACHINE}" == "true" ]]; then
  RPC_P2P_PORT=30306
  RPC_HTTP_PORT=8545 # Porta RPC principal para aplicações e testes de carga
  RPC_WS_PORT=8645
  RPC_METRICS_PORT=9545
else
  RPC_P2P_PORT=30303
  RPC_HTTP_PORT=8545
  RPC_WS_PORT=8645
  RPC_METRICS_PORT=9545
fi

cp "${BUILD_DIR}/genesis.json" "${RPC_PKG_DIR}/genesis.json"
cp "${BUILD_DIR}/permissions_config.toml" "${RPC_PKG_DIR}/permissions_config.toml"
cp "${DOCKER_COMPOSE_TEMPLATE}" "${RPC_PKG_DIR}/docker-compose.yaml"

cat <<EOF > "${RPC_PKG_DIR}/.env"
NODE_NAME=besu-rpcnode
BESU_IMAGE=hyperledger/besu:24.7.0
BESU_LOGGING=INFO
P2P_PORT=${RPC_P2P_PORT}
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=${RPC_P2P_PORT} --bootnodes=${BOOTNODE_ENODE} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=0.0.0.0 --rpc-http-port=${RPC_HTTP_PORT} --rpc-http-api=ETH,NET,WEB3,QBFT,DEBUG,TXPOOL --rpc-http-cors-origins="*" --rpc-ws-enabled=true --rpc-ws-host=0.0.0.0 --rpc-ws-port=${RPC_WS_PORT} --rpc-ws-api=ETH,NET,WEB3,QBFT --metrics-enabled=true --metrics-port=${RPC_METRICS_PORT}
EOF

write_helper_scripts "${RPC_PKG_DIR}" "Nó RPC / Gateway" "${RPC_HTTP_PORT}"
tar -czf "${DIST_DIR}/rpc-node.tar.gz" -C "${DIST_DIR}" "rpc-node"
echo "📦 Criado pacote para: rpc-node (P2P: ${RPC_P2P_PORT}, RPC: ${RPC_HTTP_PORT})"

# 3. Gerar README de instruções de distribuição
cat <<EOF > "${DIST_DIR}/README.md"
# Pacotes de Distribuição da Rede Besu (4 VMs)

Os pacotes prontos para cada máquina foram gerados em: \`${DIST_DIR}\`.

### 1. VM 1 (Coordenadora / Bootnode + Validador 1)
* Já está configurada na pasta local: \`dist/node1\`
* Para iniciar:
  \`\`\`bash
  cd dist/node1 && ./run.sh
  \`\`\`

### 2. VM 2 e VM 3 (Validadores QBFT)
* Copie o arquivo tar correspondente para a máquina de destino:
  \`\`\`bash
  scp dist/node2.tar.gz <usuario>@<node2-ip>:~/
  scp dist/node3.tar.gz <usuario>@<node3-ip>:~/
  \`\`\`
* Na máquina de destino:
  \`\`\`bash
  tar -xzf node2.tar.gz && cd node2 && ./run.sh
  tar -xzf node3.tar.gz && cd node3 && ./run.sh
  \`\`\`

### 3. VM 4 (Nó RPC / Gateway de Consultas e Aplicações)
* Copie o pacote RPC:
  \`\`\`bash
  scp dist/rpc-node.tar.gz <usuario>@<rpc-ip>:~/
  \`\`\`
* Na máquina de destino:
  \`\`\`bash
  tar -xzf rpc-node.tar.gz && cd rpc-node && ./run.sh
  \`\`\`
* As portas HTTP 8545 e WS 8645 estarão abertas para transações e consultas.
EOF

echo "-----------------------------------------------------------------"
echo "✅ Todos os pacotes gerados em ${DIST_DIR}:"
ls -lh "${DIST_DIR}"/*.tar.gz 2>/dev/null || true
echo "================================================================="

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

echo "================================================================="
echo "   EMPACOTAMENTO DOS NÓS HYPERLEDGER BESU PARA MULTI-MÁQUINAS   "
echo "================================================================="
echo "Bootnode Enode : ${BOOTNODE_ENODE}"
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

# 1. Empacotar Validadores 1 a 4
for i in {1..4}; do
  NODE_NAME="node${i}"
  NODE_PKG_DIR="${DIST_DIR}/${NODE_NAME}"
  mkdir -p "${NODE_PKG_DIR}/data"

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
P2P_PORT=30303
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=30303 --p2p-host=${BOOTNODE_IP} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=127.0.0.1 --rpc-http-port=8545 --rpc-http-api=ETH,NET,WEB3,QBFT
EOF
    write_helper_scripts "${NODE_PKG_DIR}" "Validador 1 (Bootnode)" "8545"
  else
    # Nodes 2, 3 e 4 conectam ao Bootnode
    cat <<EOF > "${NODE_PKG_DIR}/.env"
NODE_NAME=besu-${NODE_NAME}
BESU_IMAGE=hyperledger/besu:24.7.0
BESU_LOGGING=INFO
P2P_PORT=30303
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=30303 --bootnodes=${BOOTNODE_ENODE} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=127.0.0.1 --rpc-http-port=8545 --rpc-http-api=ETH,NET,WEB3,QBFT
EOF
    write_helper_scripts "${NODE_PKG_DIR}" "Validador ${i}" "8545"
    
    # Criar tar.gz para envio fácil
    tar -czf "${DIST_DIR}/${NODE_NAME}.tar.gz" -C "${DIST_DIR}" "${NODE_NAME}"
  fi

  echo "📦 Criado pacote para: ${NODE_NAME}"
done

# 2. Empacotar Nó RPC / Gateway (Sem chaves de validador, apenas sincroniza e expõe APIs)
RPC_PKG_DIR="${DIST_DIR}/rpc-node"
mkdir -p "${RPC_PKG_DIR}/data"

cp "${BUILD_DIR}/genesis.json" "${RPC_PKG_DIR}/genesis.json"
cp "${BUILD_DIR}/permissions_config.toml" "${RPC_PKG_DIR}/permissions_config.toml"
cp "${DOCKER_COMPOSE_TEMPLATE}" "${RPC_PKG_DIR}/docker-compose.yaml"

cat <<EOF > "${RPC_PKG_DIR}/.env"
NODE_NAME=besu-rpcnode
BESU_IMAGE=hyperledger/besu:24.7.0
BESU_LOGGING=INFO
P2P_PORT=30303
BESU_ARGS=--data-path=/opt/besu/data --genesis-file=/opt/besu/genesis.json --p2p-port=30303 --bootnodes=${BOOTNODE_ENODE} --min-gas-price=0 --data-storage-format=BONSAI --profile=ENTERPRISE --permissions-accounts-config-file=/opt/besu/permissions_config.toml --permissions-accounts-config-file-enabled=true --rpc-http-enabled=true --rpc-http-host=0.0.0.0 --rpc-http-port=8545 --rpc-http-api=ETH,NET,WEB3,QBFT,DEBUG,TXPOOL --rpc-http-cors-origins="*" --rpc-ws-enabled=true --rpc-ws-host=0.0.0.0 --rpc-ws-port=8645 --rpc-ws-api=ETH,NET,WEB3,QBFT --metrics-enabled=true --metrics-port=9545
EOF

write_helper_scripts "${RPC_PKG_DIR}" "Nó RPC / Gateway" "8545"
tar -czf "${DIST_DIR}/rpc-node.tar.gz" -C "${DIST_DIR}" "rpc-node"
echo "📦 Criado pacote para: rpc-node"

# 3. Gerar README de instruções de distribuição
cat <<EOF > "${DIST_DIR}/README.md"
# Pacotes de Distribuição da Rede Besu

Os pacotes prontos para cada máquina foram gerados em: \`${DIST_DIR}\`.

### 1. Máquina 1 (Coordenadora / Bootnode)
* Já está configurada na pasta local: \`dist/node1\`
* Para iniciar:
  \`\`\`bash
  cd dist/node1 && ./run.sh
  \`\`\`

### 2. Máquinas 2, 3 e 4 (Validadores)
* Copie o arquivo tar correspondente para a máquina de destino:
  \`\`\`bash
  scp dist/node2.tar.gz usuario@IP_VM2:~/
  scp dist/node3.tar.gz usuario@IP_VM3:~/
  scp dist/node4.tar.gz usuario@IP_VM4:~/
  \`\`\`
* Na máquina de destino:
  \`\`\`bash
  tar -xzf node2.tar.gz && cd node2 && ./run.sh
  \`\`\`

### 3. Máquina 5 (Nó RPC / Backend / Caliper)
* Copie o pacote RPC:
  \`\`\`bash
  scp dist/rpc-node.tar.gz usuario@IP_RPC:~/
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

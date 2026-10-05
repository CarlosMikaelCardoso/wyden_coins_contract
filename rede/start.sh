#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# --- Funções Auxiliares ---
die() {
    echo "[ERRO] $*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Comando obrigatório não encontrado: $1"
}

# --- Variáveis de Configuração ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}"

BESU_VERSION="24.7.0"
JAVA_VERSION="jdk-21.0.7"
JAVA_TAR_GZ="${JAVA_VERSION}_linux-x64_bin.tar.gz"
BESU_TAR_GZ="besu-${BESU_VERSION}.tar.gz"
EXTERNAL_DEPLOY_ACCOUNT="0xfe3b557e8fb62b89f4916b721be55ceb828dbd73"

cleanup() {
    echo "--- Limpando arquivos e contêineres de uma execução anterior ---"
    if [[ -f "${BASE_DIR}/docker-compose.yaml" ]]; then
        docker compose -f "${BASE_DIR}/docker-compose.yaml" down --volumes --remove-orphans || true
    fi
    docker rm -f node1 node2 node3 node4 node5 node6 rpcnode 2>/dev/null || true
    docker run --rm -v "${BASE_DIR}:/data" alpine sh -c "rm -rf /data/besu-* /data/${JAVA_VERSION} /data/networkFiles /data/Permissioned-Network /data/genesis.json"
    echo "Limpeza concluída."
}

install_dependencies() {
    echo "--- Instalando Dependências: Hyperledger Besu ---"
    require_command docker
    docker compose version >/dev/null 2>&1 || die "Docker Compose v2 é obrigatório"
    
    if [ ! -d "${BASE_DIR}/besu-${BESU_VERSION}" ]; then
        wget "https://github.com/hyperledger/besu/releases/download/${BESU_VERSION}/${BESU_TAR_GZ}"
        tar -xvf "${BESU_TAR_GZ}"
        rm "${BESU_TAR_GZ}"
    fi
    export PATH="${BASE_DIR}/besu-${BESU_VERSION}/bin:$PATH"

    echo "--- Instalando Dependências: JAVA ---"
    if [ ! -d "${BASE_DIR}/${JAVA_VERSION}" ]; then
        wget "https://download.oracle.com/java/21/archive/${JAVA_TAR_GZ}"
        tar -xvf "${JAVA_TAR_GZ}"
        rm "${JAVA_TAR_GZ}"
    fi
    export JAVA_HOME="${BASE_DIR}/${JAVA_VERSION}"
}

generate_keys_and_configs() {
    echo "--- Etapa 1: Geração de Chaves e Ficheiros de Configuração ---"
    chmod +x generate-nodes-config.sh

    besu operator generate-blockchain-config \
        --config-file=genesis_QBFT.json \
        --to=networkFiles \
        --private-key-file-name=key

    cp networkFiles/genesis.json ./
    ./generate-nodes-config.sh

    PERMISSIONS_CONFIG_PATH="${BASE_DIR}/Permissioned-Network/permissions_config.toml"
    if [ -f "$PERMISSIONS_CONFIG_PATH" ]; then
        sed -i "s/\(accounts-allowlist=\[[^]]*\)\]/\1, \"$EXTERNAL_DEPLOY_ACCOUNT\"]/" "$PERMISSIONS_CONFIG_PATH"
        for i in $(seq 1 6); do
            cp "$PERMISSIONS_CONFIG_PATH" "${BASE_DIR}/Permissioned-Network/Node-$i/data/"
        done
    else
        die "Erro: permissions_config.toml não encontrado em ${PERMISSIONS_CONFIG_PATH}."
    fi
}

execute_network() {
    echo "--- Etapa 2: Execução da Rede ---"
    docker build --no-cache -f Dockerfile -t besu-image-local:1.0 .
    
    echo "Iniciando a rede temporariamente..."
    docker compose up -d
    sleep 30

    python3 update_docker_compose.py
    docker compose down

    echo "Inicializando a rede Besu corretamente com bootnodes..."
    docker compose up -d
    sleep 30
    echo "Rede Besu inicializada com sucesso."
}

validate_network() {
    echo "--- Etapa 3: Validação do Estado da Rede ---"
    curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://127.0.0.1:8545 || true
    echo ""
}

main() {
    cd "${BASE_DIR}"
    cleanup
    install_dependencies
    generate_keys_and_configs
    execute_network
    validate_network

    echo "----------------------------------------------------------------------"
    echo "Rede Besu Local inicializada (RPC: http://127.0.0.1:8545)"
    echo "----------------------------------------------------------------------"
}

main "$@"

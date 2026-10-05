#!/usr/bin/env bash
set -o errexit
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}"

echo "--- Derrubando a Rede Besu ---"
if [[ -f "${BASE_DIR}/docker-compose.yaml" ]]; then
    cd "${BASE_DIR}"
    docker compose down --volumes --remove-orphans || true
fi

echo "--- Forçando remoção de contêineres órfãos por nome ---"
docker rm -f node1 node2 node3 node4 node5 node6 rpcnode 2>/dev/null || true

echo "--- Limpando arquivos de configuração gerados ---"
docker run --rm -v "${BASE_DIR}:/data" alpine sh -c "rm -rf /data/networkFiles /data/Permissioned-Network /data/genesis.json"

read -p "Deseja também apagar os binários baixados do Besu e do Java (y/n)? " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Limpando binários..."
    docker run --rm -v "${BASE_DIR}:/data" alpine sh -c "rm -rf /data/besu-* /data/jdk-*"
fi

echo "Ambiente limpo com sucesso!"

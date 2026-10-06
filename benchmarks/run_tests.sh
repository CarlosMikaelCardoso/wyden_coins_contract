#!/usr/bin/env bash
set -e

echo "=== 1. Lendo endereços do deploy ==="
WC_ADDRESS=$(cat ~/facicoin/contratos/addresses.json | jq -r .WydenCoin)
RM_ADDRESS=$(cat ~/facicoin/contratos/addresses.json | jq -r .RedemptionManager)

echo "WydenCoin: $WC_ADDRESS"
echo "RedemptionManager: $RM_ADDRESS"

echo "=== 2. Atualizando networkconfig.json do Caliper ==="
cd ~/facicoin/benchmarks
jq --arg wc "$WC_ADDRESS" --arg rm "$RM_ADDRESS" \
   '.ethereum.contracts.wydenCoin.address = $wc | .ethereum.contracts.redemptionManager.address = $rm' \
   caliper_besu/networkconfig.json > tmp.json && mv tmp.json caliper_besu/networkconfig.json

echo "=== 3. Instalando dependências do Caliper ==="
npm install

echo "=== 4. Rodando Teste 1: Mint Reward (open.yaml) ==="
npm run test:open

echo "=== 5. Rodando Teste 2: Resgatar (query.yaml) ==="
npm run test:query

echo "=== Testes finalizados com sucesso! ==="

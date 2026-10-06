#!/usr/bin/env bash
set -e

echo "=== 1. Lendo endereços do deploy ==="
WC_ADDRESS=$(cat ~/facicoin/contratos/addresses.json | jq -r .WydenCoin)
RM_ADDRESS=$(cat ~/facicoin/contratos/addresses.json | jq -r .RedemptionManager)

echo "WydenCoin: $WC_ADDRESS"
echo "RedemptionManager: $RM_ADDRESS"

echo "=== 2. Atualizando networkconfig.json do Caliper ==="
jq --arg wc "$WC_ADDRESS" --arg rm "$RM_ADDRESS" \
   '.ethereum.contracts.wydenCoin.address = $wc | .ethereum.contracts.wydenCoin.gas = {"mintReward": 3000000, "approve": 3000000} | .ethereum.contracts.redemptionManager.address = $rm | .ethereum.contracts.redemptionManager.gas = {"resgatar": 3000000, "confirmarUso": 3000000, "cancelar": 3000000, "expirar": 3000000}' \
   caliper_besu/networkconfig.json > tmp.json && mv tmp.json caliper_besu/networkconfig.json

# Atualiza endereço do RM no resgatar.js (fallback)
sed -i "s/0x[a-fA-F0-9]\{40\}/$RM_ADDRESS/g" caliper_besu/resgatar.js

echo "=== 3. Instalando dependências do Caliper ==="
npm install

echo "=== 3.5. Dando permissões, saldo e criando resgates iniciais ==="
cd ~/facicoin/contratos
node setup_test_data.js
cd ~/facicoin/benchmarks

echo "=== 4. Rodando Teste 1: Mint Reward (open.yaml) ==="
> caliper_execution.log
npm run test:open | tee -a caliper_execution.log &
PID_OPEN=$!
while kill -0 $PID_OPEN 2>/dev/null; do
  if grep -q "Benchmark successfully finished" caliper_execution.log; then
    sleep 2
    killall -9 node || true
    break
  fi
  sleep 2
done

echo "=== 5. Rodando Teste 2: Resgatar (query.yaml) ==="
> caliper_query_execution.log
npm run test:query | tee -a caliper_query_execution.log &
PID_QUERY=$!
while kill -0 $PID_QUERY 2>/dev/null; do
  if grep -q "Benchmark successfully finished" caliper_query_execution.log; then
    sleep 2
    killall -9 node || true
    break
  fi
  sleep 2
done
cat caliper_query_execution.log >> caliper_execution.log

echo "=== 6. Rodando Teste 3: Confirmar Uso ==="
> caliper_confirmar_execution.log
npm run test:confirmar | tee -a caliper_confirmar_execution.log &
PID_CONF=$!
while kill -0 $PID_CONF 2>/dev/null; do
  if grep -q "Benchmark successfully finished" caliper_confirmar_execution.log; then
    sleep 2
    killall -9 node || true
    break
  fi
  sleep 2
done
cat caliper_confirmar_execution.log >> caliper_execution.log

echo "=== 7. Rodando Teste 4: Cancelar ==="
> caliper_cancelar_execution.log
npm run test:cancelar | tee -a caliper_cancelar_execution.log &
PID_CANC=$!
while kill -0 $PID_CANC 2>/dev/null; do
  if grep -q "Benchmark successfully finished" caliper_cancelar_execution.log; then
    sleep 2
    killall -9 node || true
    break
  fi
  sleep 2
done
cat caliper_cancelar_execution.log >> caliper_execution.log

echo "=== 8. Rodando Teste 5: Expirar ==="
> caliper_expirar_execution.log
npm run test:expirar | tee -a caliper_expirar_execution.log &
PID_EXP=$!
while kill -0 $PID_EXP 2>/dev/null; do
  if grep -q "Benchmark successfully finished" caliper_expirar_execution.log; then
    sleep 2
    killall -9 node || true
    break
  fi
  sleep 2
done
cat caliper_expirar_execution.log >> caliper_execution.log

echo "=== Testes finalizados com sucesso! ==="

echo "=== 9. Gerando Relatório e Gráficos ==="
python3 gerar_relatorio.py caliper_execution.log

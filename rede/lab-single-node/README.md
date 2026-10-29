# Laboratório Hyperledger Besu QBFT: Instalação Manual em Máquina Única (lab-single-node)

> [!NOTE]
> Este guia ensina cada etapa do processo de criação, configuração e execução da rede Hyperledger Besu QBFT de forma **puramente manual**, utilizando Docker e comandos do sistema operacional, **sem o uso de scripts automáticos (`.sh`)**. O objetivo é conceder ao operador controle total e compreensão profunda sobre cada engrenagem da rede.

---

## 1. Visão Geral da Arquitetura Local

Este laboratório descreve a implantação e operação da rede completa (3 nós validadores QBFT e 1 nó gateway RPC) em um **único host** (computador local ou máquina virtual dedicada).

Para que 4 instâncias do Hyperledger Besu possam rodar simultaneamente no mesmo sistema operacional sem conflitos de rede, cada nó utiliza portas específicas na interface de loopback (`127.0.0.1`):

| Nó | Papel na Rede | Porta P2P | Porta JSON-RPC HTTP | Porta WebSockets |
| :--- | :--- | :--- | :--- | :--- |
| **`besu-node1`** | **Validador 1 / Bootnode** | `30303` | `8541` (Local) | - |
| **`besu-node2`** | **Validador 2** | `30304` | `8542` (Local) | - |
| **`besu-node3`** | **Validador 3** | `30305` | `8543` (Local) | - |
| **`besu-rpcnode`** | **Gateway RPC / Consultas** | `30306` | `8545` (Padrão para DApps) | `8645` |

> [!TIP]
> O nó `besu-rpcnode` expõe a porta padrão **8545**. Dessa forma, contratos inteligentes, carteiras (MetaMask), scripts Node.js e ferramentas de benchmark de carga podem se conectar diretamente ao endpoint `http://127.0.0.1:8545` sem necessidade de reconfiguração de portas.

---

## 2. Passo 1: Preparação da Estrutura de Diretórios

Crie a estrutura de diretórios onde os dados, chaves e arquivos de configuração de cada nó serão armazenados:

```bash
mkdir -p ~/besu-single-node/config
mkdir -p ~/besu-single-node/node1/data
mkdir -p ~/besu-single-node/node2/data
mkdir -p ~/besu-single-node/node3/data
mkdir -p ~/besu-single-node/rpcnode/data

cd ~/besu-single-node
```

---

## 3. Passo 2: Criação do Arquivo de Configuração do Consenso (`genesis_QBFT.json`)

Crie o arquivo `config/genesis_QBFT.json`. Ele define os parâmetros do algoritmo de consenso QBFT, tempo de bloco, Chain ID e as contas pré-financiadas:

```bash
cat <<'EOF' > config/genesis_QBFT.json
{
  "genesis": {
    "config": {
      "chainId": 381660001,
      "muirglacierblock": 0,
      "londonBlock": 0,
      "zeroBaseFee": true,
      "qbft": {
        "blockperiodseconds": 2,
        "epochlength": 30000,
        "requesttimeoutseconds": 4
      }
    },
    "nonce": "0x0",
    "timestamp": "0x58ee40ba",
    "gasLimit": "0x1fffffffffffff",
    "difficulty": "0x1",
    "mixHash": "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {
      "fe3b557e8fb62b89f4916b721be55ceb828dbd73": {
        "balance": "0xad78ebc5ac6200000"
      },
      "627306090abaB3A6e1400e9345bC60c78a8BEf57": {
        "balance": "90000000000000000000000"
      },
      "f17f52151EbEF6C7334FAD080c5704D77216b732": {
        "balance": "90000000000000000000000"
      }
    }
  },
  "blockchain": {
    "nodes": {
      "generate": true,
      "count": 3
    }
  }
}
EOF
```

**Explicação dos Parâmetros:**
* `chainId: 381660001`: Identificador exclusivo da rede privada WydenCoin para evitar ataques de replay.
* `blockperiodseconds: 2`: Produção de 1 bloco a cada 2 segundos.
* `zeroBaseFee: true`: Rede corporativa com taxa de gas zero (transações sem custo de mineração).
* `alloc`: Saldo inicial pré-financiado para a conta deployer (`0xfe3b...`).
* `nodes.count: 3`: O Besu gerará automaticamente os pares de chaves criptográficas para 3 validadores QBFT.

---

## 4. Passo 3: Geração Criptográfica via Contêiner Besu

Execute o gerador nativo do Besu através do contêiner Docker oficial descartável (`--rm`), mapeando a pasta `config/` como volume de trabalho:

```bash
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -v $(pwd)/config:/data \
  hyperledger/besu:24.7.0 \
  operator generate-blockchain-config \
  --config-file=/data/genesis_QBFT.json \
  --to=/data/networkFiles \
  --private-key-file-name=key
```

Após a execução, o Besu terá criado o diretório `config/networkFiles/` contendo:
* `genesis.json`: O bloco gênese definitivo com o cabeçalho QBFT populado (`extraData` com os endereços dos 3 validadores autorizados).
* `keys/0x.../key`: Chave privada de cada validador.
* `keys/0x.../key.pub`: Chave pública de cada validador.

---

## 5. Passo 4: Distribuição Manual das Chaves dos Nós

Identifique as pastas de chaves criadas pelo Besu:

```bash
ls -d config/networkFiles/keys/0x*
```

Copie as chaves de cada validador para a respectiva pasta de dados dos nós:

```bash
# Obtenha os caminhos das pastas de chaves em ordem
KEYS=($(ls -d config/networkFiles/keys/0x* | sort))

# Copia chave do Nó 1
cp "${KEYS[0]}/key" node1/data/key
cp "${KEYS[0]}/key.pub" node1/data/key.pub

# Copia chave do Nó 2
cp "${KEYS[1]}/key" node2/data/key
cp "${KEYS[1]}/key.pub" node2/data/key.pub

# Copia chave do Nó 3
cp "${KEYS[2]}/key" node3/data/key
cp "${KEYS[2]}/key.pub" node3/data/key.pub

# Copia o genesis.json para todos os nós
cp config/networkFiles/genesis.json node1/genesis.json
cp config/networkFiles/genesis.json node2/genesis.json
cp config/networkFiles/genesis.json node3/genesis.json
cp config/networkFiles/genesis.json rpcnode/genesis.json
```

---

## 6. Passo 5: Cálculo do Enode do Bootnode (Nó 1)

O Nó 1 atuará como ponto de ancoragem para descoberta P2P da rede. Obtenha a chave pública do Nó 1 e construa a URL Enode de conexão:

```bash
PUBKEY_NODE1=$(cat node1/data/key.pub | sed 's/^0x//')
BOOTNODE_ENODE="enode://${PUBKEY_NODE1}@127.0.0.1:30303"

echo "Bootnode Enode: ${BOOTNODE_ENODE}"
```

Guarde este valor; ele será passado como parâmetro `--bootnodes` para o Nó 2, Nó 3 e Nó RPC.

---

## 7. Passo 6: Criação do Arquivo de Permissões (`permissions_config.toml`)

Crie o arquivo de regras de permissões, autorizando a conta do deployer (`0xfe3b...`) e os endereços dos validadores a emitirem transações:

```bash
VAL1_ADDR=$(basename "${KEYS[0]}")
VAL2_ADDR=$(basename "${KEYS[1]}")
VAL3_ADDR=$(basename "${KEYS[2]}")

cat <<EOF > config/permissions_config.toml
# Lista de contas autorizadas a transacionar na rede
accounts-allowlist=[
  "0xfe3b557e8fb62b89f4916b721be55ceb828dbd73",
  "${VAL1_ADDR}",
  "${VAL2_ADDR}",
  "${VAL3_ADDR}"
]
EOF

# Distribui o arquivo para cada nó
cp config/permissions_config.toml node1/permissions_config.toml
cp config/permissions_config.toml node2/permissions_config.toml
cp config/permissions_config.toml node3/permissions_config.toml
cp config/permissions_config.toml rpcnode/permissions_config.toml
```

---

## 8. Passo 7: Inicialização Manual de Cada Nó via Docker

Agora iniciamos cada contêiner individualmente com `docker run`.

### 8.1. Iniciar Nó 1 (Validador 1 / Bootnode)
* Porta P2P: `30303` | RPC Local: `8541`

```bash
docker run -d \
  --name besu-node1 \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/node1/data:/opt/besu/data \
  -v $(pwd)/node1/genesis.json:/opt/besu/genesis.json \
  -v $(pwd)/node1/permissions_config.toml:/opt/besu/permissions_config.toml \
  hyperledger/besu:24.7.0 \
  --data-path=/opt/besu/data \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30303 \
  --p2p-host=127.0.0.1 \
  --min-gas-price=0 \
  --data-storage-format=BONSAI \
  --profile=ENTERPRISE \
  --permissions-accounts-config-file=/opt/besu/permissions_config.toml \
  --permissions-accounts-config-file-enabled=true \
  --rpc-http-enabled=true \
  --rpc-http-host=127.0.0.1 \
  --rpc-http-port=8541 \
  --rpc-http-api=ETH,NET,WEB3,QBFT
```

### 8.2. Iniciar Nó 2 (Validador 2)
* Porta P2P: `30304` | RPC Local: `8542` | Conecta ao Bootnode (`30303`)

```bash
docker run -d \
  --name besu-node2 \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/node2/data:/opt/besu/data \
  -v $(pwd)/node2/genesis.json:/opt/besu/genesis.json \
  -v $(pwd)/node2/permissions_config.toml:/opt/besu/permissions_config.toml \
  hyperledger/besu:24.7.0 \
  --data-path=/opt/besu/data \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30304 \
  --bootnodes=${BOOTNODE_ENODE} \
  --min-gas-price=0 \
  --data-storage-format=BONSAI \
  --profile=ENTERPRISE \
  --permissions-accounts-config-file=/opt/besu/permissions_config.toml \
  --permissions-accounts-config-file-enabled=true \
  --rpc-http-enabled=true \
  --rpc-http-host=127.0.0.1 \
  --rpc-http-port=8542 \
  --rpc-http-api=ETH,NET,WEB3,QBFT
```

### 8.3. Iniciar Nó 3 (Validador 3)
* Porta P2P: `30305` | RPC Local: `8543` | Conecta ao Bootnode (`30303`)

```bash
docker run -d \
  --name besu-node3 \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/node3/data:/opt/besu/data \
  -v $(pwd)/node3/genesis.json:/opt/besu/genesis.json \
  -v $(pwd)/node3/permissions_config.toml:/opt/besu/permissions_config.toml \
  hyperledger/besu:24.7.0 \
  --data-path=/opt/besu/data \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30305 \
  --bootnodes=${BOOTNODE_ENODE} \
  --min-gas-price=0 \
  --data-storage-format=BONSAI \
  --profile=ENTERPRISE \
  --permissions-accounts-config-file=/opt/besu/permissions_config.toml \
  --permissions-accounts-config-file-enabled=true \
  --rpc-http-enabled=true \
  --rpc-http-host=127.0.0.1 \
  --rpc-http-port=8543 \
  --rpc-http-api=ETH,NET,WEB3,QBFT
```

> [!NOTE]
> Com a subida do Nó 3, a rede atinge a maioria qualificada ($2F + 1$) do consenso QBFT. A partir deste exato momento, os validadores começam a assinar e emitir blocos a cada 2 segundos!

### 8.4. Iniciar Nó 4 (Gateway RPC / Membro)
* Porta P2P: `30306` | RPC HTTP: `8545` (0.0.0.0 com CORS `*`) | WebSockets: `8645`

```bash
docker run -d \
  --name besu-rpcnode \
  --restart unless-stopped \
  --network host \
  -v $(pwd)/rpcnode/data:/opt/besu/data \
  -v $(pwd)/rpcnode/genesis.json:/opt/besu/genesis.json \
  -v $(pwd)/rpcnode/permissions_config.toml:/opt/besu/permissions_config.toml \
  hyperledger/besu:24.7.0 \
  --data-path=/opt/besu/data \
  --genesis-file=/opt/besu/genesis.json \
  --p2p-port=30306 \
  --bootnodes=${BOOTNODE_ENODE} \
  --min-gas-price=0 \
  --data-storage-format=BONSAI \
  --profile=ENTERPRISE \
  --permissions-accounts-config-file=/opt/besu/permissions_config.toml \
  --permissions-accounts-config-file-enabled=true \
  --rpc-http-enabled=true \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-api=ETH,NET,WEB3,QBFT,DEBUG,TXPOOL \
  --rpc-http-cors-origins="*" \
  --rpc-ws-enabled=true \
  --rpc-ws-host=0.0.0.0 \
  --rpc-ws-port=8645 \
  --rpc-ws-api=ETH,NET,WEB3,QBFT \
  --metrics-enabled=true \
  --metrics-port=9545
```

---

## 9. Passo 8: Verificação Manual do Estado da Rede (JSON-RPC)

### 9.1. Consultar Contagem de Peers
O nó RPC deve estar conectado a todos os outros 3 nós (`result: 0x3` = 3 peers):
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  -H "Content-Type: application/json" http://127.0.0.1:8545
```

### 9.2. Consultar Altura do Bloco Atual
Verifique se a numeração de blocos está aumentando continuamente a cada 2 segundos:
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" http://127.0.0.1:8545
```

### 9.3. Consultar Validadores Ativos no Consenso QBFT
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" http://127.0.0.1:8545
```

---

## 10. Passo 9: Parada e Limpeza Manual

Para encerrar os contêineres:
```bash
docker stop besu-node1 besu-node2 besu-node3 besu-rpcnode
docker rm besu-node1 besu-node2 besu-node3 besu-rpcnode
```

Se desejar apagar o histórico de blocos e reiniciar o estado da blockchain do zero:
```bash
rm -rf node1/data/DATABASE node2/data/DATABASE node3/data/DATABASE rpcnode/data/DATABASE
rm -rf node1/data/caches node2/data/caches node3/data/caches rpcnode/data/caches
```

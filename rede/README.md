# Infraestrutura de Rede Hyperledger Besu (Multi-Node QBFT)

Módulo de implantação e orquestração da rede privada Ethereum/Besu para o projeto **WydenCoin**, refatorado com base nas melhores práticas do projeto **Ilíada (RNP)** para suporte nativo à execução distribuída em **múltiplas máquinas e nós independentes**.

---

## 🏛️ Visão Geral da Arquitetura

A rede utiliza o algoritmo de consenso bizantino **QBFT (Quorum Byzantine Fault Tolerance)** com tempo de bloco estipulado em **2 segundos**, política de taxa zero (`min-gas-price=0`), pré-financiamento da conta deployer e isolamento entre validadores e gateways de aplicação:

```
                  +-----------------------------------+
                  |      Máquina 1 (Coordenadora)     |
                  |     Validador 1 / Bootnode QBFT   |
                  |      P2P Port: 30303 (TCP/UDP)    |
                  +-----------------+-----------------+
                                    |
          +-------------------------+-------------------------+
          |                         |                         |
          v                         v                         v
+-------------------+     +-------------------+     +-------------------+
|     Máquina 2     |     |     Máquina 3     |     |     Máquina 4     |
|   Validador 2     |     |   Validador 3     |     |   Validador 4     |
|   (Consenso QBFT) |     |   (Consenso QBFT) |     |   (Consenso QBFT) |
+-------------------+     +-------------------+     +-------------------+
          \                         |                         /
           \                        |                        /
            +-----------------------+-----------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |             Máquina 5             |
                  |       Gateway RPC / Consultas     |
                  |  HTTP 8545 | WS 8645 | Metrics 9545
                  |     (Caliper, JMeter, DApps)      |
                  +-----------------------------------+
```

Para mais detalhes, consulte: [arquitetura-multi-node.md](file:///home/mikael/Documentos/Codes/facicoin/rede/docs/arquitetura-multi-node.md).

---

## 📁 Estrutura de Diretórios

```bash
rede/
├── configs/                      # Modelos declarativos e configurações base
│   ├── genesis_QBFT.json         # Especificação do bloco gênese e consenso QBFT
│   ├── network-topology.yaml.example # Exemplo de topologia multi-máquina
│   └── permissions.template.toml # Modelo de permissões de nós e contas
│
├── core/                         # Scripts centrais de geração de rede e empacotamento
│   ├── 01-generate-network.sh    # Cria chaves criptográficas, genesis.json e enodes
│   └── 02-package-nodes.sh       # Empacota bundles autônomos (.tar.gz) para cada VM
│
├── deploy/                       # Orquestradores de implantação por máquina
│   ├── setup-coordinator.sh      # Gera a rede e inicia o Nó 1 na Máquina 1
│   ├── setup-validator.sh        # Inicializa um nó validador (Nós 2 a 4)
│   └── setup-rpc.sh              # Inicializa o nó Gateway RPC
│
├── docker/                       # Artefatos Docker padronizados
│   ├── Dockerfile                # Imagem Besu baseada em hyperledger/besu:24.7.0
│   ├── docker-compose.node.yaml  # Template Compose parametrizável via .env
│   └── node.env.example          # Exemplo de variáveis de ambiente do nó
│
├── docs/                         # Documentação técnica e operacional
│   ├── arquitetura-multi-node.md # Topologia, portas de firewall e funções
│   └── steps-multi-node.md       # Guia operacional passo a passo completo
│
├── scripts/                      # Utilitários de apoio
│   ├── check-node.sh             # Diagnóstico de saúde, peers e bloco
│   ├── install-docker.sh         # Instalação automatizada do Docker & Compose
│   └── stop-node.sh              # Parada e limpeza segura de contêineres
│
└── dist/                         # Diretório gerado contendo os pacotes prontos
    ├── node1/                    # Executável na Máquina 1
    ├── node2.tar.gz              # Pacote para Máquina 2
    ├── node3.tar.gz              # Pacote para Máquina 3
    ├── node4.tar.gz              # Pacote para Máquina 4
    └── rpc-node.tar.gz           # Pacote para Máquina 5
```

---

## 🚀 Guia Rápido de Uso

### 1. Na Máquina 1 (Coordenadora / Bootnode)

Execute o orquestrador fornecendo o IP da Máquina 1:
```bash
./deploy/setup-coordinator.sh --bootnode-ip 192.168.100.184
```

Isso gera as chaves, o arquivo `genesis.json`, os pacotes em `dist/` e já sobe o Nó 1.

### 2. Distribuir para as demais máquinas

```bash
scp dist/node2.tar.gz usuario@192.168.100.146:~/
scp dist/node3.tar.gz usuario@192.168.100.142:~/
scp dist/node4.tar.gz usuario@192.168.100.150:~/
scp dist/rpc-node.tar.gz usuario@192.168.100.143:~/
```

### 3. Nas Máquinas 2, 3 e 4 (Validadores)
```bash
tar -xzf nodeX.tar.gz && cd nodeX && ./run.sh
```

### 4. Na Máquina 5 (Gateway RPC)
```bash
tar -xzf rpc-node.tar.gz && cd rpc-node && ./run.sh
```

### 5. Verificar a Rede
Em qualquer nó, consulte a saúde:
```bash
./check.sh
```

Para o tutorial completo e detalhado com exemplos de chamadas `curl` e solução de problemas, consulte o documento:
📖 [steps-multi-node.md](file:///home/mikael/Documentos/Codes/facicoin/rede/docs/steps-multi-node.md)

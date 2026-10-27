# Infraestrutura de Rede Hyperledger Besu (Multi-Node QBFT - 4 VMs)

Módulo de implantação e orquestração da rede privada Ethereum/Besu para o projeto **WydenCoin**, configurado para suporte nativo à execução distribuída em **4 máquinas virtuais (VMs) independentes**.

---

## 🏛️ Visão Geral da Arquitetura (4 VMs)

A rede utiliza o algoritmo de consenso bizantino **QBFT (Quorum Byzantine Fault Tolerance)** com tempo de bloco estipulado em **2 segundos**, política de taxa zero (`min-gas-price=0`), pré-financiamento da conta deployer e isolamento entre validadores e gateway de aplicação:

```
                  +-----------------------------------+
                  |          VM 1 (Coordenadora)      |
                  |     Validador 1 / Bootnode QBFT   |
                  |      P2P Port: 30303 (TCP/UDP)    |
                  +-----------------+-----------------+
                                    |
          +-------------------------+-------------------------+
          |                                                   |
          v                                                   v
+-------------------+                               +-------------------+
|       VM 2        |                               |       VM 3        |
|   Validador 2     |<=============================>|   Validador 3     |
|   (Consenso QBFT) |                               |   (Consenso QBFT) |
+-------------------+                               +-------------------+
          \                                                   /
           \                                                 /
            +-----------------------+-----------------------+
                                    |
                                    v
                  +-----------------------------------+
                  |               VM 4                |
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
│   ├── genesis_QBFT.json         # Bloco gênese (3 validadores QBFT, 2s block time)
│   ├── network-topology.yaml.example # Topologia das 4 VMs
│   └── permissions.template.toml # Modelo de permissões de nós e contas
│
├── core/                         # Scripts centrais de geração de rede e empacotamento
│   ├── 01-generate-network.sh    # Cria chaves criptográficas, genesis.json e enodes
│   └── 02-package-nodes.sh       # Empacota bundles autônomos (.tar.gz) para cada VM
│
├── deploy/                       # Orquestradores de implantação por máquina
│   ├── setup-coordinator.sh      # Gera a rede e inicia o Nó 1 na VM 1
│   ├── setup-validator.sh        # Inicializa nós validadores (VM 2 e VM 3)
│   └── setup-rpc.sh              # Inicializa o nó Gateway RPC (VM 4)
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
    ├── node1/                    # Executável na VM 1
    ├── node2.tar.gz              # Pacote para VM 2
    ├── node3.tar.gz              # Pacote para VM 3
    └── rpc-node.tar.gz           # Pacote para VM 4
```

---

## 🚀 Guia Rápido de Uso

### 1. Na VM 1 (Coordenadora / Bootnode + Validador 1)

Execute o orquestrador fornecendo o IP da VM 1:
```bash
./deploy/setup-coordinator.sh --bootnode-ip 192.168.100.184
```

Isso gera as chaves dos 3 validadores, o arquivo `genesis.json`, os pacotes em `dist/` e já sobe o Nó 1.

### 2. Distribuir para as demais máquinas via SCP

```bash
scp dist/node2.tar.gz usuario@192.168.100.146:~/
scp dist/node3.tar.gz usuario@192.168.100.142:~/
scp dist/rpc-node.tar.gz usuario@192.168.100.143:~/
```

### 3. Nas VMs 2 e 3 (Validadores QBFT)
```bash
tar -xzf nodeX.tar.gz && cd nodeX && ./run.sh
```

### 4. Na VM 4 (Gateway RPC / Consultas / Caliper / JMeter)
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

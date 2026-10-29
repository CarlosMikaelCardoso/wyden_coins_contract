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

Para mais detalhes sobre o desenho da rede, consulte: [arquitetura-multi-node.md](file:///home/mikael/Documentos/Codes/facicoin/rede/docs/arquitetura-multi-node.md).

---

## 📚 Guias Manuais de Instalação (Sem Scripts .sh)

Para desenvolvedores, pesquisadores e operadores que desejam ter controle manual absoluto sobre a infraestrutura e compreender cada comando executado nos bastidores, consulte os tutoriais detalhados:

* 🖥️ **[lab-single-node/README.md](file:///home/mikael/Documentos/Codes/facicoin/rede/lab-single-node/README.md)**: Guia completo para subir 4 nós em **máquina única** usando comandos `docker run` manuais, mapeamento de portas locais e geração criptográfica passo a passo.
* 🌐 **[lab-multi-node/README.md](file:///home/mikael/Documentos/Codes/facicoin/rede/lab-multi-node/README.md)**: Guia completo para implantar a rede em **4 VMs distribuídas** usando comandos `docker run` manuais, configuração de bootnode externo, transferência via `scp` e placeholders padronizados (`<ip-vm1>`, `<ip-vm2>`, etc.).

---

## 📁 Estrutura de Diretórios

```bash
rede/
├── lab-single-node/              # Tutorial de instalação manual em máquina única (sem .sh)
│   └── README.md
│
├── lab-multi-node/               # Tutorial de instalação manual em 4 VMs (sem .sh)
│   └── README.md
│
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
│   ├── setup-rpc.sh              # Inicializa o nó Gateway RPC (VM 4)
│   └── test-single-machine.sh    # Validação automática da rede em máquina única
│
├── docker/                       # Artefatos Docker padronizados
│   ├── Dockerfile                # Imagem Besu baseada em hyperledger/besu:24.7.0
│   ├── docker-compose.node.yaml  # Template Compose parametrizável via .env
│   └── node.env.example          # Exemplo de variáveis de ambiente do nó
│
├── docs/                         # Documentação técnica e operacional
│   ├── arquitetura-multi-node.md # Topologia, portas de firewall e funções
│   └── steps-multi-node.md       # Guia operacional passo a passo com scripts
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

## Guia Rápido de Uso

### 1. Na VM 1 (Coordenadora / Bootnode + Validador 1)

Execute o orquestrador fornecendo o IP da VM 1:
```bash
./deploy/setup-coordinator.sh --bootnode-ip <ip-vm1>
```

Isso gera as chaves dos 3 validadores, o arquivo `genesis.json`, os pacotes em `dist/` e já sobe o Nó 1.

### 2. Distribuir para as demais máquinas via SCP

```bash
scp dist/node2.tar.gz <usuario>@<ip-vm2>:~/
scp dist/node3.tar.gz <usuario>@<ip-vm3>:~/
scp dist/rpc-node.tar.gz <usuario>@<ip-vm4>:~/
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

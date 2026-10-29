# Guia de Operação da Rede Hyperledger Besu Multi-Node (4 VMs)

Este documento descreve o procedimento operacional passo a passo para inicializar e gerenciar a rede privada Hyperledger Besu (QBFT) em **4 máquinas virtuais (VMs) independentes**, inspirado no modelo do Projeto **Ilíada (RNP)**.

---

## 1. Cenário e Topologia da Rede (4 VMs)

A rede é composta por 4 máquinas participantes:

| Máquina | Papel na Rede | Host / IP Exemplo | Portas Expostas |
| :--- | :--- | :--- | :--- |
| **VM 1** | **Coordenador + Validador 1 (Bootnode)** | `<node1-ip>` | `30303` (P2P TCP/UDP), `8545` (RPC Local) |
| **VM 2** | **Validador 2 (QBFT)** | `<node2-ip>` | `30303` (P2P TCP/UDP), `8545` (RPC Local) |
| **VM 3** | **Validador 3 (QBFT)** | `<node3-ip>` | `30303` (P2P TCP/UDP), `8545` (RPC Local) |
| **VM 4** | **Gateway RPC / Consultas e Aplicações Externas** | `<rpc-ip>` | `30303` (P2P), `8545` (HTTP RPC Público), `8645` (WS) |

> [!TIP]
> Substitua os placeholders `<node1-ip>`, `<node2-ip>`, `<node3-ip>`, `<rpc-ip>` e `<usuario>` pelos valores reais do seu laboratório utilizando o recurso de buscar e substituir (**Ctrl + F**).

> [!NOTE]
> Os nós validadores 1 a 3 participam do algoritmo de consenso QBFT e produzem blocos a cada 2 segundos. O nó RPC (VM 4) atua exclusivamente como gateway de API para contratos inteligentes, ferramentas de benchmark e carteiras (MetaMask), mantendo a integridade e segurança dos nós validadores.

---

## 2. Pré-requisitos em Todas as Máquinas

Em **cada uma das 4 máquinas (VM 1 a VM 4)**, é necessário ter o Docker e Docker Compose instalados:

```bash
# Caso o Docker não esteja instalado, utilize o utilitário fornecido:
chmod +x ./scripts/install-docker.sh
./scripts/install-docker.sh
```

### Regras de Firewall (UFW / iptables)
Certifique-se de liberar o tráfego nas portas necessárias:
* **Em todas as máquinas (P2P)**:
  ```bash
  sudo ufw allow 30303/tcp
  sudo ufw allow 30303/udp
  ```
* **Na VM 4 (Gateway RPC)**:
  ```bash
  sudo ufw allow 8545/tcp
  sudo ufw allow 8645/tcp
  ```

---

## 3. VM 1 (Coordenadora / Bootnode + Validador 1)

A VM 1 é responsável por gerar as chaves criptográficas de todos os nós, o arquivo de bloco gênese (`genesis.json`), as listas de permissões e empacotar as configurações prontas para as demais máquinas.

### Passo 1: Navegar até o diretório da rede
```bash
cd rede
```

### Passo 2: Executar o Assistente de Inicialização do Coordenador
Informe o IP público ou de rede local acessível da VM 1:

```bash
./deploy/setup-coordinator.sh --bootnode-ip <node1-ip>
```

O script realizará automaticamente:
1. Geração das 3 chaves dos validadores via contêiner oficial do Besu (`hyperledger/besu:24.7.0`).
2. Criação do `genesis.json` com QBFT configurado (2s block time, chainId 381660001, 0 gas, 3 validadores).
3. Construção dos pacotes de distribuição em `rede/dist/`:
   * `dist/node1/` (inicializado localmente na VM 1).
   * `dist/node2.tar.gz` (para VM 2).
   * `dist/node3.tar.gz` (para VM 3).
   * `dist/rpc-node.tar.gz` (para VM 4).
4. Inicialização em segundo plano do Validador 1 / Bootnode.

### Passo 3: Verificar o status do Nó 1
```bash
cd dist/node1
./check.sh
```

---

## 4. Distribuição dos Pacotes para as Outras Máquinas (SCP)

Na **VM 1**, envie os arquivos compactados para cada máquina de destino via `scp`:

```bash
# Para a VM 2 (Validador 2)
scp dist/node2.tar.gz <usuario>@<node2-ip>:~/

# Para a VM 3 (Validador 3)
scp dist/node3.tar.gz <usuario>@<node3-ip>:~/

# Para a VM 4 (Gateway RPC / Consultas e Aplicações Externas)
scp dist/rpc-node.tar.gz <usuario>@<rpc-ip>:~/
```

---

## 5. VM 2 e VM 3 (Validadores QBFT)

Repita os seguintes comandos na VM de cada validador correspondente.

### No Validador 2 (VM 2):
```bash
tar -xzf ~/node2.tar.gz
cd ~/node2
./run.sh
```

### No Validador 3 (VM 3):
```bash
tar -xzf ~/node3.tar.gz
cd ~/node3
./run.sh
```

### Como verificar se o validador está conectado e sincronizado:
Em qualquer um dos nós, execute:
```bash
./check.sh
```
Ou acompanhe os logs em tempo real:
```bash
docker compose logs -f
```

Com 2 ou 3 validadores online (maioria qualificada QBFT), a rede iniciará a produção contínua de blocos!

---

## 6. VM 4 (Gateway RPC / Consultas e Aplicações Externas)

Acesse a VM 4 para colocar o nó de consulta e transações no ar:

```bash
tar -xzf ~/rpc-node.tar.gz
cd ~/rpc-node
./run.sh
```

### Testar a conectividade RPC a partir de qualquer computador:
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  -H "Content-Type: application/json" http://<rpc-ip>:8545
```
Resposta esperada (bloco em hexadecimal):
```json
{"jsonrpc":"2.0","id":1,"result":"0x1a"}
```

Para consultar a lista de validadores ativos no bloco atual:
```bash
curl -s -X POST --data '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}' \
  -H "Content-Type: application/json" http://<rpc-ip>:8545
```

---

## 7. Comandos de Operação e Manutenção Diária

Cada pacote gerado possui scripts padronizados:

| Script | Ação | Descrição |
| :--- | :--- | :--- |
| `./run.sh` | Subir o nó | Executa `docker compose up -d` com as variáveis do `.env` |
| `./stop.sh` | Parar o nó | Para e remove o contêiner de forma limpa (`docker compose down`) |
| `./check.sh` | Diagnóstico | Consulta `net_peerCount`, `eth_blockNumber`, sincronização e logs |
| `docker compose logs -f` | Logs | Exibe o stream de logs do Besu em tempo real |

### Resetar a rede do zero (apenas quando necessário):
Se for necessário recriar toda a rede:
1. Em todas as máquinas, execute `./stop.sh && rm -rf data/DATABASE/`.
2. Na VM 1, execute novamente `./deploy/setup-coordinator.sh --bootnode-ip <node1-ip>`.
3. Reenvie os arquivos `.tar.gz` para as VMs 2, 3 e 4.

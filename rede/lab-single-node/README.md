# Laboratório Hyperledger Besu QBFT: Instalação Passo a Passo em Máquina Única (lab-single-node)

> [!NOTE]
> Este laboratório orienta a implantação e operação da rede privada Hyperledger Besu (QBFT) em **máquina única**, utilizando scripts modulares (`.sh`) para cada etapa do processo — seguindo o modelo operacional do projeto **Ilíada (RNP / cenarios-bevel)**. 
> Em vez de scripts monolíticos que executam tudo de forma opaca, cada fase é acionada individualmente para oferecer controle total e visibilidade sobre a rede.

---

## 1. Visão Geral da Arquitetura Local

Para simular o comportamento de uma infraestrutura corporativa completa em um único host (computador local ou máquina virtual), executamos **4 instâncias do Hyperledger Besu**: **3 nós validadores QBFT** e **1 nó gateway RPC**, cada um com portas exclusivas na interface de loopback (`127.0.0.1`):

| Nó | Papel no Consenso | Porta P2P | Porta JSON-RPC HTTP | Porta WebSockets |
| :--- | :--- | :--- | :--- | :--- |
| **`besu-node1`** | **Validador 1 / Bootnode** | `30303` | `8541` (Local) | - |
| **`besu-node2`** | **Validador 2** | `30304` | `8542` (Local) | - |
| **`besu-node3`** | **Validador 3** | `30305` | `8543` (Local) | - |
| **`besu-rpcnode`** | **Gateway RPC / Membro** | `30306` | `8545` (Padrão DApps) | `8645` |

> [!TIP]
> O nó `besu-rpcnode` expõe a porta padrão **8545**. Dessa forma, ferramentas como MetaMask, scripts Node.js, contratos e utilitários de teste conectam-se diretamente a `http://127.0.0.1:8545`.

---

## 2. Passo a Passo de Execução com Scripts Modulares

Navegue até a pasta do laboratório:
```bash
cd rede/lab-single-node
```

### Etapa 1: Instalação e Validação dos Pré-requisitos
Execute o script de verificação do Docker e Docker Compose:
```bash
./01-install-requirements.sh
```
*O script valida a existência do daemon do Docker e permissões do usuário atual.*

---

### Etapa 2: Geração Criptográfica e Bloco Gênese QBFT
Gere as chaves dos 3 validadores, o bloco gênese com tempo de bloco de 2 segundos e os pacotes locais:
```bash
./02-generate-network.sh
```
* **O que este script executa:**
  1. Chama o gerador nativo do Hyperledger Besu (`operator generate-blockchain-config`) configurando 3 validadores e o Chain ID `381660001`.
  2. Extrai o identificador Enode do Nó 1 (`enode://...127.0.0.1:30303`).
  3. Gera o arquivo de allowlist `permissions_config.toml` contendo a conta deployer e as chaves dos validadores.
  4. Estrutura os diretórios em `dist/node1`, `dist/node2`, `dist/node3` e `dist/rpc-node` com portas separadas.

---

### Etapa 3: Subir o Nó 1 (Validador 1 / Bootnode)
Inicialize o nó coordenador da rede:
```bash
./03-start-node1.sh
```
* **O que acontece:** O contêiner `besu-node1` sobe em segundo plano expondo a porta P2P `30303`. Este nó atuará como o ponto de ancoragem para que os demais nós possam se conectar.

---

### Etapa 4: Subir o Nó 2 (Validador 2)
Inicialize o segundo nó validador:
```bash
./04-start-node2.sh
```
* **O que acontece:** O contêiner `besu-node2` inicia na porta `30304` e conecta-se automaticamente ao Nó 1 através do bootnode configurado.

---

### Etapa 5: Subir o Nó 3 (Validador 3) — Ativação do Quorum QBFT
Inicialize o terceiro nó validador:
```bash
./05-start-node3.sh
```
> [!IMPORTANT]
> **Quorum QBFT Atingido:**
> Para tolerar $F$ nós bizantinos (falhas), o QBFT requer pelo menos $3F + 1$ nós, e uma decisão exige a maioria qualificada de pelo menos $2F + 1$ assinaturas. Com 3 nós ativos ($N=3, F=0$), a presença dos 3 validadores é a condição necessária e suficiente para iniciar a produção contínua de blocos a cada 2 segundos!

---

### Etapa 6: Subir o Nó 4 (Gateway RPC / Consultas e DApps)
Inicialize o nó gateway da rede:
```bash
./06-start-rpcnode.sh
```
* **O que acontece:** O contêiner `besu-rpcnode` sobe na porta `30306` (P2P), conecta-se aos 3 validadores e expõe a interface JSON-RPC HTTP na porta padrão **`8545`** com CORS habilitado (`*`) e suporte a WebSockets na porta **`8645`**.

---

### Etapa 7: Diagnóstico Consolidado da Rede
Verifique o estado de saúde de todos os nós:
```bash
./07-check-network.sh
```
* **Saída esperada:**
  - Status `healthy` em todos os 4 contêineres Docker.
  - `Peers Conectados : 3 (0x3)` no nó RPC.
  - `Bloco Atual` incrementando a cada 2 segundos.
  - Array com os 3 endereços dos validadores no consenso QBFT.

---

### Etapa 8: Parada e Limpeza dos Nós
Para encerrar todos os nós em execução:
```bash
./08-stop-network.sh
```

Se desejar apagar o banco de dados e recriar o histórico da blockchain do zero:
```bash
rm -rf ../dist/*/data/DATABASE ../dist/*/data/caches
```

---

## 3. Comandos Equivalentes por Diretório (`dist/`)

Cada pasta gerada em `dist/` é autônoma e possui seus próprios scripts:

```bash
# Subir nó individual
cd ../dist/node1 && ./run.sh

# Diagnóstico de nó individual
cd ../dist/node1 && ./check.sh

# Parar nó individual
cd ../dist/node1 && ./stop.sh

# Visualizar logs em tempo real
cd ../dist/node1 && docker compose logs -f
```

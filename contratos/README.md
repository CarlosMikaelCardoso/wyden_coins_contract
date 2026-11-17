# Documentação dos Contratos: WydenCoin & RedemptionManager

Esta documentação explica a arquitetura e o funcionamento dos contratos inteligentes do projeto WydenCoin, desenvolvidos para rodar na rede Hyperledger Besu. Ela serve de guia para as equipes de Backend/API (Luiz Felipe e Henrique) integrarem as rotas aos contratos.

---

## 📍 Endereços na Rede Multi-Node (Oracle Cloud - Besu QBFT)

* **RPC Endpoint:** `http://129.146.55.236:8545`
* **Chain ID:** `381660001` (`0x16bfab61`)
* **Consenso:** QBFT (Blocos a cada 2 segundos, custo de gas zerado)

| Contrato | Endereço Implantado |
| :--- | :--- |
| **WydenCoin (`WC`)** | `0xa50a51c09a5c451C52BB714527E1974b686D8e77` |
| **RedemptionManager** | `0x9a3DBCa554e9f6b9257aAa24010DA8377C57c17e` |

---

## 1. WydenCoin (Token WC)

### Papéis (Roles)
- `DEFAULT_ADMIN_ROLE`: Responsável por administrar permissões e atualizar o endereço do `RedemptionManager`. O endereço que faz o deploy recebe esse papel.
- `MINTER_ROLE`: Único papel autorizado a gerar/emitir novas moedas (`mintReward`). **A API Node.js deve ter esse papel.**

### Funções para a API

#### `mintReward(address aluno, uint256 valor, bytes32 motivo)`
Gera novas moedas para a carteira de um aluno individual.
- **`aluno`**: O endereço da carteira vinculada ao aluno.
- **`valor`**: A quantidade de WydenCoins a ser creditada.
- **`motivo`**: Um identificador curto (em formato `bytes32`) do motivo do ganho. Exemplos: `SIA_15D`, `PRES_15D`, `SIMULADO`.

#### `mintRewardBatch(address[] calldata alunos, uint256[] calldata valores, bytes32[] calldata motivos)`
Gera novas moedas em lote para dezenas/centenas de alunos em uma única transação atômica. Ideal para o processamento quinzenal do Motor de Recompensas.
- **`alunos`**: Lista de endereços das carteiras dos alunos.
- **`valores`**: Lista de quantidades correspondentes em WydenCoins.
- **`motivos`**: Lista de códigos de regra (`bytes32`). Cada par `(aluno, valor, motivo)` emite o respectivo evento `RewardMinted`.

### Tabela de Códigos de Regras (Motivos de Emissão)

| Código (`motivo`) | Descrição para o Extrato do Aluno | Condição / Critério | Valor Típico |
|-------------------|-----------------------------------|---------------------|--------------|
| `SIA_15D` | Acesso regular ao SIA (15 dias) | Acessou nos últimos 15 dias | 20 WC |
| `PRES_15D` | Frequência presencial regular | Alunos presenciais com $\ge 75\%$ de presença | 30 a 50 WC |
| `SIMULADO` | Participação no Simulado | Adesão completa ou parcial ao Simulado | 15 a 30 WC |
| `DIG_ESTUDO` | Engajamento no Ambiente Digital | Alunos do curso Digital com acesso no ciclo | 50 WC |
| `VOLTOU` | Bônus Retomada aos Estudos (Anti-Evasão) | Alunos com $>30$ dias inativos que retornaram | 100 WC |
| `CR_SEM` | Reconhecimento de Desempenho (CR) | Pago 1x/semestre para alunos com CR $\ge 6.0$ | 25 a 40 WC |
| `ESTUDO_30` | *(Reservada)* 30% tempo de estudo | Aguardando envio das horas pela coordenação | 100 WC |
| `ESTUDO_SUBIU` | *(Reservada)* Tempo de estudo subiu | Aguardando envio das horas pela coordenação | Bônus |

### Eventos (Para o Indexador do Dashboard)
- `RewardMinted(address indexed aluno, uint256 valor, bytes32 motivo)`: Emitido sempre que novas moedas são dadas. O indexador no Node.js pode escutar esse evento para gerar o extrato detalhado do aluno e atualizar os indicadores da gestão.

---

## 2. RedemptionManager (Gerenciador de Resgates)

Fluxo centralizado para resgate de benefícios, sejam eles itens da cantina, descontos na mensalidade ou mentorias. 

O fluxo padrão tem 4 estados (`Status`):
1. **Resgatado (Pendente):** O aluno escolhe o benefício e as moedas ficam retidas/bloqueadas no contrato.
2. **Utilizado:** A cantina/mentor entrega o benefício ao aluno e o backend confirma. As moedas retidas são **queimadas**.
3. **Cancelado:** O backend ou aluno cancela o pedido. As moedas retidas **voltam** para o saldo livre do aluno.
4. **Expirado:** O voucher não foi utilizado no prazo estipulado. O backend roda uma rotina cron para expirar. As moedas **voltam** para o aluno.

### Papéis (Roles)
- `DEFAULT_ADMIN_ROLE`: Administrador geral que concederá permissões aos componentes do backend.
- `CONFIRMER_ROLE`: Papel que pode confirmar o uso de um voucher. Pode ser dado a APIs específicas que as cantinas/mentores utilizam.
- `MANAGER_ROLE`: Papel autorizado a cancelar ou expirar um resgate para estornar moedas.

### Funções para a API

#### `resgatar(uint256 beneficioId, uint256 valor, uint64 expiraEm) returns (uint256 id)`
Função acionada quando o aluno clica em "Resgatar Benefício" no frontend. Retira as moedas da carteira do aluno e as deixa sob a custódia do contrato.
- **`beneficioId`**: ID único do benefício no banco de dados (PostgreSQL).
- **`valor`**: Preço em WydenCoins.
- **`expiraEm`**: Um timestamp Unix (em segundos) definindo quando o voucher vence e pode ser expirado (Ex: `Date.now() / 1000 + 86400` para 24 horas).
- **Retorno**: Um `id` de resgate autoincrementado gerado na blockchain.

#### `confirmarUso(uint256 id)`
Função acionada pela API quando a cantina bipa o voucher ou o mentor confirma a sessão.
- Só pode ser chamado por quem tem `CONFIRMER_ROLE`.
- Queima permanentemente as moedas da rede, reduzindo a inflação da WydenCoin.

#### `cancelar(uint256 id)`
Função para estorno administrativo manual.
- Só pode ser chamado por quem tem `MANAGER_ROLE`.
- O saldo é devolvido à carteira do aluno.

#### `expirar(uint256 id)`
Função acionada por um cron job/verificador no Node.js sempre que a data atual passar da data `expiraEm`.
- Só pode ser chamado por quem tem `MANAGER_ROLE`.
- O saldo é devolvido à carteira do aluno.

### Eventos
Esses eventos são fundamentais para o indexador manter o banco de dados sincronizado:
- `ResgateCriado(uint256 indexed id, address indexed aluno, uint256 beneficioId, uint256 valor, uint64 expiraEm)`
- `ResgateUtilizado(uint256 indexed id)`
- `ResgateCancelado(uint256 indexed id)`
- `ResgateExpirado(uint256 indexed id)`

---

## 🛠️ Passo a Passo para o Setup do Backend (Recomendado: Gateway API)

Para a API Node.js/Express (desenvolvida por Luiz Felipe e Henrique) se comunicar com a blockchain de forma segura e sem complexidade de Web3, utilize o cliente oficial do Gateway:

👉 **Consulte o guia completo com exemplos práticos: [`GUIA_CHAMADAS_GATEWAY_CLIENT.md`](GUIA_CHAMADAS_GATEWAY_CLIENT.md)**  
👉 **Arquivo do cliente pronto para copiar: [`gateway_client.js`](gateway_client.js)**

### Como Inicializar no Backend:
```bash
# 1. Copie o gateway_client.js para seu projeto Express
# 2. No seu .env, adicione:
BLOCKCHAIN_GATEWAY_URL=http://129.146.55.236:8546
BLOCKCHAIN_GATEWAY_TOKEN=wyden-rpc-sec-9a8f27b4e1
```

```javascript
const { WydencoinGatewayClient } = require('./gateway_client');
const blockchain = new WydencoinGatewayClient();

// Exemplo: Consultar saldo
const { saldo } = await blockchain.getSaldo("0x...");

// Exemplo: Bonificar aluno
await blockchain.emitirRecompensa("0x...", 20, "SIA_15D");
```

---

## Passo a Passo Alternativo (Direto via Ethers.js - Baixo Nível)

Para a API Node.js/Express se comunicar com os contratos usando a biblioteca `ethers`, siga esse padrão:

1. **Assinar Transações (Signer):**
A API deve instanciar um `Wallet` com a chave privada de uma conta administradora (que possua os papéis `MINTER_ROLE`, `MANAGER_ROLE` e `CONFIRMER_ROLE`).

2. **Aprovação Automática (Para o Resgate):**
Como as moedas do aluno precisam ir para o `RedemptionManager`, o aluno precisa autorizar. A rota que cria a carteira do aluno (`POST /alunos/me/carteira`) deve, assim que instanciar a carteira na blockchain, enviar a transação genérica `WydenCoin.approve(ENDERECO_REDEMPTION_MANAGER, ethers.MaxUint256)`. Isso permite que o `RedemptionManager` processe todos os resgates futuros sem atrito ou assinaturas extras do aluno.

3. **Chamada ao Mint (Dar Moedas):**
```javascript
// Exemplo Node.js
const motivoHex = ethers.encodeBytes32String("SIA_15D");
const tx = await wydenCoinContract.mintReward(alunoAddress, 20, motivoHex);
await tx.wait();
```

4. **Chamada ao Resgate (Comprar Voucher):**
*(Opcionalmente assinada pela carteira do aluno ou por um delegador)*
```javascript
// Exemplo Node.js
const expiraEm = Math.floor(Date.now() / 1000) + 86400; // Validade de 1 dia
const tx = await redemptionManagerContract.resgatar(beneficioId, 50, expiraEm);
const receipt = await tx.wait();
// Capturar o 'id' do evento ResgateCriado no receipt para salvar no PostgreSQL
```

5. **Chamada de Emissão em Lote (Motor de Recompensas):**
```javascript
// Exemplo Node.js para processar um ciclo quinzenal inteiro
const alunos = ["0x...", "0x..."];
const valores = [20, 50];
const motivos = [
    ethers.encodeBytes32String("SIA_15D"),
    ethers.encodeBytes32String("PRES_15D")
];

const tx = await wydenCoinContract.mintRewardBatch(alunos, valores, motivos);
await tx.wait();
```

---

## Como Rodar os Testes

Para validar a compilação e a função de emissão em lote utilizando a base real de 66 alunos da simulação:

```bash
cd contratos
npm run compile
npm test
```

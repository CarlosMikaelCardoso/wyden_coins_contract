# 🚀 Guia de Integração do Backend — Wydencoin Gateway

Guia prático para as equipes de Backend (**Luiz Felipe e Henrique**) integrarem a API Geral do WydenCoin com a blockchain Hyperledger Besu utilizando o cliente [`gateway_client.js`](gateway_client.js).

> **Por que usar o Gateway Client?**
> Você **não** precisa instalar bibliotecas pesadas de Web3 (`ethers` ou `web3.js`), compilar contratos Solidity ou lidar com gas, nonces e ABIs. Tudo é abstraído por funções JavaScript assíncronas simples que retornam JSON.

---

## 1. Instalação e Requisitos

* **Node.js:** Versão 18 ou superior (utiliza o `fetch` nativo).
* **Dependências extras:** **Nenhuma!** Zero dependências `npm`.

### Como adicionar ao projeto da sua API:
Copie o arquivo [`gateway_client.js`](gateway_client.js) para dentro da pasta de serviços da sua API (ex: `src/services/gateway_client.js`).

---

## 2. Variáveis de Ambiente (`.env`)

Adicione no arquivo `.env` da sua aplicação Node.js:

```env
# URL do Gateway na VM Oracle Cloud (Phoenix)
BLOCKCHAIN_GATEWAY_URL=http://129.146.55.236:8546

# Token secreto de autenticacao para autorizar as chamadas
BLOCKCHAIN_GATEWAY_TOKEN=wyden-rpc-sec-9a8f27b4e1
```

---

## 3. Inicializando o Cliente

Em qualquer arquivo de serviço ou controller da sua API:

```javascript
// src/services/blockchain.service.js
const { WydencoinGatewayClient } = require('./gateway_client');

// Instancia o cliente usando as variaveis do .env automaticamente
const blockchain = new WydencoinGatewayClient();

module.exports = blockchain;
```

---

## 4. Exemplos Práticos por Caso de Uso

### 4.1. Consultar Saldo de um Aluno
Ideal para a rota `GET /alunos/:id/saldo` ou para exibir na home do app.

```javascript
// Exemplo em um controller Express
async function obterSaldoAluno(req, res) {
  try {
    const { carteiraAddress } = req.params; // Ex: '0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73'

    const dados = await blockchain.getSaldo(carteiraAddress);

    // Retorno: { success: true, aluno: '0x...', saldo: 150, unidade: 'WC' }
    return res.json({
      saldo: dados.saldo,
      unidade: dados.unidade
    });
  } catch (erro) {
    return res.status(500).json({ erro: erro.message });
  }
}
```

---

### 4.2. Bonificar Aluno Individual (Mint)
Acionado quando o aluno completa uma ação (ex: respondeu ao simulado ou bateu meta de presença).

```javascript
// Codigos de motivo aceitos: 'SIA_15D', 'PRES_15D', 'SIMULADO', 'DIG_ESTUDO', 'VOLTOU', 'CR_SEM'
async function premiarAluno(req, res) {
  try {
    const { carteiraAddress, valor, motivo } = req.body;

    const tx = await blockchain.emitirRecompensa(carteiraAddress, valor, motivo);

    // Retorno de sucesso:
    // {
    //   success: true,
    //   txHash: "0xacca49...",
    //   blockNumber: 92315,
    //   aluno: "0x...",
    //   valor: 30,
    //   motivo: "SIMULADO"
    // }
    return res.json({
      sucesso: true,
      transacaoHash: tx.txHash,
      bloco: tx.blockNumber
    });
  } catch (erro) {
    return res.status(400).json({ erro: erro.message });
  }
}
```

---

### 4.3. Motor de Recompensas Quinzenal (Emissão em Lote / Batch Mint)
Ideal para a rotina que roda quinzenalmente processando o relatório acadêmico de dezenas/centenas de alunos de uma só vez (atômico e com altíssima performance).

```javascript
async function rodarMotorQuinzenal() {
  const loteAlunos = [
    { aluno: "0x1111111111111111111111111111111111111111", valor: 20, motivo: "SIA_15D" },
    { aluno: "0x2222222222222222222222222222222222222222", valor: 50, motivo: "PRES_15D" },
    { aluno: "0x3333333333333333333333333333333333333333", valor: 40, motivo: "CR_SEM" }
  ];

  try {
    const resultado = await blockchain.emitirLoteRecompensas(loteAlunos);

    console.log(`Lote processado! ${resultado.totalItens} premiações gravadas.`);
    console.log(`Hash do lote: ${resultado.txHash} no Bloco #${resultado.blockNumber}`);
  } catch (erro) {
    console.error("Falha ao rodar motor quinzenal:", erro.message);
  }
}
```

---

### 4.4. Resgate de Benefício (Comprar Voucher no App)
Quando o aluno clica em "Resgatar Café" ou "Desconto na Mensalidade" no app. Os tokens saem da carteira do aluno e ficam bloqueados sob custódia do contrato on-chain.

```javascript
async function comprarBeneficio(req, res) {
  try {
    const { alunoPrivateKey, beneficioId, precoWC, validadeHoras } = req.body;

    const resgate = await blockchain.solicitarResgate(
      alunoPrivateKey,
      beneficioId,
      precoWC,
      validadeHoras || 24
    );

    // Salvar o resgate.idResgate no PostgreSQL associado ao pedido do aluno
    return res.status(201).json({
      sucesso: true,
      voucherId: resgate.idResgate,
      validoAteTimestamp: resgate.expiraEm,
      txHash: resgate.txHash
    });
  } catch (erro) {
    return res.status(400).json({ erro: erro.message });
  }
}
```

---

### 4.5. Cantina / Mentor Bipa o QR Code (Confirmar Uso e Queimar Moedas)
Rota chamada pelo operador/cantina para validar o benefício. O contrato queima as moedas custodiadas.

```javascript
async function validarVoucherNaCantina(req, res) {
  try {
    const { voucherId } = req.params;

    // 1. Opcional: checar estado atual antes
    const info = await blockchain.consultarResgate(voucherId);
    if (info.status !== "Resgatado") {
      return res.status(400).json({ erro: `Voucher não pode ser usado: status atual é ${info.status}` });
    }

    // 2. Confirma uso e executa o burn dos tokens
    const resultado = await blockchain.confirmarUsoVoucher(voucherId);

    return res.json({
      sucesso: true,
      mensagem: "Benefício entregue com sucesso!",
      status: resultado.status, // 'Utilizado'
      txHash: resultado.txHash
    });
  } catch (erro) {
    return res.status(400).json({ erro: erro.message });
  }
}
```

---

### 4.6. Estorno Administrativo ou Expiração Automática
* **Cancelar (Estorno Manual):** Devolve as moedas para o aluno.
  ```javascript
  await blockchain.cancelarVoucher(voucherId);
  ```
* **Expirar (Rotina Cron):** Executada periodicamente pelo backend para devolver tokens de vouchers que passaram da validade.
  ```javascript
  await blockchain.expirarVoucher(voucherId);
  ```

---

### 4.7. Healthcheck e Monitoramento de Conexão
Para verificar se a rede blockchain está online no painel do administrador:

```javascript
const status = await blockchain.getHealth();
console.log(status);
// {
//   status: 'UP',
//   network: { chainId: 381660001, blockNumber: 92350, peers: 2, syncing: false },
//   contracts: { wydenCoin: '0xa50a5...', redemptionManager: '0x9a3DB...' }
// }
```

---

## 5. Tabela Resumo dos Métodos

| Método | Argumentos | Retorno Principal |
| :--- | :--- | :--- |
| `getHealth()` | *(nenhum)* | Objeto com status `UP`, número do bloco e peers |
| `getSaldo(aluno)` | `alunoAddress` | `{ saldo: number, unidade: 'WC' }` |
| `emitirRecompensa(aluno, valor, motivo)` | `aluno`, `valor`, `motivo` | `{ txHash, blockNumber, valor, motivo }` |
| `emitirLoteRecompensas(itens)` | `[{ aluno, valor, motivo }]` | `{ totalItens, txHash, blockNumber }` |
| `solicitarResgate(key, id, valor, horas)` | `alunoKey`, `beneficioId`, `valor`, `horas` | `{ idResgate, expiraEm, txHash }` |
| `consultarResgate(id)` | `id` | `{ id, aluno, beneficioId, valor, status }` |
| `confirmarUsoVoucher(id)` | `id` | `{ id, status: 'Utilizado', txHash }` |
| `cancelarVoucher(id)` | `id` | `{ id, status: 'Cancelado', txHash }` |
| `expirarVoucher(id)` | `id` | `{ id, status: 'Expirado', txHash }` |
| `chamadaRpcBruta(method, params)` | `method`, `params` | Resposta bruta do RPC do Besu |

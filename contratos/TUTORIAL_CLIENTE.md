# 📘 Tutorial Prático: Como Usar o `gateway_client.js`

Este tutorial ensina como testar o cliente localmente no seu computador e como utilizar suas funções dentro da API / Backend do WydenCoin.

---

## 🎯 O que é o `gateway_client.js`?

É um **SDK / biblioteca cliente em JavaScript** pronta para uso. 

Em vez de você ter que configurar conexões Web3 complexas (`ethers`, chaves privadas, estimativas de gas, compilação de ABIs), você apenas chama funções assíncronas simples em JavaScript (`client.getSaldo()`, `client.emitirRecompensa()`, etc.) que se comunicam diretamente com a Gateway API na nuvem.

---

## 🚀 Passo 1: Como Rodar o Teste Completo Agora Mesmo no Terminal

O próprio arquivo já vem com um teste demonstrativo funcional no rodapé. Você pode executá-lo a partir do seu terminal local:

1. Abra o terminal e acerte o diretório:
   ```bash
   cd /home/mikael/Documentos/Codes/facicoin/contratos
   ```

2. Execute o arquivo com o Node.js:
   ```bash
   node gateway_client.js
   ```

3. **O que acontece ao rodar:**
   * Ele conecta via internet na máquina RPC da Oracle Cloud (`http://wydencoin-rpc.duckdns.org:8546`).
   * Valida a saúde da rede Besu.
   * Consulta o saldo atual de um aluno.
   * Emite moedas de bonificação on-chain em tempo real.
   * Confirma o novo saldo e imprime os hashes de transação e números de blocos minerados.

---

## 📦 Passo 2: Como Importar o Cliente no Projeto da API (Backend)

Para o time de backend (Luiz Felipe e Henrique) utilizar na API Express:

1. Copie o arquivo `gateway_client.js` para a pasta de serviços do seu projeto (ex: `src/services/gateway_client.js`).
2. No seu arquivo JavaScript, basta instanciar a classe:

```javascript
const { WydencoinGatewayClient } = require('./gateway_client');

// Instancia o cliente (ja aponta para a VM RPC com o token correto por padrao)
const client = new WydencoinGatewayClient();
```

---

## 🛠️ Passo 3: Guia das Funções do Cliente

Todas as funções são assíncronas (`async/await`) e retornam objetos JSON simples.

---

### 1. Checar se a Blockchain está Online (`getHealth`)
Ideal para telas de status, monitoramento ou healthcheck da aplicação.

```javascript
const saude = await client.getHealth();

console.log("Status:", saude.status);                       // "UP"
console.log("Bloco mais recente:", saude.network.blockNumber); // ex: 92450
console.log("Validadores conectados:", saude.network.peers);   // 2
```

---

### 2. Consultar Saldo de um Aluno (`getSaldo`)
Consulta quantas moedas o aluno possui. É uma operação de leitura gratuita (não consome gas) e responde de forma imediata.

```javascript
const carteiraAluno = "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73";

const resposta = await client.getSaldo(carteiraAluno);

console.log(`Saldo: ${resposta.saldo} ${resposta.unidade}`);
// Exemplo de saída: "Saldo: 60 WC"
```

---

### 3. Dar Moedas para 1 Aluno (`emitirRecompensa`)
Acionado quando o aluno completa uma ação individual meritória (ex: fez o simulado ou acessou o SIA).

* **Parâmetros:** `(alunoAddress, valor, motivo)`
* **Códigos de Motivo Padrão:** `'SIA_15D'`, `'PRES_15D'`, `'SIMULADO'`, `'DIG_ESTUDO'`, `'VOLTOU'`, `'CR_SEM'`.

```javascript
const aluno = "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73";
const valor = 30; // 30 WydenCoins
const motivo = "SIMULADO";

const tx = await client.emitirRecompensa(aluno, valor, motivo);

console.log("Transação confirmada on-chain!");
console.log("Hash da transação:", tx.txHash);
console.log("Bloco minerado:", tx.blockNumber);
```

---

### 4. Motor de Recompensas em Lote (`emitirLoteRecompensas`)
Ideal para a rotina quinzenal. Emite moedas para dezenas ou centenas de alunos **em uma única transação atômica** on-chain (muito mais rápido e econômico).

```javascript
const loteQuinzenal = [
  { aluno: "0x1111111111111111111111111111111111111111", valor: 20, motivo: "SIA_15D" },
  { aluno: "0x2222222222222222222222222222222222222222", valor: 50, motivo: "PRES_15D" },
  { aluno: "0x3333333333333333333333333333333333333333", valor: 40, motivo: "CR_SEM" }
];

const resultado = await client.emitirLoteRecompensas(loteQuinzenal);

console.log(`Sucesso! ${resultado.totalItens} premiações processadas.`);
console.log("Hash do lote:", resultado.txHash);
```

---

### 5. Aluno Resgatar Benefício no App (`solicitarResgate`)
Quando o aluno clica em "Comprar Voucher na Cantina" no app mobile. As moedas saem da carteira do aluno e ficam sob custódia temporária do contrato inteligente.

* **Parâmetros:** `(alunoPrivateKey, beneficioId, valor, horasValidade)`

```javascript
const resgate = await client.solicitarResgate(
  alunoPrivateKey, // Chave privada da carteira do aluno (para autorizar a custodia)
  101,             // ID do produto no banco de dados da aplicacao
  50,              // Preço: 50 WC
  24               // Validade: 24 horas para consumir
);

console.log("Voucher gerado na blockchain!");
console.log("ID do voucher:", resgate.idResgate); // Grave este ID no PostgreSQL da aplicacao
console.log("Expira no timestamp:", resgate.expiraEm);
```

---

### 6. Consultar Estado de um Voucher (`consultarResgate`)
Verifica se o voucher ainda é válido antes de entregar o produto.

```javascript
const voucher = await client.consultarResgate(1);

console.log("Status:", voucher.status); 
// Retorna: "Resgatado" (pendente), "Utilizado", "Cancelado" ou "Expirado"
console.log("Valor:", voucher.valor, "WC");
```

---

### 7. Cantina Validar Voucher / Bipar QR Code (`confirmarUsoVoucher`)
A cantina confirma a entrega do produto. O contrato inteligente **queima permanentemente** as moedas custodiadas.

```javascript
const voucherId = 1;

const confirmacao = await client.confirmarUsoVoucher(voucherId);

console.log("Benefício entregue e moedas queimadas!");
console.log("Novo status:", confirmacao.status); // "Utilizado"
```

---

### 8. Estorno ou Expiração (`cancelarVoucher` e `expirarVoucher`)
* **Cancelar (Estorno Manual):** Se o aluno desistir ou o item estiver esgotado, o saldo é devolvido para a carteira dele:
  ```javascript
  await client.cancelarVoucher(voucherId);
  ```
* **Expirar (Rotina Cron):** Executada periodicamente de madrugada para estornar vouchers vencidos:
  ```javascript
  await client.expirarVoucher(voucherId);
  ```

---

## 💻 Passo 4: Exemplo Completo em uma API Express

Veja como fica a integração real em um servidor Express:

```javascript
const express = require('express');
const { WydencoinGatewayClient } = require('./gateway_client');

const app = express();
app.use(express.json());

const blockchain = new WydencoinGatewayClient();

// ROTA 1: Consultar Saldo
app.get('/api/alunos/:carteira/saldo', async (req, res) => {
  try {
    const dados = await blockchain.getSaldo(req.params.carteira);
    return res.json({ saldo: dados.saldo });
  } catch (erro) {
    return res.status(500).json({ erro: erro.message });
  }
});

// ROTA 2: Premiar Aluno
app.post('/api/recompensas/bonificar', async (req, res) => {
  try {
    const { carteiraAluno, valor, motivo } = req.body;
    const tx = await blockchain.emitirRecompensa(carteiraAluno, valor, motivo);
    return res.json({ sucesso: true, txHash: tx.txHash, bloco: tx.blockNumber });
  } catch (erro) {
    return res.status(400).json({ erro: erro.message });
  }
});

// ROTA 3: Cantina Bipar e Queimar Voucher
app.post('/api/cantina/validar/:id', async (req, res) => {
  try {
    const resultado = await blockchain.confirmarUsoVoucher(req.params.id);
    return res.json({ sucesso: true, status: resultado.status });
  } catch (erro) {
    return res.status(400).json({ erro: erro.message });
  }
});

app.listen(8080, () => console.log("API rodando na porta 8080"));
```

---

## 📊 Tabela Rápida de Referência dos Métodos

| Método | Argumentos | Retorno Principal |
| :--- | :--- | :--- |
| `getHealth()` | *(nenhum)* | Status `UP`, bloco e peers |
| `getSaldo(aluno)` | `alunoAddress` | `{ saldo: number, unidade: 'WC' }` |
| `emitirRecompensa(aluno, valor, motivo)` | `aluno`, `valor`, `motivo` | `{ txHash, blockNumber, valor, motivo }` |
| `emitirLoteRecompensas(itens)` | `[{ aluno, valor, motivo }]` | `{ totalItens, txHash, blockNumber }` |
| `solicitarResgate(key, id, valor, horas)` | `alunoKey`, `beneficioId`, `valor`, `horas` | `{ idResgate, expiraEm, txHash }` |
| `consultarResgate(id)` | `id` | `{ id, aluno, beneficioId, valor, status }` |
| `confirmarUsoVoucher(id)` | `id` | `{ id, status: 'Utilizado', txHash }` |
| `cancelarVoucher(id)` | `id` | `{ id, status: 'Cancelado', txHash }` |
| `expirarVoucher(id)` | `id` | `{ id, status: 'Expirado', txHash }` |
| `chamadaRpcBruta(method, params)` | `method`, `params` | Resposta bruta do RPC do Besu |

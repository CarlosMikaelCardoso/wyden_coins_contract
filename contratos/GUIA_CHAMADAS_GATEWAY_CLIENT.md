# 📡 Guia de Chamadas via JSON (API REST & RPC Gateway)

Este guia documenta **como fazer chamadas HTTP enviando e recebendo JSON** diretamente no RPC Gateway do WydenCoin (`129.146.55.236:8546`), sem depender de bibliotecas ou SDKs específicos. 

Qualquer linguagem ou ferramenta (cURL, Postman, Insomnia, Python `requests`, Flutter/Dart, PHP, Java ou JavaScript nativo) pode consumir estes endpoints.

---

## 🌐 1. Configurações Globais de Rede e Headers

* **URL Base do Gateway:**
  * Direta (Nuvem / 4G / Servidor): `http://129.146.55.236:8546`
  * Local (caso esteja em rede com firewall/FortiGuard via túnel SSH): `http://localhost:8546`
* **Headers HTTP Obrigatórios:**
  ```http
  Content-Type: application/json
  X-API-KEY: wyden-rpc-sec-9a8f27b4e1
  ```
  *(Também é aceito no formato `Authorization: Bearer wyden-rpc-sec-9a8f27b4e1`)*

---

## 📋 2. Tabela Rápida de Endpoints

| Método | Endpoint | Autenticação | Descrição |
| :--- | :--- | :---: | :--- |
| `GET` | `/health` | Pública | Status da API, bloco atual e contratos |
| `GET` | `/api/v1/saldo/:aluno` | `X-API-KEY` | Consulta de saldo de WydenCoins (WC) |
| `POST` | `/api/v1/recompensas/mint` | `X-API-KEY` | Emissão de moedas para 1 aluno |
| `POST` | `/api/v1/recompensas/mint-batch` | `X-API-KEY` | Emissão de moedas em lote quinzenal |
| `POST` | `/api/v1/resgates` | `X-API-KEY` | Criação de resgate / voucher |
| `GET` | `/api/v1/resgates/:id` | `X-API-KEY` | Consulta detalhes e status do resgate |
| `POST` | `/api/v1/resgates/:id/confirmar` | `X-API-KEY` | Confirmação e queima on-chain na cantina |
| `POST` | `/api/v1/resgates/:id/cancelar` | `X-API-KEY` | Cancelamento e devolução de moedas |
| `POST` | `/api/v1/resgates/:id/expirar` | `X-API-KEY` | Expiração de voucher vencido |
| `POST` | `/api/v1/rpc` | `X-API-KEY` | Proxy JSON-RPC nativo para o nó Besu |

---

## 🛠️ 3. Especificação Detalhada das Chamadas via JSON

---

### 3.1. `GET /health` (Verificação de Status)

Consulta pública para saber se a API Gateway e o nó Besu estão online.

* **Método:** `GET`
* **URL:** `http://129.146.55.236:8546/health`
* **Body:** Nenhum.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "status": "UP",
  "network": {
    "chainId": 381660001,
    "blockNumber": 165620,
    "peers": 2,
    "syncing": false
  },
  "contracts": {
    "wydenCoin": "0xa50a51c09a5c451C52BB714527E1974b686D8e77",
    "redemptionManager": "0x9a3DBCa554e9f6b9257aAa24010DA8377C57c17e"
  },
  "timestamp": "2026-11-17T17:50:00.000Z"
}
```

#### Exemplo cURL:
```bash
curl -X GET http://129.146.55.236:8546/health
```

---

### 3.2. `GET /api/v1/saldo/:aluno` (Consultar Saldo)

Retorna o saldo de WydenCoins de uma carteira informada na URL.

* **Método:** `GET`
* **URL:** `http://129.146.55.236:8546/api/v1/saldo/0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73`
* **Headers:**
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`
* **Body:** Nenhum.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
  "saldo": 70,
  "unidade": "WC"
}
```

#### Exemplo cURL:
```bash
curl -X GET http://129.146.55.236:8546/api/v1/saldo/0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73 \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1"
```

---

### 3.3. `POST /api/v1/recompensas/mint` (Emissão Individual)

Emite novas unidades de WydenCoin para a carteira de um aluno por motivo meritório.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/recompensas/mint`
* **Headers:**
  * `Content-Type: application/json`
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`

#### JSON da Requisição (Request Payload):
```json
{
  "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
  "valor": 10,
  "motivo": "SIA_15D"
}
```

* **Campos:**
  * `aluno` *(string, obrigatório)*: Endereço hexadecimal da carteira (`0x...`).
  * `valor` *(number, obrigatório)*: Quantidade inteira de WydenCoins (ex: `10`, `30`).
  * `motivo` *(string, opcional)*: Código do motivo (Ex: `SIA_15D`, `PRES_15D`, `SIMULADO`, `DIG_ESTUDO`, `VOLTOU`, `CR_SEM`).

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "txHash": "0x285263135888b78ee8f6946079850d2f790c58716da5c13fcdc202bb7b27bd93",
  "blockNumber": 165576,
  "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
  "valor": 10,
  "motivo": "SIA_15D"
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/recompensas/mint \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1" \
  -d '{
    "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
    "valor": 10,
    "motivo": "SIA_15D"
  }'
```

---

### 3.4. `POST /api/v1/recompensas/mint-batch` (Emissão em Lote)

Emite moedas para múltiplos alunos em uma **única transação atômica**. Ideal para rotinas de fechamento quinzenal.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/recompensas/mint-batch`
* **Headers:**
  * `Content-Type: application/json`
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`

#### JSON da Requisição (Request Payload):
```json
{
  "itens": [
    {
      "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
      "valor": 10,
      "motivo": "SIA_15D"
    },
    {
      "aluno": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
      "valor": 10,
      "motivo": "PRES_15D"
    },
    {
      "aluno": "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
      "valor": 30,
      "motivo": "SIMULADO"
    }
  ]
}
```

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "totalItens": 3,
  "txHash": "0x3c21a4f00b991ef2340bfa15f79a9cd89031ef091a13c983c21f98bc1901ab21",
  "blockNumber": 165580
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/recompensas/mint-batch \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1" \
  -d '{
    "itens": [
      { "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73", "valor": 10, "motivo": "SIA_15D" },
      { "aluno": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8", "valor": 10, "motivo": "PRES_15D" }
    ]
  }'
```

---

### 3.5. `POST /api/v1/resgates` (Criar Resgate / Voucher)

Transfere as moedas do aluno para a custódia do contrato `RedemptionManager` gerando um voucher.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/resgates`
* **Headers:**
  * `Content-Type: application/json`
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`

#### JSON da Requisição (Request Payload):
```json
{
  "alunoPrivateKey": "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63",
  "beneficioId": 101,
  "valor": 15,
  "horasValidade": 24
}
```

* **Campos:**
  * `alunoPrivateKey` *(string, obrigatório)*: Chave privada da carteira do aluno para autorizar a transferência para custódia.
  * `beneficioId` *(number, obrigatório)*: ID do produto no banco de dados da aplicação.
  * `valor` *(number, obrigatório)*: Custo do item em WydenCoins.
  * `horasValidade` *(number, opcional, padrão: 24)*: Prazo de expiração do voucher em horas.

#### Exemplo de Resposta JSON (`201 Created`):
```json
{
  "success": true,
  "idResgate": 1,
  "beneficioId": 101,
  "valor": 15,
  "expiraEm": 1763481600,
  "txHash": "0x1d4ef289a0bc9882aef9120934bd081cde91209384bbfa890123ef89021cd981",
  "blockNumber": 165585
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/resgates \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1" \
  -d '{
    "alunoPrivateKey": "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63",
    "beneficioId": 101,
    "valor": 15,
    "horasValidade": 24
  }'
```

---

### 3.6. `GET /api/v1/resgates/:id` (Consultar Voucher)

Obtém os dados e o status on-chain de um voucher emitido.

* **Método:** `GET`
* **URL:** `http://129.146.55.236:8546/api/v1/resgates/1`
* **Headers:**
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`
* **Body:** Nenhum.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "id": 1,
  "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
  "beneficioId": 101,
  "valor": 15,
  "expiraEm": 1763481600,
  "status": "Resgatado",
  "statusCode": 0
}
```

* **Significado de `status` e `statusCode`:**
  * `0`: `"Resgatado"` (Pendente / Pronto para uso)
  * `1`: `"Utilizado"` (Consumido na cantina / Moedas queimadas)
  * `2`: `"Cancelado"` (Cancelado pelo gestor / Saldo devolvido)
  * `3`: `"Expirado"` (Prazo ultrapassado / Saldo devolvido)

#### Exemplo cURL:
```bash
curl -X GET http://129.146.55.236:8546/api/v1/resgates/1 \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1"
```

---

### 3.7. `POST /api/v1/resgates/:id/confirmar` (Validar / Queimar Voucher)

Chamado quando o operador da cantina valida o QR Code do voucher. Queima definitivamente as moedas custodiadas.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/resgates/1/confirmar`
* **Headers:**
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`
* **Body:** Vazio ou `{}`.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "id": 1,
  "status": "Utilizado",
  "txHash": "0x98fba100c8a2b34de5912389012cae98120398bbde90123890123abcdfe98012",
  "blockNumber": 165590
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/resgates/1/confirmar \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1"
```

---

### 3.8. `POST /api/v1/resgates/:id/cancelar` (Cancelar e Reembolsar)

Cancela um voucher pendente e devolve integralmente as moedas para a carteira do aluno.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/resgates/1/cancelar`
* **Headers:**
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`
* **Body:** Vazio ou `{}`.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "id": 1,
  "status": "Cancelado",
  "txHash": "0xaa12bc34de56fa780912bcde349012ca981230491823abce891023cd891023bc",
  "blockNumber": 165595
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/resgates/1/cancelar \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1"
```

---

### 3.9. `POST /api/v1/resgates/:id/expirar` (Expirar Voucher)

Executa a devolução das moedas ao aluno quando a validade (`expiraEm`) foi ultrapassada.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/resgates/1/expirar`
* **Headers:**
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`
* **Body:** Vazio ou `{}`.

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "id": 1,
  "status": "Expirado",
  "txHash": "0xbb9876543210fedcba0987654321fedcba0987654321fedcba0987654321fedc",
  "blockNumber": 165600
}
```

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/resgates/1/expirar \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1"
```

---

### 3.10. `POST /api/v1/rpc` (Proxy JSON-RPC Nativo Ethereum)

Permite executar qualquer chamada padrão JSON-RPC contra o nó Hyperledger Besu sem expor portas diretas da blockchain.

* **Método:** `POST`
* **URL:** `http://129.146.55.236:8546/api/v1/rpc`
* **Headers:**
  * `Content-Type: application/json`
  * `X-API-KEY: wyden-rpc-sec-9a8f27b4e1`

#### JSON da Requisição (Request Payload):
```json
{
  "method": "eth_blockNumber",
  "params": []
}
```

#### Exemplo de Resposta JSON (`200 OK`):
```json
{
  "success": true,
  "result": "0x286c9"
}
```
*(Para converter o bloco `0x286c9` em decimal: `parseInt("0x286c9", 16) = 165577`)*

#### Exemplo cURL:
```bash
curl -X POST http://129.146.55.236:8546/api/v1/rpc \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: wyden-rpc-sec-9a8f27b4e1" \
  -d '{
    "method": "eth_blockNumber",
    "params": []
  }'
```

---

## 🔮 4. Chamadas JSON-RPC Úteis via `POST /api/v1/rpc`

Você pode enviar qualquer método padrão da especificação Ethereum JSON-RPC:

| Objetivo | Payload JSON a enviar |
| :--- | :--- |
| **Bloco Atual** | `{"method": "eth_blockNumber", "params": []}` |
| **Recibo de Transação** | `{"method": "eth_getTransactionReceipt", "params": ["0xTxHash..."]}` |
| **Detalhes do Bloco** | `{"method": "eth_getBlockByNumber", "params": ["latest", false]}` |
| **Quantidade de Peers** | `{"method": "net_peerCount", "params": []}` |
| **Chain ID da Rede** | `{"method": "eth_chainId", "params": []}` |

---

## ⚠️ 5. Padrão de Erros HTTP e Estrutura JSON de Resposta

Caso ocorra qualquer erro de parâmetro, chave de API inválida ou erro on-chain, o Gateway responde com formato JSON padronizado:

```json
{
  "success": false,
  "error": "Descrição detalhada do motivo do erro"
}
```

### Códigos de Status HTTP Retornados:

| Status HTTP | Causa | Exemplo de JSON de Erro |
| :---: | :--- | :--- |
| **`400 Bad Request`** | Parâmetro inválido ou ausente | `{"success": false, "error": "Endereco de aluno invalido: 0x123"}` |
| **`401 Unauthorized`** | Token `X-API-KEY` ausente ou incorreto | `{"success": false, "error": "Acesso nao autorizado. Header X-API-KEY ou Bearer token invalido."}` |
| **`404 Not Found`** | Rota ou ID inexistente | `{"success": false, "error": "Rota nao encontrada: POST /api/v1/rota-errada"}` |
| **`500 Internal Error`**| Reversão de contrato ou falha no Besu | `{"success": false, "error": "execution reverted: Saldo insuficiente"}` |

---

## 💻 6. Exemplos de Envio de JSON em Diferentes Linguagens

### Exemplo 1: JavaScript Nativo (`fetch`)
```javascript
const resposta = await fetch("http://129.146.55.236:8546/api/v1/recompensas/mint", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-API-KEY": "wyden-rpc-sec-9a8f27b4e1"
  },
  body: JSON.stringify({
    aluno: "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
    valor: 10,
    motivo: "SIA_15D"
  })
});

const dados = await resposta.json();
console.log("TxHash retornado:", dados.txHash);
```

### Exemplo 2: Python (`requests`)
```python
import requests

url = "http://129.146.55.236:8546/api/v1/recompensas/mint"
headers = {
    "Content-Type": "application/json",
    "X-API-KEY": "wyden-rpc-sec-9a8f27b4e1"
}
payload = {
    "aluno": "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73",
    "valor": 10,
    "motivo": "SIA_15D"
}

response = requests.post(url, json=payload, headers=headers)
print(response.json())
```

### Exemplo 3: Dart / Flutter (`http`)
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> emitirMoeda() async {
  final url = Uri.parse('http://129.146.55.236:8546/api/v1/recompensas/mint');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'X-API-KEY': 'wyden-rpc-sec-9a8f27b4e1',
    },
    body: jsonEncode({
      'aluno': '0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73',
      'valor': 10,
      'motivo': 'SIA_15D',
    }),
  );

  print(jsonDecode(response.body));
}
```

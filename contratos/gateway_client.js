/**
 * ==============================================================================
 * Wydencoin Blockchain Gateway - Cliente & Documentacao Executavel (Node.js)
 * ==============================================================================
 *
 * Este arquivo serve como referencia tecnica e cliente pronto para uso pelas equipes
 * de Backend (Luiz Felipe e Henrique) para integrar a API Geral do WydenCoin com a
 * blockchain Hyperledger Besu através do RPC Gateway seguro.
 *
 * Requisitos:
 *   - Node.js v18+ (usa o fetch nativo, sem necessidade de dependencias externas).
 *
 * Como testar este arquivo diretamente:
 *   $ node gateway_client.js
 *
 * ==============================================================================
 */

const GATEWAY_URL = process.env.BLOCKCHAIN_GATEWAY_URL || "http://wydencoin-rpc.duckdns.org:8546";
const API_KEY = process.env.BLOCKCHAIN_GATEWAY_TOKEN || "wyden-rpc-sec-9a8f27b4e1";

/**
 * Classe cliente que encapsula todas as operacoes do Gateway Blockchain.
 */
class WydencoinGatewayClient {
  /**
   * @param {string} baseUrl - URL base do gateway (ex: http://wydencoin-rpc.duckdns.org:8546)
   * @param {string} apiKey  - Token secreto de autenticacao do header X-API-KEY
   */
  constructor(baseUrl = GATEWAY_URL, apiKey = API_KEY) {
    this.baseUrl = baseUrl.replace(/\/$/, "");
    this.apiKey = apiKey;
  }

  /**
   * Metodo interno utilitario para envio de requisicoes HTTP padronizadas.
   * @private
   */
  async _request(endpoint, options = {}) {
    const url = `${this.baseUrl}${endpoint}`;
    const headers = {
      "Content-Type": "application/json",
      ...(this.apiKey ? { "X-API-KEY": this.apiKey } : {}),
      ...(options.headers || {})
    };

    const config = {
      method: options.method || "GET",
      headers,
      ...(options.body ? { body: JSON.stringify(options.body) } : {})
    };

    const response = await fetch(url, config);
    const data = await response.json().catch(() => null);

    if (!response.ok) {
      const msg = (data && data.error) || `Erro HTTP ${response.status}: ${response.statusText}`;
      throw new Error(msg);
    }

    return data;
  }

  // ============================================================================
  // 1. MONITORAMENTO & SAUDE DA REDE
  // ============================================================================

  /**
   * Consulta a saude geral da rede Besu e o estado dos contratos inteligentes.
   * Rota publica: nao exige envio de token.
   *
   * @returns {Promise<{
   *   status: string,
   *   network: { chainId: number, blockNumber: number, peers: number, syncing: boolean },
   *   contracts: { wydenCoin: string, redemptionManager: string },
   *   timestamp: string
   * }>}
   */
  async getHealth() {
    return this._request("/health");
  }

  // ============================================================================
  // 2. TOKEN WYDENCOIN (WC) & SALDO
  // ============================================================================

  /**
   * Consulta o saldo disponivel de WydenCoins (WC) de uma carteira de aluno.
   * Operacao de leitura pura (view), rapida e sem custo de gas.
   *
   * @param {string} alunoAddress - Endereco hexadecimal da carteira (0x...)
   * @returns {Promise<{ success: boolean, aluno: string, saldo: number, unidade: string }>}
   */
  async getSaldo(alunoAddress) {
    if (!alunoAddress) {
      throw new Error("Endereco do aluno e obrigatorio.");
    }
    return this._request(`/api/v1/saldo/${alunoAddress}`);
  }

  /**
   * Emite moedas (mint) para um aluno individual com base em um motivo pedagogico.
   * Requer autenticacao. Assinado internamente com a role MINTER_ROLE.
   *
   * @param {string} alunoAddress - Carteira de destino (0x...)
   * @param {number} valor        - Quantidade inteira de WydenCoins
   * @param {string} motivo       - Codigo do motivo (Ex: 'SIA_15D', 'PRES_15D', 'SIMULADO')
   * @returns {Promise<{ success: boolean, txHash: string, blockNumber: number, aluno: string, valor: number, motivo: string }>}
   */
  async emitirRecompensa(alunoAddress, valor, motivo) {
    if (!alunoAddress || !valor || valor <= 0) {
      throw new Error("Dados invalidos: informe aluno e valor positivo.");
    }

    return this._request("/api/v1/recompensas/mint", {
      method: "POST",
      body: {
        aluno: alunoAddress,
        valor: Number(valor),
        motivo: motivo || "RECOMPENSA"
      }
    });
  }

  /**
   * Emissao em lote quinzenal (batch mint) atomica em uma unica transacao on-chain.
   * Ideal para o processamento automatizado de fechamento quinzenal de notas/frequencia.
   *
   * @param {Array<{ aluno: string, valor: number, motivo: string }>} itens - Lista de premiacoes
   * @returns {Promise<{ success: boolean, totalItens: number, txHash: string, blockNumber: number }>}
   */
  async emitirLoteRecompensas(itens) {
    if (!Array.isArray(itens) || itens.length === 0) {
      throw new Error("A lista de itens para lote nao pode ser vazia.");
    }

    return this._request("/api/v1/recompensas/mint-batch", {
      method: "POST",
      body: { itens }
    });
  }

  // ============================================================================
  // 3. CICLO DE VIDA DE RESGATES (REDEMPTION MANAGER)
  // ============================================================================

  /**
   * Registra a solicitacao de resgate de um beneficio pelo aluno.
   * Transfere os tokens da carteira do aluno para a custodia temporaria do contrato.
   *
   * @param {string} alunoPrivateKey - Chave privada da carteira do aluno (para assinar a custodia)
   * @param {number} beneficioId     - ID do produto/beneficio no banco de dados da aplicacao
   * @param {number} valor           - Preco em WydenCoins
   * @param {number} [horasValidade=24] - Prazo para expiracao do voucher em horas
   * @returns {Promise<{ success: boolean, idResgate: number, beneficioId: number, valor: number, expiraEm: number, txHash: string }>}
   */
  async solicitarResgate(alunoPrivateKey, beneficioId, valor, horasValidade = 24) {
    if (!alunoPrivateKey || !beneficioId || !valor) {
      throw new Error("Chave do aluno, beneficioId e valor sao obrigatorios.");
    }

    return this._request("/api/v1/resgates", {
      method: "POST",
      body: {
        alunoPrivateKey,
        beneficioId: Number(beneficioId),
        valor: Number(valor),
        horasValidade: Number(horasValidade)
      }
    });
  }

  /**
   * Consulta os detalhes e o status on-chain atual de um resgate/voucher.
   *
   * @param {number} id - Identificador unico do resgate gerado on-chain
   * @returns {Promise<{
   *   success: boolean,
   *   id: number,
   *   aluno: string,
   *   beneficioId: number,
   *   valor: number,
   *   expiraEm: number,
   *   status: 'Resgatado' | 'Utilizado' | 'Cancelado' | 'Expirado',
   *   statusCode: number
   * }>}
   */
  async consultarResgate(id) {
    if (!id) throw new Error("ID do resgate e obrigatorio.");
    return this._request(`/api/v1/resgates/${id}`);
  }

  /**
   * Valida presencialmente o voucher na cantina ou sessao de mentoria.
   * Queima permanentemente as moedas custodiadas (CONFIRMER_ROLE).
   *
   * @param {number} id - ID do resgate on-chain
   * @returns {Promise<{ success: boolean, id: number, status: 'Utilizado', txHash: string, blockNumber: number }>}
   */
  async confirmarUsoVoucher(id) {
    if (!id) throw new Error("ID do resgate e obrigatorio.");
    return this._request(`/api/v1/resgates/${id}/confirmar`, { method: "POST" });
  }

  /**
   * Cancela manualmente um voucher pendente e devolve o saldo integral ao aluno (MANAGER_ROLE).
   *
   * @param {number} id - ID do resgate on-chain
   * @returns {Promise<{ success: boolean, id: number, status: 'Cancelado', txHash: string, blockNumber: number }>}
   */
  async cancelarVoucher(id) {
    if (!id) throw new Error("ID do resgate e obrigatorio.");
    return this._request(`/api/v1/resgates/${id}/cancelar`, { method: "POST" });
  }

  /**
   * Processa a expiracao de um voucher cujo prazo ja foi ultrapassado (MANAGER_ROLE).
   * Devolve as moedas para a carteira do aluno. Ideal para rotinas cron do backend.
   *
   * @param {number} id - ID do resgate on-chain
   * @returns {Promise<{ success: boolean, id: number, status: 'Expirado', txHash: string, blockNumber: number }>}
   */
  async expirarVoucher(id) {
    if (!id) throw new Error("ID do resgate e obrigatorio.");
    return this._request(`/api/v1/resgates/${id}/expirar`, { method: "POST" });
  }

  // ============================================================================
  // 4. PASSTHROUGH RPC BRUTO (AVANCADO)
  // ============================================================================

  /**
   * Executa qualquer metodo padrao Ethereum JSON-RPC atraves da conexao segura do gateway.
   *
   * @param {string} method - Nome do metodo (Ex: 'eth_blockNumber', 'eth_getTransactionReceipt')
   * @param {Array}  [params=[]] - Parametros do metodo
   * @returns {Promise<{ success: boolean, result: any }>}
   */
  async chamadaRpcBruta(method, params = []) {
    return this._request("/api/v1/rpc", {
      method: "POST",
      body: { method, params }
    });
  }
}

// ==============================================================================
// DEMONSTRACAO / EXEMPLO EXECUTAVEL
// ==============================================================================

async function main() {
  console.log("==================================================================");
  console.log("Iniciando teste de integracao com o Wydencoin RPC Gateway...");
  console.log(`Endpoint: ${GATEWAY_URL}`);
  console.log("==================================================================\n");

  const client = new WydencoinGatewayClient(GATEWAY_URL, API_KEY);

  // 1. Validar conexao e saude da rede
  console.log("-> 1. Testando GET /health...");
  const saude = await client.getHealth();
  console.log("Status:", saude.status);
  console.log(`Chain ID: ${saude.network.chainId} | Bloco Atual: ${saude.network.blockNumber} | Peers: ${saude.network.peers}`);
  console.log("Contrato WC:", saude.contracts.wydenCoin);

  // 2. Consulta de Saldo de um Aluno
  const alunoExemplo = "0xFE3B557E8Fb62b89F4916B721be55cEb828dBd73";
  console.log(`\n-> 2. Testando GET /api/v1/saldo/${alunoExemplo}...`);
  const saldoAntes = await client.getSaldo(alunoExemplo);
  console.log(`Saldo inicial: ${saldoAntes.saldo} ${saldoAntes.unidade}`);

  // 3. Emissao de Moedas Individual (Mint)
  console.log("\n-> 3. Testando POST /api/v1/recompensas/mint...");
  const mintResult = await client.emitirRecompensa(alunoExemplo, 10, "SIA_15D");
  console.log(`[OK] ${mintResult.valor} WC emitidos para ${mintResult.aluno}`);
  console.log(`TxHash: ${mintResult.txHash} (Bloco #${mintResult.blockNumber})`);

  // 4. Confirmar saldo atualizado
  const saldoDepois = await client.getSaldo(alunoExemplo);
  console.log(`Saldo atualizado: ${saldoDepois.saldo} ${saldoDepois.unidade} (+10 WC)`);

  // 5. Teste de Passthrough RPC Bruto
  console.log("\n-> 4. Testando POST /api/v1/rpc (eth_blockNumber)...");
  const rpcResult = await client.chamadaRpcBruta("eth_blockNumber", []);
  console.log(`Bloco retornado via RPC: ${parseInt(rpcResult.result, 16)} (${rpcResult.result})`);

  console.log("\n==================================================================");
  console.log("Todos os testes do cliente foram executados com sucesso!");
  console.log("==================================================================");
}

// Exporta a classe para ser importada como modulo no backend da aplicacao:
// const { WydencoinGatewayClient } = require('./gateway_client');
module.exports = {
  WydencoinGatewayClient,
  GATEWAY_URL,
  API_KEY
};

// Executa a demonstracao caso o script seja chamado diretamente via terminal
if (require.main === module) {
  main().catch((erro) => {
    console.error("\n[FALHA NO CLIENTE]:", erro.message);
    process.exit(1);
  });
}

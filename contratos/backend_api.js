const { ethers } = require('ethers');

// ==========================================
// 1. Configurações de Conexão e Variáveis
// ==========================================

// Endpoint JSON-RPC da rede Hyperledger Besu
const RPC_URL = "http://127.0.0.1:8545";

// Provedor JSON-RPC para comunicação de leitura e escrita com a blockchain Besu
const provider = new ethers.JsonRpcProvider(RPC_URL);

// Chave privada da conta administradora (detentora das roles DEFAULT_ADMIN, MINTER, MANAGER e CONFIRMER)
const ADMIN_PRIVATE_KEY = "8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";

// Wallet do Administrador conectada ao provedor
const adminWallet = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);

// Endereços dos contratos previamente publicados na rede
const WYDENCOIN_ADDRESS = "0x42699A7612A82f1d9C36148af9C77354759b210b";
const REDEMPTION_MANAGER_ADDRESS = "0xa50a51c09a5c451C52BB714527E1974b686D8e77";

// Definições de ABI (Application Binary Interface) para interface com os contratos
const WYDENCOIN_ABI = [
    "function mintReward(address aluno, uint256 valor, bytes32 motivo) external",
    "function approve(address spender, uint256 value) returns (bool)",
    "function balanceOf(address account) view returns (uint256)"
];

const REDEMPTION_MANAGER_ABI = [
    "function resgatar(uint256 beneficioId, uint256 valor, uint64 expiraEm) external returns (uint256 id)",
    "function confirmarUso(uint256 id) external",
    "function cancelar(uint256 id) external",
    "function expirar(uint256 id) external",
    "event ResgateCriado(uint256 indexed id, address indexed aluno, uint256 beneficioId, uint256 valor, uint64 expiraEm)"
];

// Instâncias dos Contratos Conectadas à Wallet do Administrador (para operações administrativas)
const wydenCoinAdmin = new ethers.Contract(WYDENCOIN_ADDRESS, WYDENCOIN_ABI, adminWallet);
const redemptionManagerAdmin = new ethers.Contract(REDEMPTION_MANAGER_ADDRESS, REDEMPTION_MANAGER_ABI, adminWallet);


/**
 * Consulta de Saldo de Aluno
 * Operação de leitura (call / view) sem custo de gas ou alteração de estado global.
 */
async function exemploLerSaldo(alunoAddress) {
    const saldo = await wydenCoinAdmin.balanceOf(alunoAddress);
    console.log(`Saldo do aluno: ${saldo.toString()} WC`);
}

/**
 * Emissão de Tokens (Mint)
 * Transação de escrita on-chain executada por conta autorizada (MINTER_ROLE).
 */
async function exemploMintarMoedas(alunoAddress, valor) {
    try {
        const motivoBytes = ethers.encodeBytes32String("PRESENCA_SIA");
        
        // Submete a transação à rede
        const tx = await wydenCoinAdmin.mintReward(alunoAddress, valor, motivoBytes);
        console.log(`Submetendo transação... Hash: ${tx.hash}`);

        // Aguarda a confirmação da transação em um bloco minerado
        const receipt = await tx.wait();
        
        console.log("Transação confirmada no bloco:", receipt.blockNumber);
        console.log("Tokens emitidos com sucesso.");

    } catch (erro) {
        console.error("Erro na emissão de tokens:", erro.message);
    }
}

/**
 * Solicitação de Resgate de Benefício
 * Operação de retenção/custódia de tokens assinada pelo solicitante.
 */
async function exemploResgatarBeneficio(alunoPrivateKey, beneficioId, valorWC, horasParaExpirar) {
    try {
        // Inicializa a carteira do aluno
        const alunoWallet = new ethers.Wallet(alunoPrivateKey, provider);
        
        // Instancia o contrato conectado ao signatário solicitante
        const redemptionManagerAluno = new ethers.Contract(REDEMPTION_MANAGER_ADDRESS, REDEMPTION_MANAGER_ABI, alunoWallet);

        // Define o prazo de validade em timestamp Unix (segundos)
        const expiraEm = Math.floor(Date.now() / 1000) + (horasParaExpirar * 3600);

        // Submete a transação de resgate
        const tx = await redemptionManagerAluno.resgatar(beneficioId, valorWC, expiraEm);
        const receipt = await tx.wait();

        console.log("Resgate criado. Hash da transação:", receipt.hash);

        // Captura do identificador único do resgate a partir do evento ResgateCriado
        for (const log of receipt.logs) {
            try {
                const parsedLog = redemptionManagerAluno.interface.parseLog(log);
                if (parsedLog.name === "ResgateCriado") {
                    const idResgateGerado = parsedLog.args[0].toString();
                    console.log(`Identificador do resgate registrado on-chain: ${idResgateGerado}`);
                }
            } catch (e) {
                // Log não correspondente ao evento esperado
            }
        }
    } catch (erro) {
         console.error("Erro ao registrar resgate:", erro.message);
    }
}

/**
 * Operações de Gestão do Ciclo de Vida do Resgate
 * Executadas pelas contas detentoras das roles CONFIRMER_ROLE ou MANAGER_ROLE.
 */
async function exemploGerenciamentoVoucher(idBlockchain) {
    // Confirmação de uso e queima de tokens (requer CONFIRMER_ROLE)
    const txConfirm = await redemptionManagerAdmin.confirmarUso(idBlockchain);
    await txConfirm.wait();
    console.log("Uso confirmado e tokens queimados.");

    // Cancelamento da solicitação e devolução de saldo ao aluno (requer MANAGER_ROLE)
    const txCancel = await redemptionManagerAdmin.cancelar(idBlockchain);
    await txCancel.wait();
    console.log("Resgate cancelado e saldo restituído ao aluno.");

    // Expiração por decurso de prazo e restituição de saldo (requer MANAGER_ROLE)
    const txExpire = await redemptionManagerAdmin.expirar(idBlockchain);
    await txExpire.wait();
    console.log("Prazo expirado e saldo restituído ao aluno.");
}


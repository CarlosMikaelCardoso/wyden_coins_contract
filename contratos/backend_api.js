const { ethers } = require('ethers');

// ==========================================
// 1. Configurações de Conexão e Variáveis
// ==========================================

// URL de conexão com a rede Hyperledger Besu (RPC local do Jmeter ou rede configurada)
const RPC_URL = "http://127.0.0.1:8545";

// Instanciamos o provedor (Provider) que fará a comunicação de leitura/escrita com o Besu
const provider = new ethers.JsonRpcProvider(RPC_URL);

// Chave privada do Administrador (O mesmo que fez o deploy e possui as MINTER/MANAGER/CONFIRMER Roles)
const ADMIN_PRIVATE_KEY = "8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";

// Wallet do Administrador conectada ao provedor
const adminWallet = new ethers.Wallet(ADMIN_PRIVATE_KEY, provider);

// Endereços dos contratos previamente publicados na rede
const WYDENCOIN_ADDRESS = "0x42699A7612A82f1d9C36148af9C77354759b210b";
const REDEMPTION_MANAGER_ADDRESS = "0xa50a51c09a5c451C52BB714527E1974b686D8e77";

// ABIs (Application Binary Interface) - Explicam para o Javascript como os contratos funcionam
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
 * EXEMPLO 1: Ler o saldo do aluno
 * Como a leitura (view) não gasta taxa de transação e não altera estado, 
 * ela é muito rápida e só retorna o valor na mesma hora.
 */
async function exemploLerSaldo(alunoAddress) {
    const saldo = await wydenCoinAdmin.balanceOf(alunoAddress);
    console.log(`O saldo do aluno é: ${saldo.toString()} WC`);
}

/**
 * EXEMPLO 2: Dar moedas a um aluno (MINT)
 * Isso é uma transação de escrita, logo, precisamos enviá-la e aguardar ela 
 * ser processada e inserida em um bloco da rede (wait).
 */
async function exemploMintarMoedas(alunoAddress, valor) {
    try {
        // O motivo deve ser um identificador curto. Precisa ser codificado em bytes32.
        const motivoBytes = ethers.encodeBytes32String("PRESENCA_SIA");
        
        // Dispara a transação (usando a wallet que tem a MINTER_ROLE)
        const tx = await wydenCoinAdmin.mintReward(alunoAddress, valor, motivoBytes);
        console.log(`Enviando transação... Hash: ${tx.hash}`);

        // Espera a transação ser confirmada na blockchain
        const receipt = await tx.wait();
        
        console.log("Transação confirmada no bloco:", receipt.blockNumber);
        console.log("Moedas foram geradas com sucesso para o aluno!");

    } catch (erro) {
        console.error("Erro ao mintar moedas:", erro.message);
    }
}

/**
 * EXEMPLO 3: Fazer o aluno Comprar/Resgatar um benefício (Cria retenção)
 * Como o Resgate retira as moedas da conta do aluno, precisamos assinar 
 * a transação usando a chave privada daquele aluno específico.
 */
async function exemploResgatarBeneficio(alunoPrivateKey, beneficioId, valorWC, horasParaExpirar) {
    try {
        // Conecta a carteira do aluno na blockchain (Custodial Wallet controlada pelo backend)
        const alunoWallet = new ethers.Wallet(alunoPrivateKey, provider);
        
        // Instancia o contrato como se nós fossemos o aluno
        const redemptionManagerAluno = new ethers.Contract(REDEMPTION_MANAGER_ADDRESS, REDEMPTION_MANAGER_ABI, alunoWallet);

        // Gera timestamp de validade (em segundos Unix)
        const expiraEm = Math.floor(Date.now() / 1000) + (horasParaExpirar * 3600);

        // Chama a função
        const tx = await redemptionManagerAluno.resgatar(beneficioId, valorWC, expiraEm);
        const receipt = await tx.wait();

        console.log("Resgate criado! Transação Hash:", receipt.hash);

        // [OPCIONAL] Capturando o ID do resgate lendo o evento emitido pelo contrato
        for (const log of receipt.logs) {
            try {
                const parsedLog = redemptionManagerAluno.interface.parseLog(log);
                if (parsedLog.name === "ResgateCriado") {
                    const idResgateGerado = parsedLog.args[0].toString(); // args[0] é o 'id'
                    console.log(`Salve no banco de dados o ID do resgate na blockchain: ${idResgateGerado}`);
                }
            } catch (e) {
                // Esse log pode não ser do evento que queremos, então ignoramos
            }
        }
    } catch (erro) {
         console.error("Erro ao criar resgate:", erro.message);
    }
}

/**
 * EXEMPLO 4: Rotina de Gerenciamento do Admin
 * Usar essas funções quando a cantina aprovar o pedido, ou a API cancelar/expirar.
 */
async function exemploGerenciamentoVoucher(idBlockchain) {
    // 4.1 Confirmar Uso (Queima moedas). Deve ser executado pela conta com CONFIRMER_ROLE
    const txConfirm = await redemptionManagerAdmin.confirmarUso(idBlockchain);
    await txConfirm.wait();
    console.log("Uso confirmado e moedas queimadas!");

    // 4.2 Cancelar Compra (Estorna para aluno). Exige conta com MANAGER_ROLE
    const txCancel = await redemptionManagerAdmin.cancelar(idBlockchain);
    await txCancel.wait();
    console.log("Compra cancelada e valor estornado!");

    // 4.3 Expirar (Estorna para aluno). Exige conta com MANAGER_ROLE
    // Geralmente deve ser chamado num script agendado do servidor que roda diariamente
    const txExpire = await redemptionManagerAdmin.expirar(idBlockchain);
    await txExpire.wait();
    console.log("Validade vencida. Valor estornado ao aluno!");
}


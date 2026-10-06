const express = require('express');
const { ethers } = require('ethers');

// Instanciação do aplicativo Express
const app = express();
app.use(express.json());

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
    "function approve(address spender, uint256 value) returns (bool)"
];

const REDEMPTION_MANAGER_ABI = [
    "function resgatar(uint256 beneficioId, uint256 valor, uint64 expiraEm) external returns (uint256 id)",
    "function confirmarUso(uint256 id) external",
    "function cancelar(uint256 id) external",
    "function expirar(uint256 id) external"
];

// Instâncias dos Contratos Conectadas à Wallet do Administrador (para operações administrativas)
const wydenCoinAdmin = new ethers.Contract(WYDENCOIN_ADDRESS, WYDENCOIN_ABI, adminWallet);  
const redemptionManagerAdmin = new ethers.Contract(REDEMPTION_MANAGER_ADDRESS, REDEMPTION_MANAGER_ABI, adminWallet);


// ==========================================
// 2. Rotas da API e Funções do Contrato
// ==========================================

/**
 * ROTA: Dar Moedas ao Aluno (MINT)
 * Explicação: Somente o administrador (com MINTER_ROLE) pode chamar essa função.
 * Ela "imprime" novas moedas diretamente na carteira do aluno baseada num motivo (ex: "PRESENCA_100").
 */
app.post('/api/alunos/recompensar', async (req, res) => {
    try {
        const { alunoEndereco, valor, motivoString } = req.body;

        // Converte a string de motivo (ex: "PROJETO_A") para o formato bytes32 exigido pelo Solidity
        const motivoBytes32 = ethers.encodeBytes32String(motivoString);

        // Chama a função mintReward no contrato WydenCoin
        // Variáveis:
        // alunoEndereco: Para quem vai a moeda
        // valor: Quantidade (1 = 1 WC)
        // motivoBytes32: O código do ganho convertido para bytes
        const tx = await wydenCoinAdmin.mintReward(alunoEndereco, valor, motivoBytes32);
        
        // Aguarda a transação ser minerada em um bloco na rede
        const receipt = await tx.wait();

        res.json({ success: true, transactionHash: receipt.hash, message: "Moedas creditadas!" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * ROTA: Criar um Resgate (Comprar Benefício)
 * Explicação: Esta função simula a ação do aluno. Como os alunos não têm Ether (gas) na rede privada,
 * o backend precisa assinar a transação usando a chave privada do aluno (Custodial Wallet).
 */
app.post('/api/alunos/resgatar', async (req, res) => {
    try {
        const { alunoPrivateKey, beneficioId, valor, horasValidade } = req.body;

        // 1. Criar a instância da carteira do aluno conectada ao provedor
        const alunoWallet = new ethers.Wallet(alunoPrivateKey, provider);

        // 2. Conectar o contrato RedemptionManager usando a carteira do ALUNO 
        // (pois o msg.sender lá no contrato precisa ser o aluno pagador)
        const redemptionManagerAluno = new ethers.Contract(REDEMPTION_MANAGER_ADDRESS, REDEMPTION_MANAGER_ABI, alunoWallet);

        // Variável expiraEm: Timestamp unix de quando o voucher vence
        const expiraEm = Math.floor(Date.now() / 1000) + (horasValidade * 3600);

        // Chama a função resgatar. Isso vai puxar as moedas do aluno para o contrato.
        const tx = await redemptionManagerAluno.resgatar(beneficioId, valor, expiraEm);
        const receipt = await tx.wait();

        res.json({ success: true, transactionHash: receipt.hash, message: "Resgate criado e saldo retido!" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * ROTA: Confirmar Uso do Voucher (Cantina / Mentor)
 * Explicação: Quando o aluno apresenta o Voucher, a cantina chama esta rota.
 * O Backend assina com a carteira Admin (que tem CONFIRMER_ROLE) e chama confirmarUso.
 * O contrato então queima definitivamente as moedas retidas.
 */
app.post('/api/resgates/confirmar', async (req, res) => {
    try {
        // idBlockchain é o ID do resgate que foi gerado lá no Solidity
        const { idBlockchain } = req.body;

        const tx = await redemptionManagerAdmin.confirmarUso(idBlockchain);
        const receipt = await tx.wait();

        res.json({ success: true, transactionHash: receipt.hash, message: "Uso confirmado, moedas queimadas!" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * ROTA: Cancelar / Estornar um Resgate
 * Explicação: Se ocorreu algum erro no pedido, o Admin (MANAGER_ROLE) cancela.
 * As moedas voltam automaticamente da custódia do contrato para o aluno.
 */
app.post('/api/resgates/cancelar', async (req, res) => {
    try {
        const { idBlockchain } = req.body;

        const tx = await redemptionManagerAdmin.cancelar(idBlockchain);
        const receipt = await tx.wait();

        res.json({ success: true, transactionHash: receipt.hash, message: "Resgate cancelado, saldo devolvido!" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * ROTA CRON: Expirar Resgates Vencidos
 * Explicação: Um job do Backend chama essa função diariamente para expirar pedidos velhos.
 * As moedas retidas voltam para a carteira do aluno.
 */
app.post('/api/resgates/expirar', async (req, res) => {
    try {
        const { idBlockchain } = req.body;

        const tx = await redemptionManagerAdmin.expirar(idBlockchain);
        const receipt = await tx.wait();

        res.json({ success: true, transactionHash: receipt.hash, message: "Resgate expirado, saldo devolvido!" });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

// Inicialização do Servidor
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Servidor de Integração WydenCoin rodando na porta ${PORT}`);
});

const fs = require('fs');
const ethers = require('ethers');

const RPC_URL = "http://127.0.0.1:8545";
const provider = new ethers.JsonRpcProvider(RPC_URL);

const PRIVATE_KEY = "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

async function main() {
    console.log("Iniciando o deploy da arquitetura WydenCoin...\n");

    console.log("-> Fazendo deploy do WydenCoin...");
    const wcAbi = JSON.parse(fs.readFileSync('./build/WydenCoin.abi', 'utf8'));
    const wcBin = fs.readFileSync('./build/WydenCoin.bin', 'utf8');
    const WCFactory = new ethers.ContractFactory(wcAbi, wcBin, wallet);
    const wcContract = await WCFactory.deploy();
    await wcContract.waitForDeployment();
    const wcAddress = await wcContract.getAddress();
    console.log(`[+] WydenCoin (WC) publicado no endereço: ${wcAddress}`);

    console.log("\n-> Fazendo deploy do RedemptionManager...");
    const rmAbi = JSON.parse(fs.readFileSync('./build/RedemptionManager.abi', 'utf8'));
    const rmBin = fs.readFileSync('./build/RedemptionManager.bin', 'utf8');
    const RMFactory = new ethers.ContractFactory(rmAbi, rmBin, wallet);
    const rmContract = await RMFactory.deploy(wcAddress);
    await rmContract.waitForDeployment();
    const rmAddress = await rmContract.getAddress();
    console.log(`[+] RedemptionManager publicado no endereço: ${rmAddress}`);

    console.log("\n-> Configurando permissões no contrato...");
    const tx1 = await wcContract.setRedemptionManager(rmAddress);
    await tx1.wait();
    console.log(`[OK] RedemptionManager autorizado no contrato WydenCoin.`);

    const MINTER_ROLE = await wcContract.MINTER_ROLE();
    const tx2 = await wcContract.grantRole(MINTER_ROLE, wallet.address);
    await tx2.wait();
    console.log(`[OK] MINTER_ROLE concedida ao administrador.`);

    const CONFIRMER_ROLE = await rmContract.CONFIRMER_ROLE();
    const MANAGER_ROLE = await rmContract.MANAGER_ROLE();
    await (await rmContract.grantRole(CONFIRMER_ROLE, wallet.address)).wait();
    await (await rmContract.grantRole(MANAGER_ROLE, wallet.address)).wait();
    console.log(`[OK] CONFIRMER_ROLE e MANAGER_ROLE concedidas ao administrador.`);

    console.log("\n-> Dando Approve infinito no token para o RedemptionManager...");
    await (await wcContract.approve(rmAddress, ethers.MaxUint256)).wait();
    console.log("[OK] Approve concedido!");

    console.log("\nDeploy finalizado com sucesso!");
    const addrs = {
        WydenCoin: wcAddress,
        RedemptionManager: rmAddress
    };
    fs.writeFileSync('addresses.json', JSON.stringify(addrs, null, 2));
    console.log("Endereços salvos em addresses.json");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

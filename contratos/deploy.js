const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

async function main() {
    const rpcUrl = process.env.BESU_RPC_URL || 'http://127.0.0.1:8545';
    // Chave padrão usada no script de setup do Besu (EXTERNAL_DEPLOY_ACCOUNT)
    const privateKey = process.env.BESU_DEPLOYER_PRIVATE_KEY || '8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63';
    
    const buildPath = path.join(__dirname, 'build');
    
    // Ler artefatos do FaciCoin (MeuToken)
    const tokenAbi = JSON.parse(fs.readFileSync(path.join(buildPath, 'MeuToken.abi'), 'utf8'));
    const tokenBytecode = fs.readFileSync(path.join(buildPath, 'MeuToken.bin'), 'utf8');

    // Ler artefatos do MarketplaceFacicoin
    const marketAbi = JSON.parse(fs.readFileSync(path.join(buildPath, 'MarketplaceFacicoin.abi'), 'utf8'));
    const marketBytecode = fs.readFileSync(path.join(buildPath, 'MarketplaceFacicoin.bin'), 'utf8');

    // Ler artefatos do ReciclagemFacicoin
    const reciclagemAbi = JSON.parse(fs.readFileSync(path.join(buildPath, 'ReciclagemFacicoin.abi'), 'utf8'));
    const reciclagemBytecode = fs.readFileSync(path.join(buildPath, 'ReciclagemFacicoin.bin'), 'utf8');
    
    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const wallet = new ethers.Wallet(privateKey, provider);
    
    console.log("-----------------------------------------");
    console.log("Fazendo deploy do FaciCoin (MeuToken)...");
    const tokenFactory = new ethers.ContractFactory(tokenAbi, tokenBytecode, wallet);
    
    // Inicializar com 1 Milhão de moedas (18 decimais)
    const initialSupply = ethers.parseUnits("1000000", 18);
    const tokenContract = await tokenFactory.deploy(initialSupply);
    await tokenContract.waitForDeployment();
    
    const tokenAddress = await tokenContract.getAddress();
    console.log("FaciCoin deployado em:", tokenAddress);

    console.log("-----------------------------------------");
    console.log("Fazendo deploy do MarketplaceFacicoin...");
    const marketFactory = new ethers.ContractFactory(marketAbi, marketBytecode, wallet);
    const marketContract = await marketFactory.deploy(tokenAddress);
    await marketContract.waitForDeployment();

    const marketAddress = await marketContract.getAddress();
    console.log("MarketplaceFacicoin deployado em:", marketAddress);

    console.log("-----------------------------------------");
    console.log("Fazendo deploy do ReciclagemFacicoin...");
    const reciclagemFactory = new ethers.ContractFactory(reciclagemAbi, reciclagemBytecode, wallet);
    const reciclagemContract = await reciclagemFactory.deploy(tokenAddress);
    await reciclagemContract.waitForDeployment();

    const reciclagemAddress = await reciclagemContract.getAddress();
    console.log("ReciclagemFacicoin deployado em:", reciclagemAddress);

    console.log("-----------------------------------------");
    console.log("Transferindo 100.000 FaciCoins para o fundo de recompensas da Reciclagem...");
    const rewardFunds = ethers.parseUnits("100000", 18);
    const tx = await tokenContract.transfer(reciclagemAddress, rewardFunds);
    await tx.wait();
    console.log("Fundos transferidos com sucesso!");
    
    console.log("-----------------------------------------");
    console.log("Deploy de todo o ecossistema finalizado com sucesso!");
}

main().catch(console.error);

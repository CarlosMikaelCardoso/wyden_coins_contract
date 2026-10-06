const ethers = require('ethers');
const fs = require('fs');

async function main() {
    const addresses = JSON.parse(fs.readFileSync('../contratos/addresses.json', 'utf8'));
    const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
    const PRIVATE_KEY = "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    const wcAbi = JSON.parse(fs.readFileSync('../contratos/build/WydenCoin.abi', 'utf8'));
    const wcContract = new ethers.Contract(addresses.WydenCoin, wcAbi, wallet);

    const rmAbi = JSON.parse(fs.readFileSync('../contratos/build/RedemptionManager.abi', 'utf8'));
    const rmContract = new ethers.Contract(addresses.RedemptionManager, rmAbi, wallet);

    const MINTER_ROLE = await wcContract.MINTER_ROLE();

    const workers = [
        "0xd1cf9d73a91de6630c2bb068ba5fddf9f0deac09",
        "0x247ddfa00415710e0416f8c103b5e6428782c916",
        "0x500a8704f86c0d9126dfb949fdc4dc248c228fb4",
        "0x32d9ad8f398995fff658e74430749d65e0ee6702",
        "0xd826e703658fa2ce8d1018d42e637c08d9846a17"
    ];

    console.log("-> Concedendo papeis para os workers reais do Caliper...");
    for (const worker of workers) {
        await (await wcContract.grantRole(MINTER_ROLE, worker)).wait();
    }
    
    // Teste 2 (Resgatar) também precisa que os workers possuam WydenCoins e allowance para o RedemptionManager
    console.log("-> Mintando WC para os workers e aprovando RedemptionManager...");
    for (const worker of workers) {
        // Minta 1000 WC para cada worker poder resgatar
        await (await wcContract.mintReward(worker, 1000, "0x0000000000000000000000000000000000000000000000000000000000000000")).wait();
    }
    console.log("-> Papeis e moedas concedidas com sucesso!");
}

main().catch(console.error);

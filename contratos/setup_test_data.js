const ethers = require('ethers');
const fs = require('fs');

async function main() {
    const addresses = JSON.parse(fs.readFileSync('./addresses.json', 'utf8'));
    const provider = new ethers.JsonRpcProvider('http://127.0.0.1:8545');
    const PRIVATE_KEY = "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63";
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

    const wcAbi = JSON.parse(fs.readFileSync('./build/WydenCoin.abi', 'utf8'));
    const wcContract = new ethers.Contract(addresses.WydenCoin, wcAbi, wallet);

    const rmAbi = JSON.parse(fs.readFileSync('./build/RedemptionManager.abi', 'utf8'));
    const rmContract = new ethers.Contract(addresses.RedemptionManager, rmAbi, wallet);

    const MINTER_ROLE = await wcContract.MINTER_ROLE();
    const CONFIRMER_ROLE = await rmContract.CONFIRMER_ROLE();
    const MANAGER_ROLE = await rmContract.MANAGER_ROLE();

    const workers = [
        "0xd1cf9d73a91de6630c2bb068ba5fddf9f0deac09",
        "0x247ddfa00415710e0416f8c103b5e6428782c916",
        "0x500a8704f86c0d9126dfb949fdc4dc248c228fb4",
        "0x32d9ad8f398995fff658e74430749d65e0ee6702",
        "0xd826e703658fa2ce8d1018d42e637c08d9846a17"
    ];

    console.log("-> Verificando papeis...");
    for (const worker of workers) {
        if (!(await wcContract.hasRole(MINTER_ROLE, worker))) {
            await (await wcContract.grantRole(MINTER_ROLE, worker)).wait();
        }
        if (!(await rmContract.hasRole(CONFIRMER_ROLE, worker))) {
            await (await rmContract.grantRole(CONFIRMER_ROLE, worker)).wait();
        }
        if (!(await rmContract.hasRole(MANAGER_ROLE, worker))) {
            await (await rmContract.grantRole(MANAGER_ROLE, worker)).wait();
        }
    }
    
    console.log("-> Mintando WC para a wallet admin...");
    await (await wcContract.mintReward(wallet.address, 1000000, "0x0000000000000000000000000000000000000000000000000000000000000000")).wait();
    await (await wcContract.approve(addresses.RedemptionManager, 1000000)).wait();

    const startId = await rmContract.nextResgateId();
    fs.writeFileSync('../benchmarks/start_id.txt', startId.toString());
    console.log("-> START_ID gravado:", startId.toString());

    console.log("   - Criando 40 resgates válidos (para confirmar e cancelar)...");
    const futuro = Math.floor(Date.now() / 1000) + 86400; // amanha
    let nonce = await provider.getTransactionCount(wallet.address);
    let txs = [];
    for (let i = 0; i < 40; i++) {
        txs.push(rmContract.resgatar(1, 5, futuro, { nonce: nonce++ }));
    }

    console.log("   - Criando 20 resgates expirados (para expirar)...");
    const passado = Math.floor(Date.now() / 1000) - 100; // no passado
    for (let i = 0; i < 20; i++) {
        txs.push(rmContract.resgatar(2, 5, passado, { nonce: nonce++ }));
    }
    
    console.log("-> Aguardando transações...");
    const responses = await Promise.all(txs);
    await responses[responses.length - 1].wait(); // wait for the last one
    
    console.log("-> Setup concluído com sucesso!");
}

main().catch(console.error);

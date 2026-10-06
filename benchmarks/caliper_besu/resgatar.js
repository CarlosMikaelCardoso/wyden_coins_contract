'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class ResgatarWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        // Pega o endereço real do RedemptionManager pelo sutAdapter
        const rmAddress = this.sutAdapter.getContractInfo ? 
                          (this.sutAdapter.getContractInfo('redemptionManager') || {}).address || "0x686AfD6e502A81D2e77f2e038A23C0dEf4949A20" : 
                          "0x686AfD6e502A81D2e77f2e038A23C0dEf4949A20";

        const request = {
            contract: 'wydenCoin',
            verb: 'approve',
            args: [rmAddress, 999999999], 
            readOnly: false
        };
        try {
            await this.sutAdapter.sendRequests(request);
        } catch (e) {
            console.log("Worker", workerIndex, "approve transaction issue:", e.message);
        }
        
        // Espera a transação ser minerada pelo Besu (já que sendRequests as vezes retorna rapido demais e da Known Transaction)
        await new Promise(resolve => setTimeout(resolve, 5000));
    }

    async submitTransaction() {
        this.txIndex++;
        const beneficioId = this.txIndex % 10; // ids de 0 a 9
        const valor = 5; // 5 moedas
        const expiraEm = Math.floor(Date.now() / 1000) + 86400; // amanha

        const request = {
            contract: 'redemptionManager',
            verb: 'resgatar',
            args: [beneficioId, valor, expiraEm],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new ResgatarWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

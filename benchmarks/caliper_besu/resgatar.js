'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class ResgatarWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        // Primeiro, é preciso que a conta tenha saldo e allowance para o RedemptionManager
        // A conta padrao do Caliper deve chamar 'approve' uma vez no WydenCoin
        // Para simplificar o teste, vamos assumir que o approve e mint já foi dado (ou faremos no setup).
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

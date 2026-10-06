'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class MintRewardWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        // Pode gerar endereços aleatórios se quiser
    }

    async submitTransaction() {
        this.txIndex++;
        // Aluno aleatório ou fake
        const aluno = "0xfe3b557e8fb62b89f4916b721be55ceb828dbd73";
        // Convert string to bytes32 format by padding or hashing
        // Let's just use a padded hex string for "SIA_15D"
        const motivo = "0x5349415f31354400000000000000000000000000000000000000000000000000";
        const valor = 20;

        const request = {
            contract: 'wydenCoin',
            verb: 'mintReward',
            args: [aluno, valor, motivo],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new MintRewardWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

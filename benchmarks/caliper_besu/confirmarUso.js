'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
const fs = require('fs');

class ConfirmarUsoWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.startId = parseInt(fs.readFileSync(__dirname + '/../start_id.txt', 'utf8').trim());
    }

    async submitTransaction() {
        const id = this.startId + (this.workerIndex * 4) + this.txIndex;
        this.txIndex++;

        const request = {
            contract: 'redemptionManager',
            verb: 'confirmarUso',
            args: [id],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new ConfirmarUsoWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

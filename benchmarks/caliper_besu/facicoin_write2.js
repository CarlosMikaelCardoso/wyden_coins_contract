'use strict';
const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
class Write2Workload extends WorkloadModuleBase {
    constructor() { super(); this.txIndex = 0; }
    async submitTransaction() {
        this.txIndex++;
        const request = {
            contract: 'marketplace',
            verb: 'createMentorship',
            args: [`Outra Mentoria ${this.txIndex}`, `Desc ${this.txIndex}`, 100],
            readOnly: false
        };
        await this.sutAdapter.sendRequests(request);
    }
}
function createWorkloadModule() { return new Write2Workload(); }
module.exports.createWorkloadModule = createWorkloadModule;

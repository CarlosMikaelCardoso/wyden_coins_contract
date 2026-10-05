'use strict';
const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
class Write1Workload extends WorkloadModuleBase {
    constructor() { super(); this.txIndex = 0; }
    async submitTransaction() {
        this.txIndex++;
        const request = {
            contract: 'marketplace',
            verb: 'createMentorship',
            args: [`Mentoria ${this.txIndex}`, `Desc ${this.txIndex}`, 50],
            readOnly: false
        };
        await this.sutAdapter.sendRequests(request);
    }
}
function createWorkloadModule() { return new Write1Workload(); }
module.exports.createWorkloadModule = createWorkloadModule;

'use strict';
const { WorkloadModuleBase } = require('@hyperledger/caliper-core');
class ReadWorkload extends WorkloadModuleBase {
    constructor() { super(); }
    async submitTransaction() {
        const request = {
            contract: 'marketplace',
            verb: 'nextMentorshipId',
            args: [],
            readOnly: true
        };
        await this.sutAdapter.sendRequests(request);
    }
}
function createWorkloadModule() { return new ReadWorkload(); }
module.exports.createWorkloadModule = createWorkloadModule;

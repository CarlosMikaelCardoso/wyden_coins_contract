'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class MintRewardWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
        this.motivos = [
            "PRESENCA_AULA", "PROJETO_EXTENSAO", "BOM_COMPORTAMENTO", 
            "NOTA_MAXIMA", "AJUDA_COLEGA"
        ];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
    }

    async submitTransaction() {
        this.txIndex++;
        
        // Simula alunos diferentes (gerando endereços hex aleatórios para fins de demonstração)
        const randomAluno = "0x" + Math.floor(Math.random() * 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF).toString(16).padStart(40, '0');
        
        // Sorteia um motivo e um valor
        const indexMotivo = Math.floor(Math.random() * this.motivos.length);
        const motivoSorteado = this.motivos[indexMotivo];
        const valorAleatorio = Math.floor(Math.random() * 50) + 10; // De 10 a 60 WC

        // Converte string para hex (Caliper manda pro ethers, mas enviamos em hex para o bytes32)
        // Função auxiliar simples para bytes32
        const motivoHex = "0x" + Buffer.from(motivoSorteado, 'utf8').toString('hex').padEnd(64, '0');

        console.log(`[Worker ${this.workerIndex}] 🪙 -> Transferindo ${valorAleatorio} WC para o aluno ${randomAluno.slice(0, 8)}... | Motivo: ${motivoSorteado}`);

        const request = {
            contract: 'wydenCoin',
            verb: 'mintReward',
            args: [randomAluno, valorAleatorio, motivoHex],
            readOnly: false
        };

        return this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new MintRewardWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

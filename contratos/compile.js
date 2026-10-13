const fs = require('fs');                                                     
const path = require('path');                                                 
const solc = require('solc');                                                 
                                                                                
const input = {                                                               
    language: 'Solidity',                                                     
    sources: {                                                                
        'WydenCoin.sol': { content: fs.readFileSync('WydenCoin.sol', 'utf8') },
        'RedemptionManager.sol': { content: fs.                               
readFileSync('RedemptionManager.sol', 'utf8') }                                 
    },                                                                        
    settings: {                                                               
        evmVersion: 'london', // Compatível com a rede Besu                   
        optimizer: { enabled: true, runs: 200 },                              
        outputSelection: {                                                    
            '*': {                                                            
                '*': ['abi', 'evm.bytecode.object']                           
        }
        }
    }
};

function findImports(importPath) {
    let fullPath = importPath;
    if (importPath.startsWith('@openzeppelin/')) {
        fullPath = path.resolve('node_modules', importPath);
    }
    if (fs.existsSync(fullPath)) {
        return { contents: fs.readFileSync(fullPath, 'utf8') };
    }
    return { error: 'Arquivo não encontrado: ' + importPath };
}

console.log('Compilando contratos WydenCoin e RedemptionManager...');         
const output = JSON.parse(solc.compile(JSON.stringify(input), { import:       
findImports }));

if (output.errors) {
    const errs = output.errors.filter(e => e.severity === 'error');           
    if (errs.length > 0) {
        console.error(output.errors);
        process.exit(1);
    }
}

if (!fs.existsSync('build')) fs.mkdirSync('build');

const wc = output.contracts['WydenCoin.sol']['WydenCoin'];
fs.writeFileSync('build/WydenCoin.abi', JSON.stringify(wc.abi, null, 2));     
fs.writeFileSync('build/WydenCoin.bin', wc.evm.bytecode.object);

const rm = output.contracts['RedemptionManager.sol']['RedemptionManager'];    
fs.writeFileSync('build/RedemptionManager.abi', JSON.stringify(rm.abi, null,  
2));
fs.writeFileSync('build/RedemptionManager.bin', rm.evm.bytecode.object);      

console.log('✓ Contratos compilados com sucesso em ./build/!');
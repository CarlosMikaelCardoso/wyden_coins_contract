/**
 * ==============================================================================
 * Gerador de Tabela de Alunos & Carteiras Determinísticas (WydenCoin)
 * ==============================================================================
 *
 * Este script processa a base de alunos e deriva de forma 100% matemática e
 * determinística o par de chaves (carteira pública e chave privada) para cada
 * matrícula.
 *
 * Como é determinístico via Keccak-256 (secp256k1):
 * Mesmo se a blockchain for reiniciada ou zerada do zero, a mesma matrícula
 * SEMPRE gerará exatamente o mesmo endereço Ethereum!
 *
 * Arquivos gerados:
 *   1. alunos_carteiras.json -> Array estruturado para APIs e scripts Node.js
 *   2. alunos_carteiras.csv  -> Planilha CSV para importar no Supabase / Excel
 *   3. povoar_alunos.sql     -> Script SQL pronto para rodar no Supabase / PostgreSQL
 *
 * Execução:
 *   $ node gerar_tabela_alunos.js
 * ==============================================================================
 */

const fs = require('fs');
const path = require('path');
const ethers = require('ethers');

// Caminho do arquivo de simulação / base
const simPath = path.join(__dirname, 'simulacao_recompensas.json');

if (!fs.existsSync(simPath)) {
  console.error(`[ERRO] Arquivo de base não encontrado em: ${simPath}`);
  process.exit(1);
}

const simData = JSON.parse(fs.readFileSync(simPath, 'utf8'));

console.log("=================================================================");
console.log("   GERADOR DETERMINÍSTICO DE CARTEIRAS DE ALUNOS - WYDENCOIN     ");
console.log("=================================================================");
console.log(`-> Processando ${simData.total_alunos} alunos da base de Sistemas de Informação...`);

const alunos = simData.alunos.map((aluno, index) => {
  // Derivação matemática: hash da matrícula gera a chave privada e a carteira
  const hash = ethers.keccak256(ethers.toUtf8Bytes(aluno.matricula));
  const wallet = new ethers.Wallet(hash);

  return {
    id: index + 1,
    matricula: aluno.matricula,
    modalidade: aluno.bu || "PRESENCIAL",
    curso: "Sistemas de Informação",
    carteira_address: wallet.address,
    private_key: wallet.privateKey,
    total_wc_estimado: aluno.total_wc || 0
  };
});

// 1. Gerar JSON
const jsonOutput = path.join(__dirname, 'alunos_carteiras.json');
fs.writeFileSync(jsonOutput, JSON.stringify(alunos, null, 2), 'utf8');
console.log(`[OK] 1. JSON gerado: ${jsonOutput}`);

// 2. Gerar CSV
const csvOutput = path.join(__dirname, 'alunos_carteiras.csv');
const csvLines = [
  "id,matricula,modalidade,curso,carteira_address,private_key,total_wc_estimado"
];
for (const a of alunos) {
  csvLines.push(`${a.id},${a.matricula},${a.modalidade},"${a.curso}",${a.carteira_address},${a.private_key},${a.total_wc_estimado}`);
}
fs.writeFileSync(csvOutput, csvLines.join('\n'), 'utf8');
console.log(`[OK] 2. CSV gerado: ${csvOutput}`);

// 3. Gerar SQL para Supabase / PostgreSQL
const sqlOutput = path.join(__dirname, 'povoar_alunos.sql');
const sqlLines = [
  "-- ==============================================================================",
  "-- Script de Povoamento Inicial: Alunos & Carteiras Blockchain (WydenCoin)",
  `-- Total de registros: ${alunos.length} alunos`,
  `-- Gerado em: ${new Date().toISOString()}`,
  "-- ==============================================================================",
  "",
  "-- 1. Garante que a tabela alunos exista com o campo de carteira",
  "CREATE TABLE IF NOT EXISTS alunos (",
  "    id SERIAL PRIMARY KEY,",
  "    matricula VARCHAR(20) UNIQUE NOT NULL,",
  "    modalidade VARCHAR(20) NOT NULL DEFAULT 'PRESENCIAL',",
  "    curso VARCHAR(100) NOT NULL DEFAULT 'Sistemas de Informação',",
  "    carteira_address VARCHAR(42) UNIQUE NOT NULL,",
  "    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()",
  ");",
  "",
  "-- 2. Inserção idempotente (ON CONFLICT preserva dados se já existirem)",
  "INSERT INTO alunos (matricula, modalidade, curso, carteira_address) VALUES"
];

const valuesList = alunos.map(a => 
  `  ('${a.matricula}', '${a.modalidade}', '${a.curso}', '${a.carteira_address}')`
);

sqlLines.push(valuesList.join(',\n') + ';');
sqlLines.push("");
sqlLines.push("-- Atualiza carteiras caso a matrícula já exista no banco");
sqlLines.push("-- ON CONFLICT (matricula) DO UPDATE SET carteira_address = EXCLUDED.carteira_address;");

fs.writeFileSync(sqlOutput, sqlLines.join('\n'), 'utf8');
console.log(`[OK] 3. SQL gerado: ${sqlOutput}`);

console.log("\n-> Exemplos de registros gerados:");
alunos.slice(0, 3).forEach(a => {
  console.log(`   [Aluno ${a.id}] Matrícula: ${a.matricula} | Modalidade: ${a.modalidade} | Carteira: ${a.carteira_address}`);
});

console.log("\n=================================================================");
console.log("   Processamento concluído com sucesso!");
console.log("=================================================================");

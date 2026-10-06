import re
import sys
import matplotlib.pyplot as plt
from collections import defaultdict

def parse_log(filepath):
    transfers = []
    tps_data = []
    
    # Regex para capturar as transferências detalhadas
    # Exemplo: [Worker 1] 🪙 -> Transferindo 31 WC para o aluno 0x000000... | Motivo: AJUDA_COLEGA
    transfer_pattern = re.compile(r'\[Worker \d+\] .* Transferindo (\d+) WC .* Motivo: (.+)')

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                # Extrai informações de transferência
                match_transfer = transfer_pattern.search(line)
                if match_transfer:
                    amount = int(match_transfer.group(1))
                    reason = match_transfer.group(2).strip()
                    transfers.append({"amount": amount, "reason": reason})
                
                # Extrai informações da tabela do Caliper separando por pipe
                # | Name | Succ | Fail | Send Rate (TPS) | Max Latency (s) | Min Latency (s) | Avg Latency (s) | Throughput (TPS) |
                # | open | 0    | 20   | 66.2            | -               | -               | -               | 66.0             |
                if line.startswith('|') and not line.startswith('|-'):
                    parts = [p.strip() for p in line.split('|')]
                    if len(parts) >= 9:
                        name = parts[1]
                        # Ignora a linha de cabeçalho
                        if name == 'Name' or not name:
                            continue
                        
                        try:
                            succ = int(parts[2])
                            fail = int(parts[3])
                            send_rate = float(parts[4])
                            throughput = float(parts[8])
                            
                            tps_data.append({
                                "name": name, 
                                "succ": succ, 
                                "fail": fail, 
                                "send_rate": send_rate, 
                                "throughput": throughput
                            })
                        except ValueError:
                            pass
    except FileNotFoundError:
        print(f"Erro: Arquivo '{filepath}' não encontrado.")
        sys.exit(1)

    return transfers, tps_data

def generate_charts(transfers):
    reasons_count = defaultdict(int)
    reasons_amount = defaultdict(int)

    for t in transfers:
        reasons_count[t['reason']] += 1
        reasons_amount[t['reason']] += t['amount']

    if not transfers:
        print("Aviso: Nenhuma transferência encontrada no log para gerar gráficos.")
        return

    labels = list(reasons_count.keys())
    counts = list(reasons_count.values())
    amounts = list(reasons_amount.values())

    # Gráfico 1: Quantidade de transações por motivo
    plt.figure(figsize=(10, 6))
    bars = plt.bar(labels, counts, color='skyblue', edgecolor='black')
    plt.title('Número de Transações por Motivo', fontsize=14)
    plt.xlabel('Motivo', fontsize=12)
    plt.ylabel('Quantidade de Transações', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    
    # Adiciona os valores em cima de cada barra
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval, int(yval), va='bottom', ha='center')

    plt.tight_layout()
    plt.savefig('transacoes_por_motivo.png')
    plt.close()

    # Gráfico 2: Total de WC transferidos por motivo
    plt.figure(figsize=(10, 6))
    wedges, texts, autotexts = plt.pie(
        amounts, 
        labels=labels, 
        autopct='%1.1f%%', 
        startangle=140, 
        colors=plt.cm.Paired.colors
    )
    plt.title('Distribuição de WC Transferidos por Motivo', fontsize=14)
    plt.tight_layout()
    plt.savefig('wc_por_motivo.png')
    plt.close()

def generate_markdown(transfers, tps_data):
    # Consolidar dados de TPS pegando o último registro de cada workload
    consolidated_tps = {}
    for data in tps_data:
        consolidated_tps[data['name']] = data

    total_wc = sum(t['amount'] for t in transfers)
    total_tx = len(transfers)

    md_content = f"# Relatório de Desempenho e Distribuição (WydenCoin)\n\n"
    md_content += "Este documento foi gerado automaticamente através da extração dos logs do Hyperledger Caliper.\n\n"
    md_content += "## 1. Resumo de Transferências\n\n"
    md_content += f"- **Total de Transações Únicas Registradas**: {total_tx}\n"
    md_content += f"- **Total de Moedas (WC) Distribuídas**: {total_wc} WC\n\n"
    
    if transfers:
        md_content += "### 1.1 Gráficos Gerados\n"
        md_content += "Abaixo estão as representações visuais dos motivos que originaram as transferências na rede.\n\n"
        md_content += "![Transações por Motivo](./transacoes_por_motivo.png)\n\n"
        md_content += "![WC por Motivo](./wc_por_motivo.png)\n\n"

    md_content += "## 2. Métricas de Desempenho da Rede (Caliper)\n\n"
    md_content += "Desempenho final consolidado por tipo de workload executado no teste:\n\n"
    md_content += "| Workload | Sucesso | Falha | Send Rate (TPS) | Throughput (TPS) |\n"
    md_content += "|----------|---------|-------|-----------------|------------------|\n"
    
    if consolidated_tps:
        for name, data in consolidated_tps.items():
            md_content += f"| **{name}** | {data['succ']} | {data['fail']} | {data['send_rate']} | {data['throughput']} |\n"
    else:
        md_content += "| N/A | N/A | N/A | N/A | N/A |\n"
    
    md_content += "\n\n---\n*Relatório gerado pelo script automatizado.*"

    with open("relatorio_caliper.md", "w", encoding="utf-8") as f:
        f.write(md_content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python gerar_relatorio.py <caminho_para_o_log>")
        print("Exemplo: python gerar_relatorio.py caliper.log")
        sys.exit(1)
        
    logfile = sys.argv[1]
    transfers, tps_data = parse_log(logfile)
    
    print(f"-> Extraídas {len(transfers)} transações de recompensas do log.")
    
    generate_charts(transfers)
    print("-> Gráficos gerados com sucesso: 'transacoes_por_motivo.png' e 'wc_por_motivo.png'")
    
    generate_markdown(transfers, tps_data)
    print("-> Relatório legível criado: 'relatorio_caliper.md'")
    print("Processo finalizado!")

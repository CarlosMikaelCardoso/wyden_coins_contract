import re
import sys
import matplotlib.pyplot as plt
import numpy as np

def parse_log(filepath):
    tps_data = []

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("|") and not line.startswith("|-"):
                    parts = [p.strip() for p in line.split("|")]
                    if len(parts) >= 9:
                        name = parts[1]
                        if name == "Name" or not name:
                            continue
                        
                        try:
                            succ = int(parts[2])
                            fail = int(parts[3])
                            send_rate = float(parts[4])
                            
                            max_lat = parts[5]
                            min_lat = parts[6]
                            avg_lat = parts[7]
                            
                            throughput = float(parts[8])
                            
                            tps_data.append({
                                "name": name, 
                                "succ": succ, 
                                "fail": fail, 
                                "send_rate": send_rate, 
                                "max_lat": max_lat,
                                "min_lat": min_lat,
                                "avg_lat": avg_lat,
                                "throughput": throughput
                            })
                        except ValueError:
                            pass
    except FileNotFoundError:
        print(f"Erro: Arquivo {filepath} não encontrado.")
        sys.exit(1)

    return tps_data

def generate_charts(tps_data):
    consolidated_tps = {}
    for data in tps_data:
        consolidated_tps[data["name"]] = data

    if not consolidated_tps:
        print("Aviso: Nenhuma métrica encontrada para gerar gráficos.")
        return

    labels = list(consolidated_tps.keys())
    throughputs = [d["throughput"] for d in consolidated_tps.values()]
    sucessos = [d["succ"] for d in consolidated_tps.values()]
    falhas = [d["fail"] for d in consolidated_tps.values()]

    plt.figure(figsize=(10, 6))
    bars = plt.bar(labels, throughputs, color="mediumseagreen", edgecolor="black")
    plt.title("Vazão (Throughput - TPS) por Operação Smart Contract", fontsize=14)
    plt.xlabel("Operação", fontsize=12)
    plt.ylabel("Transações por Segundo (TPS)", fontsize=12)
    plt.xticks(rotation=45, ha="right")
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2.0, yval, f"{yval:.1f}", va="bottom", ha="center")
    plt.tight_layout()
    plt.savefig("grafico_throughput.png")
    plt.close()

    x = np.arange(len(labels))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    rects1 = ax.bar(x - width/2, sucessos, width, label="Sucesso", color="dodgerblue")
    rects2 = ax.bar(x + width/2, falhas, width, label="Falha", color="crimson")

    ax.set_ylabel("Quantidade de Transações", fontsize=12)
    ax.set_title("Transações Bem-sucedidas vs Falhas por Operação", fontsize=14)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=45, ha="right")
    ax.legend()

    for bar in rects1:
        yval = bar.get_height()
        ax.text(bar.get_x() + bar.get_width()/2.0, yval, int(yval), va="bottom", ha="center")
    for bar in rects2:
        yval = bar.get_height()
        if yval > 0:
            ax.text(bar.get_x() + bar.get_width()/2.0, yval, int(yval), va="bottom", ha="center")

    plt.tight_layout()
    plt.savefig("grafico_sucesso_falhas.png")
    plt.close()

def generate_markdown(tps_data):
    consolidated_tps = {}
    for data in tps_data:
        consolidated_tps[data["name"]] = data

    md_content = "# Relatório de Teste de Carga - Ciclo Completo de Moedas\n\n"
    md_content += "Este documento apresenta a análise de desempenho do sistema blockchain englobando todo o ciclo de vida da WydenCoin: Emissão (`mintReward`), Retenção (`resgatar`), Confirmação (`confirmarUso`), Cancelamento (`cancelar`) e Expiração (`expirar`).\n\n"
    
    md_content += "## 1. Gráficos de Desempenho\n\n"
    md_content += "![Throughput por Operação](./grafico_throughput.png)\n\n"
    md_content += "![Sucesso vs Falha](./grafico_sucesso_falhas.png)\n\n"

    md_content += "## 2. Tabela Analítica de Desempenho (TPS e Latência)\n\n"
    md_content += "| Operação | Sucesso | Falha | Send Rate (TPS) | Throughput (TPS) | Latência Máx (s) | Latência Mín (s) | Latência Média (s) |\n"
    md_content += "|----------|---------|-------|-----------------|------------------|------------------|------------------|--------------------|\n"
    
    if consolidated_tps:
        for name, data in consolidated_tps.items():
            md_content += f"| **{name}** | {data['succ']} | {data['fail']} | {data['send_rate']} | {data['throughput']} | {data['max_lat']} | {data['min_lat']} | {data['avg_lat']} |\n"
    else:
        md_content += "| N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |\n"
    
    md_content += "\n\n---\n*Gerado automaticamente na VM JMeter.*"

    with open("relatorio_caliper_completo.md", "w", encoding="utf-8") as f:
        f.write(md_content)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python gerar_relatorio.py <caminho_para_o_log>")
        sys.exit(1)
        
    logfile = sys.argv[1]
    tps_data = parse_log(logfile)
    
    generate_charts(tps_data)
    print("-> Gráficos gerados com sucesso: grafico_throughput.png e grafico_sucesso_falhas.png")
    
    generate_markdown(tps_data)
    print("-> Relatório criado: relatorio_caliper_completo.md")

import subprocess
import re
import os
import json
import yaml # Importar a biblioteca PyYAML
import time

def get_enode(node_number):
    """
    Obtém o enode para um nó Besu específico.
    Adiciona timeout para o curl e retry.
    """
    port = 8545 + node_number - 1
    command = f"curl -X POST --silent --connect-timeout 5 --max-time 10 --data '{{\"jsonrpc\":\"2.0\",\"method\":\"net_enode\",\"params\":[],\"id\":1}}' http://127.0.0.1:{port} | jq -r .result"
    
    for attempt in range(5):
        try:
            result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
            enode = result.stdout.strip()
            if not enode or enode == "null":
                print(f"Aviso: Enode vazio/null para Node-{node_number} (tentativa {attempt+1}). Aguardando...")
                time.sleep(5)
                continue
            
            # Modifica o IP no enode para 127.0.0.1
            if node_number == 1:
                enode = re.sub(r'@\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+', '@127.0.0.1:30303', enode)
            return enode
        except subprocess.CalledProcessError as e:
            print(f"Erro ao obter enode para Node-{node_number} (tentativa {attempt+1}): {e}")
            time.sleep(5)
            continue
        except Exception as e:
            print(f"Ocorreu um erro inesperado ao obter enode para Node-{node_number}: {e}")
            return None
    return None

def update_docker_compose_with_yq(file_path, enode1):
    """
    Atualiza o arquivo docker-compose.yaml com o enode do node1.
    """
    new_bootnodes_string = f'--bootnodes="{enode1}"'

    try:
        with open(file_path, 'r') as f:
            yaml_data = yaml.safe_load(f)

        for i in range(2, 5): # Ajustado para 4 nodes (2 a 4)
            node_name = f'node{i}'
            
            if node_name in yaml_data.get('services', {}) and 'command' in yaml_data['services'][node_name]:
                current_command_content = yaml_data['services'][node_name]['command']

                if re.search(r'--bootnodes=', current_command_content):
                    updated_command_content = re.sub(
                        r'--bootnodes=\S+', 
                        new_bootnodes_string, 
                        current_command_content 
                    )
                else:
                    if re.search(r'--genesis-file=', current_command_content):
                        updated_command_content = re.sub(
                            r'(--genesis-file=/\S+)',
                            r'\1\n' + new_bootnodes_string, 
                            current_command_content,
                            flags=re.MULTILINE
                        )
                    else:
                        updated_command_content = new_bootnodes_string + "\n" + current_command_content
                
                yaml_data['services'][node_name]['command'] = updated_command_content
                print(f"Comando para {node_name} modificado em memória.")
            else:
                print(f"Aviso: O serviço '{node_name}' não foi encontrado no YAML.")

        with open(file_path, 'w') as f:
            yaml.dump(yaml_data, f, default_flow_style=False, sort_keys=False)
        
        print(f"Arquivo '{file_path}' atualizado com sucesso usando PyYAML.")

    except Exception as e:
        print(f"Ocorreu um erro inesperado: {e}")

if __name__ == "__main__":
    compose_file = 'docker-compose.yaml'
    
    print("Obtendo enodes do Node-1...")
    enode_node1 = get_enode(1)

    if enode_node1:
        print(f"Enode Node-1: {enode_node1}")
        print(f"Atualizando o arquivo {compose_file} usando PyYAML...")
        update_docker_compose_with_yq(compose_file, enode_node1)
    else:
        print("Não foi possível obter enode do Node-1. Verifique se o nó está rodando.")

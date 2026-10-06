#!/usr/bin/env bash
set -e

echo "1. Montando a pasta Codes dentro da VM..."
multipass mount /home/mikael/Documentos/Codes besu-vm:/home/ubuntu/Codes

echo "2. Instalando Docker e Node.js na VM..."
multipass exec besu-vm -- sudo snap install docker
multipass exec besu-vm -- sudo snap install node --classic

echo "3. Adicionando o usuário ubuntu ao grupo docker..."
multipass exec besu-vm -- sudo addgroup --system docker || true
multipass exec besu-vm -- sudo usermod -aG docker ubuntu

echo "4. Instalando dependências do sistema..."
multipass exec besu-vm -- sudo apt-get update
multipass exec besu-vm -- sudo apt-get install -y python3 make g++ jq wget curl tar

echo "VM Configurada com sucesso!"

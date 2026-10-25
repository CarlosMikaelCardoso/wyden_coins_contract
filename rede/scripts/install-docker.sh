#!/usr/bin/env bash
# ==============================================================================
# install-docker.sh
# Instala Docker e Docker Compose de forma não-interativa e adiciona o usuário ao grupo docker.
# ==============================================================================
set -o errexit
set -o nounset
set -o pipefail

echo "================================================================="
echo "   INSTALAÇÃO DE PRÉ-REQUISITOS: DOCKER & DOCKER COMPOSE         "
echo "================================================================="

if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  echo "✓ Docker e Docker Compose já estão instalados!"
  docker --version
  docker compose version
  exit 0
fi

echo "📦 Instalando Docker via script oficial da Docker Inc..."
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh

echo "👤 Adicionando o usuário '$(whoami)' ao grupo docker..."
sudo usermod -aG docker "$(whoami)" || true

echo "✓ Instalação concluída com sucesso!"
echo "Caso receba erro de permissão ao rodar 'docker', execute: newgrp docker ou reinicie a sessão."

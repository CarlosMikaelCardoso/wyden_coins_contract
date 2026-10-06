Vagrant.configure("2") do |config|
  # Usa uma imagem oficial e leve do Ubuntu 22.04 LTS
  config.vm.box = "ubuntu/jammy64"

  # Configuração de Rede: Libera a porta 8545 (RPC do Node 1) para o host (Windows/Linux) acessar
  config.vm.network "forwarded_port", guest: 8545, host: 8545, host_ip: "127.0.0.1"

  # Sincroniza a pasta atual do projeto para dentro da VM na pasta /vagrant
  # Desabilita o sync padrão e usa rsync ou virtualbox dependendo do SO hospedeiro
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"

  # Configurações da Máquina Virtual (RAM e CPU)
  config.vm.provider "virtualbox" do |vb|
    vb.name = "WydenCoin_Besu_VM"
    # 2GB de RAM e 2 CPUs são suficientes para rodar a rede Besu de 4 nós localmente
    vb.memory = "2048"
    vb.cpus = 2
  end

  # Script de Provisionamento (Roda automaticamente no primeiro 'vagrant up')
  config.vm.provision "shell", inline: <<-SHELL
    echo "=========================================="
    echo "Iniciando Provisionamento da VM WydenCoin"
    echo "=========================================="
    
    # Atualiza pacotes e instala dependências básicas
    apt-get update
    apt-get install -y curl wget git jq python3 python3-pip dos2unix

    # Instala o Docker
    if ! command -v docker &> /dev/null; then
        echo "Instalando Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        usermod -aG docker vagrant
    fi

    # Instala o Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        echo "Instalando Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

    # Instala a biblioteca PyYAML para o script do Besu
    pip3 install PyYAML

    echo "=========================================="
    echo "Ambiente Pronto!"
    echo "Para iniciar a rede Besu, digite:"
    echo "1. vagrant ssh"
    echo "2. cd /vagrant/rede"
    echo "3. sudo ./start.sh"
    echo "=========================================="
  SHELL
end

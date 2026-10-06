# Guia de Configuração: Máquina Virtual com Multipass

O **Multipass** é uma ferramenta oficial da Canonical (desenvolvedora do Ubuntu) que cria Máquinas Virtuais (VMs) Ubuntu de forma instantânea e extremamente leve. É ideal para membros da equipe que não querem instalar o Docker no próprio PC ou que preferem ter a rede blockchain rodando 100% isolada e descartável em um ambiente Linux limpo.

Ele é mais rápido, mais leve e consome menos CPU que as tradicionais VMs do VirtualBox.

---

## 1. Instalação do Multipass

1. Acesse o site oficial: [https://multipass.run/](https://multipass.run/)
2. Baixe e instale a versão correspondente ao seu sistema operacional (Windows, macOS ou Linux).
   - *Nota para Windows: O instalador perguntará qual virtualizador usar. Escolha **Hyper-V** (preferencial se você usa Windows Pro) ou **VirtualBox**.*

## 2. Criando a VM da WydenCoin

Abra seu terminal (PowerShell, CMD ou Terminal do Mac/Linux) e execute o comando abaixo para lançar uma nova máquina virtual chamada `wydencoin` contendo 2 CPUs, 2GB de RAM e 20GB de disco rígido:

```bash
multipass launch -c 2 -m 2G -d 20G -n wydencoin
```
*Aguarde alguns instantes enquanto o Ubuntu é baixado e iniciado de forma invisível.*

## 3. Acessando a Máquina e Rodando a Rede

1. Para entrar no terminal da VM que você acabou de criar, digite:
   ```bash
   multipass shell wydencoin
   ```
2. Dentro do terminal da VM, baixe o repositório do projeto:
   ```bash
   git clone https://github.com/CarlosMikaelCardoso/wyden_coins_contract.git
   cd wyden_coins_contract/rede
   ```
3. Instale o Docker de forma rápida usando o script oficial:
   ```bash
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker ubuntu
   newgrp docker
   ```
4. Suba a rede executando nosso script:
   ```bash
   ./start.sh
   ```

## 4. Conectando o seu Computador Hospedeiro (Windows/Mac) à Rede da VM

Quando a rede iniciar na VM, o Node 1 vai liberar a porta RPC (`8545`). Contudo, como a VM tem um endereço IP próprio, o seu Windows/Mac não achará a rede no `localhost`.

Para descobrir o IP da sua VM Multipass, abra uma nova aba do terminal no seu computador físico e digite:
```bash
multipass info wydencoin
```
Copie o IP listado na seção `IPv4`. 

No seu código do Backend (Node.js) ou na conexão do MetaMask, mude a URL de RPC de `http://127.0.0.1:8545` para o IP da VM. Por exemplo:
`http://192.168.X.X:8545`

## 5. Comandos Úteis do Multipass

- **Parar a VM (Pausar o uso de RAM do seu PC):**
  ```bash
  multipass stop wydencoin
  ```
- **Ligar a VM novamente:**
  ```bash
  multipass start wydencoin
  ```
- **Excluir a VM completamente (Destrói tudo):**
  ```bash
  multipass delete wydencoin
  multipass purge
  ```

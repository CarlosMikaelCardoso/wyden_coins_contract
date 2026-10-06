# Guia de Configuração: Rodando a Rede via WSL 2 (Windows 10/11)

Esta é a forma **mais leve e recomendada** para membros da equipe que utilizam Windows. O WSL 2 (Windows Subsystem for Linux) permite rodar um ambiente Linux nativo diretamente no Windows, compartilhando o Kernel e consumindo muito menos memória do que uma Máquina Virtual tradicional.

Como nossa rede da WydenCoin (Hyperledger Besu) roda inteiramente isolada dentro de contêineres Docker, o WSL 2 é perfeito para o trabalho.

---

## 1. Pré-requisitos

1. **Windows 10** (versão 2004 e superior) ou **Windows 11**.
2. **Docker Desktop** instalado no seu computador.

## 2. Passo a Passo de Instalação

### Habilitar o WSL 2
1. Abra o **PowerShell** no Windows como **Administrador**.
2. Digite o seguinte comando e aperte Enter:
   ```powershell
   wsl --install
   ```
   *(Este comando ativará as ferramentas de virtualização do Windows e fará o download da última versão do Ubuntu automaticamente)*.
3. **Reinicie seu computador** se for solicitado.

### Configurar o Docker Desktop para usar o WSL 2
1. Abra o aplicativo **Docker Desktop**.
2. Vá em **Settings** (ícone de engrenagem) no canto superior direito.
3. No menu lateral esquerdo, vá em **General**.
4. Certifique-se de que a opção **"Use the WSL 2 based engine"** está **marcada**.
5. No menu lateral, vá em **Resources > WSL Integration**.
6. Ative a chave ao lado da sua distribuição Linux (ex: `Ubuntu`).
7. Clique em **Apply & Restart**.

## 3. Rodando a Rede Besu

1. Abra o aplicativo **Ubuntu** no menu Iniciar do seu Windows (ou digite `wsl` no seu terminal).
2. Clone o repositório do projeto se ainda não tiver feito:
   ```bash
   git clone https://github.com/CarlosMikaelCardoso/wyden_coins_contract.git
   cd wyden_coins_contract
   ```
3. Navegue até a pasta da rede:
   ```bash
   cd rede
   ```
4. Execute o script de inicialização:
   ```bash
   ./start.sh
   ```
*(O script já instalará o Java e as dependências necessárias, montará as chaves criptográficas e iniciará os 4 nós Besu utilizando o Docker).*

## 4. Testando o Acesso

Quando o terminal exibir: `Rede Besu Local inicializada (RPC: http://127.0.0.1:8545)`, você já poderá conectar a API do Backend da WydenCoin rodando no seu Windows (ou mesmo ferramentas como o Postman) disparando para `http://localhost:8545`. O WSL 2 compartilha as portas de rede automaticamente com o Windows!

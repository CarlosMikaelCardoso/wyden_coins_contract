// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./WydenCoin.sol";

contract RedemptionManager is AccessControl {
    bytes32 public constant CONFIRMER_ROLE = keccak256("CONFIRMER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    WydenCoin public token;

    enum Status { Resgatado, Utilizado, Cancelado, Expirado }

    struct Resgate {
        address aluno;
        uint256 beneficioId;
        uint256 valor;
        uint64 expiraEm;
        Status status;
    }

    mapping(uint256 => Resgate) public resgates;
    uint256 public nextResgateId = 1;

    event ResgateCriado(uint256 indexed id, address indexed aluno, uint256 beneficioId, uint256 valor, uint64 expiraEm);
    event ResgateUtilizado(uint256 indexed id);
    event ResgateCancelado(uint256 indexed id);
    event ResgateExpirado(uint256 indexed id);

    constructor(address _tokenAddress) {
        token = WydenCoin(_tokenAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // O aluno resgata o benefício e as moedas ficam retidas NESTE contrato
    function resgatar(uint256 beneficioId, uint256 valor, uint64 expiraEm) external returns (uint256 id) {
        // O aluno precisa ter dado approve() no token antes, ou podemos usar transfer() já que o
        // _update() do token permite transferências PARA este contrato.
        // Vamos usar transferFrom puxando as moedas do aluno para o contrato.
        require(token.transferFrom(msg.sender, address(this), valor), "Falha ao bloquear moedas");
        
        id = nextResgateId++;
        resgates[id] = Resgate({
            aluno: msg.sender,
            beneficioId: beneficioId,
            valor: valor,
            expiraEm: expiraEm,
            status: Status.Resgatado
        });

        emit ResgateCriado(id, msg.sender, beneficioId, valor, expiraEm);
    }

    // O validador (cantina, mentor, etc) confirma o uso
    function confirmarUso(uint256 id) external onlyRole(CONFIRMER_ROLE) {
        Resgate storage r = resgates[id];
        require(r.status == Status.Resgatado, "Resgate nao esta pendente");
        require(block.timestamp <= r.expiraEm, "Resgate expirado");

        r.status = Status.Utilizado;
        
        // Queima as moedas que estavam bloqueadas no contrato
        token.burn(r.valor);

        emit ResgateUtilizado(id);
    }

    // O administrador (backend) cancela o resgate (ex: erro no pedido)
    function cancelar(uint256 id) external onlyRole(MANAGER_ROLE) {
        Resgate storage r = resgates[id];
        require(r.status == Status.Resgatado, "Resgate nao pendente");

        r.status = Status.Cancelado;
        
        // Devolve ao aluno
        require(token.transfer(r.aluno, r.valor), "Falha na devolucao");

        emit ResgateCancelado(id);
    }

    // O backend varre o banco verificando se o prazo expirou e chama essa função
    function expirar(uint256 id) external onlyRole(MANAGER_ROLE) {
        Resgate storage r = resgates[id];
        require(r.status == Status.Resgatado, "Resgate nao pendente");
        require(block.timestamp > r.expiraEm, "Ainda no prazo");

        r.status = Status.Expirado;
        
        // Devolve ao aluno
        require(token.transfer(r.aluno, r.valor), "Falha na devolucao");

        emit ResgateExpirado(id);
    }
}

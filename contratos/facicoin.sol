// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MeuToken {
    // -----------------------------
    // Metadados do token
    // -----------------------------
    string public name = "FaciCoin";
    string public symbol = "FC";
    uint8 public decimals = 18;

    // Oferta total (quantidade de tokens existentes)
    uint256 public totalSupply;

    // -----------------------------
    // Estado: saldos e permissões
    // -----------------------------
    mapping(address => uint256) private balances;

    // allowed[owner][spender] = quanto o spender pode gastar do owner
    mapping(address => mapping(address => uint256)) private allowed;

    // -----------------------------
    // Eventos (logs públicos)
    // -----------------------------
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    // -----------------------------
    // Construtor: cria o supply inicial
    // -----------------------------
    constructor(uint256 initialSupply) {
        totalSupply = initialSupply;
        balances[msg.sender] = initialSupply;

        // Evento opcional: “mint inicial” costuma ser representado assim
        emit Transfer(address(0), msg.sender, initialSupply);
    }

    // -----------------------------
    // Ler saldo (somente leitura)
    // -----------------------------
    function balanceOf(address owner) public view returns (uint256) {
        return balances[owner];
    }

    // -----------------------------
    // Transferência direta (quem chama envia do próprio saldo)
    // -----------------------------
    function transfer(address to, uint256 value) public returns (bool) {
        require(to != address(0), "Endereco invalido");
        require(balances[msg.sender] >= value, "Saldo insuficiente");

        balances[msg.sender] -= value;
        balances[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }
}

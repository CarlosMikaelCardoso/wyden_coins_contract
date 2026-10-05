// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ReciclagemFacicoin {
    IERC20 public facicoin;
    address public admin;

    struct Material {
        string name;
        uint256 rewardPerUnit; // Quantidade de FaciCoins pagas por unidade (ex: por Garrafa PET ou por Kg)
        bool active;
    }

    // Mapeamento: ID do material => Informações do material
    mapping(uint256 => Material) public materials;
    uint256 public nextMaterialId;

    // Registra quais máquinas/funcionários podem validar a reciclagem e enviar as moedas
    mapping(address => bool) public authorizedValidators;

    event MaterialAdded(uint256 id, string name, uint256 rewardPerUnit);
    event Recycled(address indexed student, uint256 materialId, uint256 quantity, uint256 reward);
    event ValidatorAdded(address validator);
    event ValidatorRemoved(address validator);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Apenas administrador");
        _;
    }

    modifier onlyValidator() {
        require(authorizedValidators[msg.sender] || msg.sender == admin, "Apenas validadores autorizados");
        _;
    }

    constructor(address _facicoinAddress) {
        facicoin = IERC20(_facicoinAddress);
        admin = msg.sender;
        authorizedValidators[msg.sender] = true; // O criador também pode validar no início
    }

    // -----------------------------------------
    // Configurações do Sistema
    // -----------------------------------------

    // Faculdade cadastra novos materiais (ex: "Garrafa PET", 5 FaciCoins)
    function addMaterial(string memory _name, uint256 _rewardPerUnit) public onlyAdmin {
        materials[nextMaterialId] = Material({
            name: _name,
            rewardPerUnit: _rewardPerUnit,
            active: true
        });
        emit MaterialAdded(nextMaterialId, _name, _rewardPerUnit);
        nextMaterialId++;
    }

    function toggleMaterial(uint256 _id) public onlyAdmin {
        materials[_id].active = !materials[_id].active;
    }

    // Adiciona o endereço de uma máquina de reciclagem ou funcionário
    function addValidator(address _validator) public onlyAdmin {
        authorizedValidators[_validator] = true;
        emit ValidatorAdded(_validator);
    }

    function removeValidator(address _validator) public onlyAdmin {
        authorizedValidators[_validator] = false;
        emit ValidatorRemoved(_validator);
    }

    // -----------------------------------------
    // Lógica de Ganho (Reciclagem)
    // -----------------------------------------

    // Essa função DEVE ser chamada pela máquina/sistema da faculdade, e não pelo próprio aluno (para evitar fraudes)
    function processRecycling(address _student, uint256 _materialId, uint256 _quantity) public onlyValidator {
        Material memory mat = materials[_materialId];
        require(mat.active, "Material inativo ou inexistente");
        require(_quantity > 0, "Quantidade deve ser maior que zero");

        uint256 totalReward = mat.rewardPerUnit * _quantity;

        // O contrato de reciclagem precisa ter saldo suficiente para pagar o aluno!
        // A faculdade deve transferir FaciCoins para o endereço deste contrato previamente (Fundo de Recompensas)
        require(facicoin.balanceOf(address(this)) >= totalReward, "Fundo de recompensas do campus esta vazio");

        // Transfere os tokens do contrato para o aluno
        require(facicoin.transfer(_student, totalReward), "Falha na transferencia");

        emit Recycled(_student, _materialId, _quantity, totalReward);
    }
}

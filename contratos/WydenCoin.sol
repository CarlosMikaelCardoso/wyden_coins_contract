// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract WydenCoin is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address public redemptionManager;

    event RewardMinted(address indexed aluno, uint256 valor, bytes32 motivo);

    constructor() ERC20("WydenCoin", "WC") {
        // O deployer vira o administrador geral
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Define qual endereço é o contrato de resgate
    function setRedemptionManager(address _redemptionManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        redemptionManager = _redemptionManager;
    }

    // 0 casas decimais para facilitar a vida do front-end e UX (1 WC = 1 inteiro)
    function decimals() public pure override returns (uint8) {
        return 0;
    }

    // Função que o Backend/Motor de Recompensas vai chamar para dar moedas ao aluno
    function mintReward(address aluno, uint256 valor, bytes32 motivo) external onlyRole(MINTER_ROLE) {
        _mint(aluno, valor);
        emit RewardMinted(aluno, valor, motivo);
    }

    // Sobrescrevemos o hook de atualização de saldo para bloquear transferências
    // P2P (entre alunos) evitando comércio paralelo das moedas.
    function _update(address from, address to, uint256 value) internal override {
        // Se não for um mint (from == 0) nem um burn (to == 0)
        if (from != address(0) && to != address(0)) {
            // Só permite a transferência se for originada pelo ou para o RedemptionManager
            require(
                msg.sender == redemptionManager || to == redemptionManager || from == redemptionManager,
                "WydenCoin: transferencias diretas entre alunos estao bloqueadas"
            );
        }
        super._update(from, to, value);
    }
}

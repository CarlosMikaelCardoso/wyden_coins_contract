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
        // Concede a role DEFAULT_ADMIN_ROLE ao endereço deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Registra o endereço autorizado do RedemptionManager
    function setRedemptionManager(address _redemptionManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        redemptionManager = _redemptionManager;
    }

    // Define 0 casas decimais (1 token WC = 1 unidade inteira)
    function decimals() public pure override returns (uint8) {
        return 0;
    }

    // Emite tokens de bonificação individual associados ao código do motivo
    function mintReward(address aluno, uint256 valor, bytes32 motivo) external onlyRole(MINTER_ROLE) {
        _mint(aluno, valor);
        emit RewardMinted(aluno, valor, motivo);
    }

    // Emissão em lote de recompensas para múltiplos destinatários em transação única
    function mintRewardBatch(
        address[] calldata alunos,
        uint256[] calldata valores,
        bytes32[] calldata motivos
    ) external onlyRole(MINTER_ROLE) {
        require(
            alunos.length == valores.length && valores.length == motivos.length,
            "WydenCoin: arrays devem ter o mesmo tamanho"
        );
        for (uint256 i = 0; i < alunos.length; i++) {
            _mint(alunos[i], valores[i]);
            emit RewardMinted(alunos[i], valores[i], motivos[i]);
        }
    }

    // Sobrescreve o hook _update para restringir transferências diretas P2P,
    // permitindo apenas operações originadas por ou destinadas ao RedemptionManager.
    function _update(address from, address to, uint256 value) internal override {
        // Ignora emissão (from == 0) e queima (to == 0)
        if (from != address(0) && to != address(0)) {
            // Permite transferência apenas se envolver o contrato de resgate autorizado
            require(
                msg.sender == redemptionManager || to == redemptionManager || from == redemptionManager,
                "WydenCoin: transferencias diretas entre alunos estao bloqueadas"
            );
        }
        super._update(from, to, value);
    }
}

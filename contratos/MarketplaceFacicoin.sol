// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Interface mínima do ERC20 (FaciCoin)
interface ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MarketplaceFacicoin {
    ERC20 public facicoin;
    address public admin;

    // Estrutura para Mentorias (Professores e Egressos)
    struct Mentorship {
        uint256 id;
        address provider; // Endereço do professor/egresso
        string title;
        string description;
        uint256 price; // Preço em FaciCoin
        bool active;
    }

    // Estrutura para Produtos/Benefícios Gerais da Faculdade
    struct Product {
        uint256 id;
        string name;
        uint256 price; // Preço em FaciCoin
        uint256 stock;
        bool active;
    }

    uint256 public nextMentorshipId;
    uint256 public nextProductId;

    mapping(uint256 => Mentorship) public mentorships;
    mapping(uint256 => Product) public products;

    event MentorshipCreated(uint256 id, address provider, string title, uint256 price);
    event ProductCreated(uint256 id, string name, uint256 price, uint256 stock);
    event MentorshipPurchased(uint256 mentorshipId, address buyer, address provider, uint256 price);
    event ProductPurchased(uint256 productId, address buyer, uint256 price);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Apenas o admin pode realizar esta acao");
        _;
    }

    constructor(address _facicoinAddress) {
        facicoin = ERC20(_facicoinAddress);
        admin = msg.sender;
    }

    // -----------------------------------------
    // Gestão de Mentorias (Professores e Egressos)
    // -----------------------------------------
    
    // Qualquer pessoa (professor/egresso) pode cadastrar uma mentoria
    function createMentorship(string memory _title, string memory _description, uint256 _price) public {
        require(_price > 0, "O preco deve ser maior que zero");
        
        uint256 id = nextMentorshipId++;
        mentorships[id] = Mentorship({
            id: id,
            provider: msg.sender,
            title: _title,
            description: _description,
            price: _price,
            active: true
        });

        emit MentorshipCreated(id, msg.sender, _title, _price);
    }

    // Comprar / Agendar Mentoria
    function buyMentorship(uint256 _id) public {
        Mentorship storage mentoria = mentorships[_id];
        require(mentoria.active, "Mentoria inativa ou nao existe");
        require(mentoria.provider != msg.sender, "Nao pode comprar propria mentoria");

        // Transfere as moedas do comprador para o provedor da mentoria
        require(
            facicoin.transferFrom(msg.sender, mentoria.provider, mentoria.price),
            "Falha na transferencia de FaciCoins"
        );

        emit MentorshipPurchased(_id, msg.sender, mentoria.provider, mentoria.price);
    }

    // Ativar/Desativar mentoria
    function toggleMentorshipActive(uint256 _id) public {
        Mentorship storage mentoria = mentorships[_id];
        require(msg.sender == mentoria.provider || msg.sender == admin, "Sem permissao");
        mentoria.active = !mentoria.active;
    }

    // -----------------------------------------
    // Gestão de Produtos/Benefícios (Faculdade)
    // -----------------------------------------

    // Apenas admin (faculdade) cadastra produtos
    function createProduct(string memory _name, uint256 _price, uint256 _stock) public onlyAdmin {
        require(_price > 0, "O preco deve ser maior que zero");
        
        uint256 id = nextProductId++;
        products[id] = Product({
            id: id,
            name: _name,
            price: _price,
            stock: _stock,
            active: true
        });

        emit ProductCreated(id, _name, _price, _stock);
    }

    // Comprar Produto / Benefício
    function buyProduct(uint256 _id) public {
        Product storage prod = products[_id];
        require(prod.active, "Produto inativo ou nao existe");
        require(prod.stock > 0, "Produto fora de estoque");

        // Transfere as moedas do comprador para a faculdade (admin)
        require(
            facicoin.transferFrom(msg.sender, admin, prod.price),
            "Falha na transferencia de FaciCoins"
        );

        prod.stock -= 1;

        emit ProductPurchased(_id, msg.sender, prod.price);
    }

    // Adicionar estoque em um produto existente
    function addProductStock(uint256 _id, uint256 _amount) public onlyAdmin {
        products[_id].stock += _amount;
    }

    // Ativar/Desativar produto
    function toggleProductActive(uint256 _id) public onlyAdmin {
        products[_id].active = !products[_id].active;
    }
}


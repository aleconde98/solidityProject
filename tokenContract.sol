// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IAidDollarToken {
    event Transfer(address indexed from, address indexed to, uint256 tokens);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    event NewAuthSet(address newAuthAddress);

    event AuthRemoved(address oldAuthAddress);

    event NewCollectorSet(address newCollectorAddress);

    event CollectorRemoved(address oldCollectorAddress);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address source, address spender)
        external
        view
        returns (uint256);

    function fundAddress(address to, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function spendToken(
        address sourceAddress,
        uint256 amount,
        address destinyAddress
    ) external returns (bool);

    function authorizeNew(address addressToAdd) external returns (bool);

    function authorizeRemove(address addressToRemove) external returns (bool);

    function checkAuthorized(address addressToCheck)
        external
        view
        returns (bool);

    function collectorNew(address addressToAdd) external returns (bool);

    function collectorRemove(address addressToRemove) external returns (bool);

    function checkCollector(address addressToCheck)
        external
        view
        returns (bool);
}

contract AidDollarToken is IAidDollarToken {
    //nombre del token
    string private _name;

    //Símbolo del token
    string private _symbol;

    //Decimales del token
    uint8 private _decimals;

    //oferta máxima (número máximo de token disponibles)
    uint256 private _totalSupply;

    //Balance de las cuentas
    mapping(address => uint256) private _balances;

    //Autorizaciones de pago/préstamos
    mapping(address => mapping(address => uint256)) private _allowances;

    //Usuarios operadores, con privilegios de gestión del contrato
    mapping(address => bool) private _authorized;

    //Direcciones a las que el usuario común puede enviar dinero
    mapping(address => bool) private _canCollect;

    //Dueño del contrato
    address public owner;

    //constructor, el dueño del contrato recibe todos los fondos iniciales
    constructor() {
        owner = msg.sender;
        _symbol = "AIDUSD";
        _name = "Aid-USD";
        _totalSupply = 1000000000000;
        _decimals = 0;
        _balances[owner] = _totalSupply;
        emit Transfer(address(0), owner, _totalSupply);
    }

    //Recuperar datos del token: nombre, símbolo, decimales, suministro
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    //Comprobar balance de las cuentas
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    //Comprobar préstamos
    function allowance(address source, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[source][spender];
    }

    //Alimentar una cuenta con fondos (desde la cuenta base)
    function fundAddress(address to, uint256 amount)
        public
        virtual
        override
        onlyOwnerOrAuthorized
        returns (bool)
    {
        _transfer(owner, to, amount);
        return true;
    }

    //Autorizar préstamo de fondos
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address source = msg.sender;
        _approve(source, spender, amount);
        return true;
    }

    //Gastar (sólo en direcciones autorizadas)
    function spendToken(
        address sourceAddress,
        uint256 amount,
        address destinyAddress
    ) public virtual override returns (bool) {
        require(
            checkCollector(destinyAddress) || checkAuthorized(destinyAddress),
            "Can't transfer to non unauthorized collector or operator address"
        );
        address spender = msg.sender;
        _spendAllowance(sourceAddress, spender, amount);
        _transfer(sourceAddress, destinyAddress, amount);
        return true;
    }

    //Autorizar nuevo operador con privilegios
    function authorizeNew(address addressToAdd)
        public
        virtual
        override
        onlyOwner
        returns (bool)
    {
        _authorized[addressToAdd] = true;
        emit NewAuthSet(addressToAdd);
        return true;
    }

    //Desautorizar operador con privilegios
    function authorizeRemove(address addressToRemove)
        public
        virtual
        override
        onlyOwner
        returns (bool)
    {
        if (_authorized[addressToRemove]) {
            _authorized[addressToRemove] = false;
            emit AuthRemoved(addressToRemove);
        }
        return true;
    }

    //Autorizar nuevo cobrador
    function collectorNew(address addressToAdd)
        public
        virtual
        override
        onlyOwnerOrAuthorized
        returns (bool)
    {
        _canCollect[addressToAdd] = true;
        emit NewCollectorSet(addressToAdd);
        return true;
    }

    //Desautorizar cobrador
    function collectorRemove(address addressToRemove)
        public
        virtual
        override
        onlyOwnerOrAuthorized
        returns (bool)
    {
        if (_canCollect[addressToRemove]) {
            _canCollect[addressToRemove] = false;
            emit CollectorRemoved(addressToRemove);
        }
        return true;
    }

    //Comprobar autorización operador
    function checkAuthorized(address addressToCheck)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _authorized[addressToCheck];
    }

    //Comprobar autorización de cobrador
    function checkCollector(address addressToCheck)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _canCollect[addressToCheck];
    }

    //Gastar préstamoD
    function _spendAllowance(
        address source,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = allowance(source, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(source, spender, currentAllowance - amount);
            }
        }
    }

    //Aprobar préstamo (función interna)
    function _approve(
        address source,
        address spender,
        uint256 amount
    ) internal {
        require(source != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[source][spender] = amount;
        emit Approval(source, spender, amount);
    }

    //transferencia (función interna)
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    //modificadores de autorización
    modifier onlyOwnerOrAuthorized() {
        require(
            msg.sender == owner || checkAuthorized(msg.sender),
            "Not available except for the contract owner and other authorized operators"
        );

        _;
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Not available except for the contract owner"
        );

        _;
    }
}

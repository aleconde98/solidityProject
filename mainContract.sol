// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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

    function authorizeNew(address _addressToAdd) external returns (bool);

    function authorizeRemove(address _addressToRemove) external returns (bool);

    function checkAuthorized(address _addressToCheck)
        external
        view
        returns (bool);

    function collectorNew(address _addressToAdd) external returns (bool);

    function collectorRemove(address _addressToRemove) external returns (bool);

    function checkCollector(address _addressToCheck)
        external
        view
        returns (bool);
}

contract AidUnifiedCollection {
    //Estructura información de dirección
    struct AddressInfo {
        string mainIdentification;
        string other;
        uint256 updatedAt;
    }

    //Estructura información donación
    struct DonationInfo {
        uint256 usdAmount;
        uint256 time;
    }

    //Eventos notificación
    event NewAuthSet(address newAuthAddress);

    event AuthRemoved(address oldAuthAddress);

    event NewReaderSet(address newCollectorAddress);

    event ReaderRemoved(address oldCollectorAddress);

    //Contrato del token
    IAidDollarToken _aidDollarToken;

    //mapping donaciones en USD
    mapping(address => DonationInfo[]) public addressDonations;

    //mapping carteras registradas comprobación
    mapping(address => bool) private _addressRegistered;

    //mapping carteras registradas info
    mapping(address => AddressInfo) private _addressInformation;

    //mapping operadores con privilegios
    mapping(address => bool) private _authorized;

    //mapping
    mapping(address => bool) private _canReadInfo;

    //Dueño
    address public owner;

    //Mínimo para registro
    uint256 public minimumDonationRegister;

    constructor(address _tokenAddress, uint256 _minimumRegister) {
        owner = msg.sender;
        _aidDollarToken = IAidDollarToken(_tokenAddress);
        minimumDonationRegister = _minimumRegister;
    }

    //Donar
    function donate(address destinyAddress) public payable {
        require(
            _aidDollarToken.checkCollector(destinyAddress),
            "Not an authorized fund collector"
        );

        payable(destinyAddress).transfer(msg.value);

        uint256 wholeDollarsDonated = getConversionRate(msg.value);

        _aidDollarToken.fundAddress(msg.sender, wholeDollarsDonated);

        if (
            wholeDollarsDonated > minimumDonationRegister &&
            checkRegistered(msg.sender)
        ) {
            addressDonations[msg.sender].push(
                DonationInfo({
                    usdAmount: wholeDollarsDonated,
                    time: block.timestamp
                })
            );
        }
    }

    //Registrar donante + primera donación
    function donateAndFirstRegister(
        string memory mainIdentification,
        string memory other,
        address destinyAddress
    ) public payable {
        require(
            _aidDollarToken.checkCollector(destinyAddress),
            "Not an authorized fund collector"
        );

        payable(destinyAddress).transfer(msg.value);

        uint256 wholeDollarsDonated = getConversionRate(msg.value);

        _aidDollarToken.fundAddress(msg.sender, wholeDollarsDonated);

        if (wholeDollarsDonated > minimumDonationRegister) {
            _addressRegistered[msg.sender] = true;
            _addressInformation[msg.sender] = AddressInfo({
                mainIdentification: mainIdentification,
                other: other,
                updatedAt: block.timestamp
            });

            addressDonations[msg.sender].push(
                DonationInfo({
                    usdAmount: wholeDollarsDonated,
                    time: block.timestamp
                })
            );
        }
    }

    //Editar info donante
    function editInfo(string memory mainIdentification, string memory other)
        public
        returns (bool)
    {
        require(_addressRegistered[msg.sender], "Not registered");

        _addressInformation[msg.sender] = AddressInfo({
            mainIdentification: mainIdentification,
            other: other,
            updatedAt: block.timestamp
        });

        return true;
    }

    //Comprobar si el usuario está registrado
    function checkRegistered(address _addressToCheck)
        public
        view
        returns (bool)
    {
        return _addressRegistered[_addressToCheck];
    }

    //Obtener info de donante
    function getAccountInfo(address addressToCheck)
        public
        view
        returns (AddressInfo memory)
    {
        require(
            msg.sender == addressToCheck || checkReader(msg.sender),
            "Unauthorized to read that info"
        );
        require(checkRegistered(addressToCheck), "User not registered");
        return _addressInformation[addressToCheck];
    }

    //Obtener donaciones de una cuenta
    function getAccountDonations(address addressToCheck)
        public
        view
        returns (DonationInfo[] memory)
    {
        require(checkRegistered(addressToCheck), "User not registered");
        return addressDonations[addressToCheck];
    }

    //Autorizar nuevo operador con privilegios
    function authorizeNew(address addressToAdd)
        public
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
        onlyOwner
        returns (bool)
    {
        if (_authorized[addressToRemove]) {
            _authorized[addressToRemove] = false;
            emit AuthRemoved(addressToRemove);
        }
        return true;
    }

    //Autorizar nuevo lector de datos
    function readerNew(address addressToAdd)
        public
        onlyOwnerOrAuthorized
        returns (bool)
    {
        _canReadInfo[addressToAdd] = true;
        emit NewReaderSet(addressToAdd);
        return true;
    }

    //Desautorizar lector
    function readerRemove(address addressToRemove)
        public
        onlyOwnerOrAuthorized
        returns (bool)
    {
        if (_canReadInfo[addressToRemove]) {
            _canReadInfo[addressToRemove] = false;
            emit ReaderRemoved(addressToRemove);
        }
        return true;
    }

    //Comprobar autorizados
    function checkAuthorized(address addressToCheck)
        public
        view
        returns (bool)
    {
        return _authorized[addressToCheck];
    }

    //Comprobar lectores
    function checkReader(address addressToCheck) public view returns (bool) {
        return _canReadInfo[addressToCheck];
    }

    //Cambiar mínimo
    function changeMinAmount(uint256 newAmount)
        public
        onlyOwnerOrAuthorized
        returns (bool)
    {
        minimumDonationRegister = newAmount;
        return true;
    }

    //Funciones de conversión ETH -> USD (chainlink oracle)
    function getVersion() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
        return priceFeed.version();
    }

    function getPrice() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return uint256(answer * 10000000000);
    }

    function getConversionRate(uint256 weiAmount)
        public
        view
        returns (uint256)
    {
        uint256 ethPrice = getPrice();
        uint256 ethAmountInUsd = (ethPrice * weiAmount) / 1000000000000000000 / 1000000000000000000;
        return ethAmountInUsd;
    }

    //Modificadores de autorización
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

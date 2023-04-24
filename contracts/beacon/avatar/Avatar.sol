// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC721EnumerableUpgradeable } from "openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";



contract Avatar is OwnableUpgradeable, AccessControlUpgradeable, ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable {

    /**
     * @notice Event emitted when the contract was initialized.
     * @dev emitted at proxy startup, once only
     * @param baseURI an URI that will be used as the base for token URI
     * @param _name name of the ERC721 token
     * @param _symbol token symbol of the ERC721 token
     * @param _sandOwner address belonging to SAND token owner
     * @param _signAddress signer address that is allowed to mint
     * @param _maxSupply max supply of tokens to be allowed to be minted per contract
     * @param _registry filter registry to which to register with. For blocking operators that do not respect royalties
     * @param _operatorFiltererSubscription subscription address to use as a template for
     * @param _operatorFiltererSubscriptionSubscribe if to subscribe tot the operatorFiltererSubscription address or
     *                                               just copy entries from it
     */
    event ContractInitialized(
        string baseURI,
        string _name,
        string _symbol,
        address _sandOwner,
        address _signAddress,
        uint256 _maxSupply,
        address _registry,
        address _operatorFiltererSubscription,
        bool _operatorFiltererSubscriptionSubscribe
    );

    /**
     * @notice Event emitted when the base token URI for the contract was set or changed
     * @dev emitted when setBaseURI is called
     * @param baseURI an URI that will be used as the base for token URI
     */
    event BaseURISet(string baseURI);

    string public baseTokenURI;

    constructor() {
        _disableInitializers();
    }

    function __AvatarCollection_init(
        address _collectionOwner,
        string memory _initialBaseURI,
        string memory _name,
        string memory _symbol,
        address payable _sandOwner,
        address _signAddress,
        address _trustedForwarder,
        address _registry,
        address _operatorFiltererSubscription,
        bool _operatorFiltererSubscriptionSubscribe,
        uint256 _maxSupply) internal onlyInitializing {

        require(bytes(_initialBaseURI).length != 0, "BaseURI is not set");
        require(bytes(_name).length != 0, "Name cannot be empty");
        require(bytes(_symbol).length != 0, "Symbol cannot be empty");
        require(_signAddress != address(0x0), "Sign address is zero address");
        require(_trustedForwarder != address(0x0), "Trusted forwarder is zero address");
        require(_sandOwner != address(0x0), "Sand owner is zero address");
        require(_maxSupply > 0, "Max supply should be more than 0");

        baseTokenURI = _initialBaseURI;


        __ERC721_init(_name, _symbol);
        // __ERC2771Handler_initialize(_trustedForwarder);
        __Ownable_init_unchained();
        __ReentrancyGuard_init();
        // __UpdatableOperatorFiltererUpgradeable_init(
        //     _registry,
        //     _operatorFiltererSubscription,
        //     _operatorFiltererSubscriptionSubscribe
        // );
        __AccessControl_init_unchained();

        // sandOwner = _sandOwner;
        // signAddress = _signAddress;
        // maxSupply = _maxSupply;

        // emit ContractInitialized(
        //     baseURI,
        //     _name,
        //     _symbol,
        //     _sandOwner,
        //     _signAddress,
        //     _maxSupply,
        //     _registry,
        //     _operatorFiltererSubscription,
        //     _operatorFiltererSubscriptionSubscribe
        // );


        // CollectionFactory is the owner and made the call, need to change it to the designated owner
        transferOwnership(_collectionOwner);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        require(bytes(baseURI).length != 0, "baseURI is not set");
        baseTokenURI = baseURI;
        emit BaseURISet(baseURI);
    }

    /**
     * @notice get base TokenURI
     * @dev returns baseTokenURI
     * @return baseTokenURI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function initialize(
        string memory _initialBaseURI,
        string memory _name,
        string memory _symbol,
        address payable _sandOwner,
        address _signAddress,
        address _trustedForwarder,
        address _registry,
        address _operatorFiltererSubscription,
        bool _operatorFiltererSubscriptionSubscribe,
        uint256 _maxSupply
    ) external virtual initializer {
        __AvatarCollection_init(
            msg.sender,
            _initialBaseURI,
            _name,
            _symbol,
            _sandOwner,
            _signAddress,
            _trustedForwarder,
            _registry,
            _operatorFiltererSubscription,
            _operatorFiltererSubscriptionSubscribe,
            _maxSupply
        );
    }
}
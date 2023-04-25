// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import { ERC721EnumerableUpgradeable, ERC721Upgradeable, IERC721Upgradeable } from "openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
// import { UpdatableOperatorFiltererUpgradeable } from "operator-filter-registry/upgradeable/UpdatableOperatorFiltererUpgradeable.sol";


contract Avatar is OwnableUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable, ERC721EnumerableUpgradeable
    //  , UpdatableOperatorFiltererUpgradeable 
    {

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

    /// @notice max token supply
    uint256 public maxSupply;
    string public baseTokenURI;
    address public allowedToExecuteMint;
    address public sandOwner;
    address public signAddress;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant CONFIGURATOR = keccak256("CONFIGURATOR");
    bytes32 public constant TRANSFORMER = keccak256("TRANSFORMER");

    /*//////////////////////////////////////////////////////////////
                           Constructor / Initializers
    //////////////////////////////////////////////////////////////*/

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

        // __ERC2771Handler_initialize(_trustedForwarder);
        __ERC721_init(_name, _symbol);
        __ReentrancyGuard_init();
        __AccessControl_init_unchained();

        // CollectionFactory is the owner and made the call, need to change it to the designated owner
        // call to __Ownable_init_unchained() is not helpfull as we want to set owner to a specific address, not msg.sender
        transferOwnership(_collectionOwner); // also checks for "new owner is the zero address"

        // __UpdatableOperatorFiltererUpgradeable_init(
        //     _registry,
        //     _operatorFiltererSubscription,
        //     _operatorFiltererSubscriptionSubscribe
        // );

        sandOwner = _sandOwner;
        signAddress = _signAddress;
        maxSupply = _maxSupply;

        // grants the collection owner the ADMIN role
        _grantRole(ADMIN, _collectionOwner);
        
        // makes ADMIN role holders be able to modify/configure the other rols
        _setRoleAdmin(CONFIGURATOR, ADMIN);
        _setRoleAdmin(TRANSFORMER, ADMIN);

        emit ContractInitialized(
            _initialBaseURI,
            _name,
            _symbol,
            _sandOwner,
            _signAddress,
            _maxSupply,
            _registry,
            _operatorFiltererSubscription,
            _operatorFiltererSubscriptionSubscribe
        );
    }

    function initialize(
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
        uint256 _maxSupply
    ) external virtual initializer {
        __AvatarCollection_init(
            _collectionOwner,
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


    /*//////////////////////////////////////////////////////////////
                    External and public functions
    //////////////////////////////////////////////////////////////*/


    function setBaseURI(string memory baseURI) public onlyOwner {
        require(bytes(baseURI).length != 0, "baseURI is not set");
        baseTokenURI = baseURI;
        emit BaseURISet(baseURI);
    }

    
    // /**
    //  * @dev See OpenZeppelin {IERC721-setApprovalForAll}
    //  */
    // function setApprovalForAll(address operator, bool approved)
    //     public
    //     override(ERC721Upgradeable, IERC721Upgradeable)
    //     onlyAllowedOperatorApproval(operator)
    // {
    //     super.setApprovalForAll(operator, approved);
    // }

    // /**
    //  * @dev See OpenZeppelin {IERC721-approve}
    //  */
    // function approve(address operator, uint256 tokenId)
    //     public
    //     override(ERC721Upgradeable, IERC721Upgradeable)
    //     onlyAllowedOperatorApproval(operator)
    // {
    //     super.approve(operator, tokenId);
    // }

    // /**
    //  * @dev See OpenZeppelin {IERC721-transferFrom}
    //  */
    // function transferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
    //     super.transferFrom(from, to, tokenId);
    // }

    // /**
    //  * @dev See OpenZeppelin {IERC721-safeTransferFrom}
    //  */
    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
    //     super.safeTransferFrom(from, to, tokenId);
    // }

    // /**
    //  * @dev See OpenZeppelin {IERC721-safeTransferFrom}
    //  */
    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory data
    // ) public override(ERC721Upgradeable, IERC721Upgradeable) onlyAllowedOperator(from) {
    //     super.safeTransferFrom(from, to, tokenId, data);
    // }

    /*//////////////////////////////////////////////////////////////
                           View functions
    //////////////////////////////////////////////////////////////*/

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

}
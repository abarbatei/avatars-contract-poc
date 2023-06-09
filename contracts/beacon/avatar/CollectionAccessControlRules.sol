// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

import { Ownable2StepUpgradeable } from "openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";


import { OwnableUpgradeable } from "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";


import { IERC5313 } from "../interfaces/IERC5313.sol";


// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlDefaultAdminRules.sol

abstract contract CollectionAccessControlRules is AccessControlUpgradeable, OwnableUpgradeable {

    // keccak256("ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;
    
    // keccak256("CONFIGURATOR_ROLE")
    bytes32 public constant CONFIGURATOR_ROLE = 0x3b49a237fe2d18fa4d9642b8a0e065923cceb71b797783b619a030a61d848bf0;
    
    // keccak256("TRANSFORMER_ROLE")
    bytes32 public constant TRANSFORMER_ROLE = 0x69fc995a7cdbc94c95dc768dfaa8ceead6003727063f7d665556608319262298;

    address private _pendingOwner;

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Modifier used to check if the send is has been granted the specific role, or if it is the owner that called
     * @param role the role to check for
     */
    modifier authorizedRole(bytes32 role) {
        address sender = _msgSender();
        require(hasRole(role, sender) || owner() == sender);
        _;
    }

    function __InitializeAccessControl(address owner_) internal initializer {
        require(owner_ != address(0), "CollectionAccessControlRules: new owner is the zero address");
        
        __AccessControl_init();        

        _transferOwnership(owner_);        
        _grantRole(ADMIN_ROLE, owner_);
        
        // makes ADMIN_ROLE role holders be able to modify/configure the other rols
        _setRoleAdmin(CONFIGURATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(TRANSFORMER_ROLE, ADMIN_ROLE);
    }

    function addConfigurator(address account) external onlyOwner {
        require(account != address(0), "CollectionAccessControlRules: account is zero address");
        super.grantRole(CONFIGURATOR_ROLE, account);
    }

    function revokeConfiguratorRole(address account) onlyOwner external {
        super.revokeRole(CONFIGURATOR_ROLE, account);
    }

    function addTransformer(address account) external onlyOwner {
        require(account != address(0), "CollectionAccessControlRules: account is zero address");
        super.grantRole(TRANSFORMER_ROLE, account);
    }

    function revokeTransformerRole(address account) onlyOwner external {
        super.revokeRole(TRANSFORMER_ROLE, account);
    }

    function acceptOwnership() external {
        address sender = _msgSender();
        require(pendingOwner() == sender, "CollectionAccessControlRules: caller is not the new owner");

        super.revokeRole(ADMIN_ROLE, owner());
        super.grantRole(ADMIN_ROLE, sender);

        _transferOwnership(sender);
    }

    /**
     * @dev Returns the address of the pending owner.
     */
    function pendingOwner() public view virtual returns (address) {
        return _pendingOwner;
    }

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
        _pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner(), newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual override {
        delete _pendingOwner;
        super._transferOwnership(newOwner);
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("CollectionAccessControlRules: Renounce ownership is not available");
    }
}
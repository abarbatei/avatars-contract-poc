// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import { IERC5313 } from "openzeppelin/interfaces/IERC5313.sol";


// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlDefaultAdminRules.sol

contract CollectionAccessControlRules is AccessControlUpgradeable {

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR_ROLE");
    bytes32 public constant TRANSFORMER_ROLE = keccak256("TRANSFORMER_ROLE");

    address internal _owner;

    function __InitializeAccessControl(address collectionOwner) internal initializer {
        require(collectionOwner != address(0x0), "CollectionAccessControlRules: owner cannot be 0x0 address");
        __AccessControl_init();
        
        _grantRole(ADMIN_ROLE, collectionOwner);
        _owner = collectionOwner;
        
        // makes ADMIN_ROLE role holders be able to modify/configure the other rols
        _setRoleAdmin(CONFIGURATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(TRANSFORMER_ROLE, ADMIN_ROLE);
    }

    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) {
        require(role != ADMIN_ROLE, "CollectionAccessControlRules: can't directly grant owner role");
        super.grantRole(role, account);
    }

    /**
     * @dev See {AccessControl-revokeRole}. Reverts for `DEFAULT_ADMIN_ROLE`.
     */
    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) {
        require(role != ADMIN_ROLE, "CollectionAccessControlRules: can't directly revoke owner role");
        super.revokeRole(role, account);
    }

    /**
     * @dev See {IERC5313-owner}.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { AccessControlUpgradeable } from "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";

// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlDefaultAdminRules.sol

contract CollectionAccessControlRules is AccessControlUpgradeable {

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant CONFIGURATOR = keccak256("CONFIGURATOR");
    bytes32 public constant TRANSFORMER = keccak256("TRANSFORMER");

    address internal maneger;
    address internal collectionOwner;

    function __InitializeManagement(address manager, address _collectionOwner) internal initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, manager);

        _maneger = manager;
        
        _grantRole(ADMIN, _collectionOwner);
        
        // makes ADMIN role holders be able to modify/configure the other rols
        _setRoleAdmin(CONFIGURATOR, ADMIN);
        _setRoleAdmin(TRANSFORMER, ADMIN);
    }

    function grantRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) {
        require(role != DEFAULT_ADMIN_ROLE, "CollectionAccessControlRules: can't directly grant default admin role");
        super.grantRole(role, account);
    }

    /**
     * @dev See {AccessControl-revokeRole}. Reverts for `DEFAULT_ADMIN_ROLE`.
     */
    function revokeRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) {
        require(role != DEFAULT_ADMIN_ROLE, "CollectionAccessControlRules: can't directly revoke default admin role");
        super.revokeRole(role, account);
    }

    /**
     * @dev See {AccessControl-renounceRole}.
     *
     * For the `DEFAULT_ADMIN_ROLE`, it only allows renouncing in two steps by first calling
     * {beginDefaultAdminTransfer} to the `address(0)`, so it's required that the {pendingDefaultAdmin} schedule
     * has also passed when calling this function.
     *
     * After its execution, it will not be possible to call `onlyRole(DEFAULT_ADMIN_ROLE)` functions.
     *
     * NOTE: Renouncing `DEFAULT_ADMIN_ROLE` will leave the contract without a {defaultAdmin},
     * thereby disabling any functionality that is only available for it, and the possibility of reassigning a
     * non-administrated role.
     */
    function renounceRole(bytes32 role, address account) public virtual override(AccessControlUpgradeable) {
        if (role == DEFAULT_ADMIN_ROLE) {
            require(
                newDefaultAdmin == address(0) && _isScheduleSet(schedule) && _hasSchedulePassed(schedule),
                "AccessControl: only can renounce in two delayed steps"
            );
        }
        super.renounceRole(role, account);
    }

    /**
     * @dev See {IERC5313-owner}.
     */
    function owner() public view virtual returns (address) {
        return collectionOwner;
    }

    function defaultAdmin() public view virtual returns (address) {
        return maneger;
    }
}
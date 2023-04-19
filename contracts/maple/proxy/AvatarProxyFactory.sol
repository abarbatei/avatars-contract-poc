// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.15;

import { ProxyFactory } from "proxy-factory/ProxyFactory.sol";
import { IMapleProxied } from "src/interfaces/IMapleProxied.sol";
import { IAvatarProxyFactory } from "../interfaces/IAvatarProxyFactory.sol";        
import { Ownable } from "openzeppelin/access/Ownable.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";



contract AvatarProxyFactory is IAvatarProxyFactory, ProxyFactory, Ownable, Pausable {

    uint256 public override defaultVersion;

    mapping(address => bool) public override isInstance;

    mapping(uint256 => mapping(uint256 => bool)) public override upgradeEnabledForPath;

    constructor() {}

    /**************************************************************************************************************************************/
    /*** Admin Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) public override virtual onlyOwner {
        require(fromVersion_ != toVersion_,                              "AVATAR:DUP:OVERWRITING_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, address(0)), "AVATAR:DUP:FAILED");

        emit UpgradePathDisabled(fromVersion_, toVersion_);

        upgradeEnabledForPath[fromVersion_][toVersion_] = false;
    }

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) public override virtual onlyOwner {
        require(fromVersion_ != toVersion_,                             "AVATAR:EUP:OVERWRITING_INITIALIZER");
        require(_registerMigrator(fromVersion_, toVersion_, migrator_), "AVATAR:EUP:FAILED");

        emit UpgradePathEnabled(fromVersion_, toVersion_, migrator_);

        upgradeEnabledForPath[fromVersion_][toVersion_] = true;
    }

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_)
        public override virtual onlyOwner
    {
        // Version 0 reserved as "no version" since default `defaultVersion` is 0.
        require(version_ != uint256(0), "AVATAR:RI:INVALID_VERSION");

        emit ImplementationRegistered(version_, implementationAddress_, initializer_);

        require(_registerImplementation(version_, implementationAddress_), "AVATAR:RI:FAIL_FOR_IMPLEMENTATION");

        // Set migrator for initialization, which understood as fromVersion == toVersion.
        require(_registerMigrator(version_, version_, initializer_), "AVATAR:RI:FAIL_FOR_MIGRATOR");
    }

    function setDefaultVersion(uint256 version_) public override virtual onlyOwner {
        // Version must be 0 (to disable creating new instances) or be registered.
        require(version_ == 0 || _implementationOf[version_] != address(0), "AVATAR:SDV:INVALID_VERSION");

        emit DefaultVersionSet(defaultVersion = version_);
    }

    /**************************************************************************************************************************************/
    /*** Instance Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function createInstance(bytes calldata arguments_, bytes32 salt_)
        public override virtual whenNotPaused returns (address instance_)
    {
        bool success;
        ( success, instance_ ) = _newInstance(arguments_, keccak256(abi.encodePacked(arguments_, salt_)));
        require(success, "AVATAR:CI:FAILED");

        isInstance[instance_] = true;

        emit InstanceDeployed(defaultVersion, instance_, arguments_);
    }

    // NOTE: The implementation proxied by the instance defines the access control logic for its own upgrade.
    function upgradeInstance(uint256 toVersion_, bytes calldata arguments_) public override virtual whenNotPaused {
        uint256 fromVersion = _versionOf[IMapleProxied(msg.sender).implementation()];

        require(upgradeEnabledForPath[fromVersion][toVersion_], "AVATAR:UI:NOT_ALLOWED");

        emit InstanceUpgraded(msg.sender, fromVersion, toVersion_, arguments_);

        require(_upgradeInstance(msg.sender, toVersion_, arguments_), "AVATAR:UI:FAILED");
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function getInstanceAddress(bytes calldata arguments_, bytes32 salt_) public view override virtual returns (address instanceAddress_) {
        return _getDeterministicProxyAddress(keccak256(abi.encodePacked(arguments_, salt_)));
    }

    function implementationOf(uint256 version_) public view override virtual returns (address implementation_) {
        return _implementationOf[version_];
    }

    function defaultImplementation() external view override returns (address defaultImplementation_) {
        return _implementationOf[defaultVersion];
    }

    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) public view override virtual returns (address migrator_) {
        return _migratorForPath[oldVersion_][newVersion_];
    }

    function versionOf(address implementation_) public view override virtual returns (uint256 version_) {
        return _versionOf[implementation_];
    }

}

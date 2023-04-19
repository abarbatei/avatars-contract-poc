// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";
import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
import { IERC1967Factory } from "../interfaces/IERC1967Factory.sol";

contract AvatarProxyManager is Ownable2Step, Pausable {

    /**
     * @notice Event emitted when a new implementation:version mapping was added.
     * @dev emitted when addImplementation is called
     * @param implementation the new implementation contract that was added
     * @param version the asociated version of the new implementation
     */
    event NewImplementationAdded(address implementation, uint256 version);

    /**
     * @notice Event emitted when the default implementation version, used in deploying collection, was changed
     * @dev emitted when setDefaultImplementationVersion is called
     * @param oldVersion the old version for the default implementation; 0 means it was unset
     * @param newVersion the new version for the default implementation
     */
    event DefaultImplementationVersionChanged(uint256 oldVersion, uint256 newVersion);

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployDefaultCollection or deployCollection is called
     * @param version the version asociated with the deployed implementation
     * @param implementation the used implementation for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(uint256 version, address implementation, address collectionProxy);

    /**
     * @notice Event emitted when a collection (proxy) was updated (had it's implementation change)
     * @dev emitted when updateCollection or updateCollectionsByVersion is called
     * @param oldVersion the previous version asociated with the deployed implementation
     * @param oldImplementation the previous implementation asociated with the proxy
     * @param newVersion the new implementation version to be asociated with the proxy
     * @param newImplementation the implementation that will be associated with the proxy
     * @param proxyAddress the proxy address whose implementation has changed
     */
    event CollectionUpdated(uint256 oldVersion, address oldImplementation, uint256 newVersion, address newImplementation, address proxyAddress);

    /**
     * @notice Event emitted when a proxy address was removed from this contracts management
     * @dev emitted when removeProxy is called
     * @param proxy the new implementation contract that was added
     */
    event ProxyRemoved(address proxy);

    /// @dev The canonical Solady ERC1967Factory address for EVM chains.
    address internal constant SOLADY_ERC1967_FACTORY_ADDRESS = 0x0000000000006396FF2a80c067f99B3d2Ab4Df24;

    mapping(address => address) public proxyToAdmin;

    mapping(address => uint256) public implementationToVersion;

    mapping(uint256 => address) public versionToImplementation;

    mapping(address => uint256) public proxyToVersion;

    address[] public proxies;

    uint256 defaultImplementationVersion;

    // constructor() {}

    /* TODO
     - decide how to pass admin/constraints to contract
     - what level of access does manager should have
     - is it ok that manager is proxy admin for all
        - should it be changeable?
        - even if changed should manager still have power - yes
     - decide if a remove implementation function is actually needed
     - decide if simple deploy to be supported
     - are there any constructor values needed?
     - make it ERC1967 proxy complient
     - 2 step change owner confirmation
     - add whenNotPause logic (if needed, if all are onlyOwner then don't see the point)
    */

    function addImplementation(address implementation, uint256 version) external onlyOwner {
        require(version != 0, "Version cannot be 0!");
        require(_isContract(implementation), "Implementation must be a deployed contract!");
        require(versionToImplementation[version] == address(0), "Version already exists!");
        require(implementationToVersion[implementation] == 0, "Implementation already exists!");

        implementationToVersion[implementation] = version;
        versionToImplementation[version] = implementation;

        emit NewImplementationAdded(implementation, version);
    }

    function changeDefaultImplementationVersion(uint256 version) external onlyOwner versionExists(version) {
        uint256 oldVersion = defaultImplementationVersion;
        defaultImplementationVersion = version;

        emit DefaultImplementationVersionChanged(oldVersion, defaultImplementationVersion);
    }

    function deployDefaultCollection(bytes calldata initializationArgs) external onlyOwner returns (address) {
        return deployCollection(defaultImplementationVersion, initializationArgs);
    }
    
    function deployCollection(uint256 version, bytes calldata initializationArgs) public onlyOwner versionExists(version) returns (address collectionProxy) {
        address implementation = versionToImplementation[version];
        collectionProxy = IERC1967Factory(SOLADY_ERC1967_FACTORY_ADDRESS).deployAndCall(
            implementation, 
            address(this), 
            initializationArgs);
        
        //  since the call above is not deterministic, we should have only unique resulted proxy addresses         
        proxies.push(collectionProxy);
        proxyToVersion[collectionProxy] = version;

        emit CollectionDeployed(version, implementation, collectionProxy);

    }

    function updateCollection(address proxyAddress, uint256 version) external onlyOwner versionExists(version) {
        _updateCollection(proxyAddress, version);
    }

    function updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        external 
        onlyOwner 
        versionExists(targetVersion) 
        versionExists(newVersion) {
        uint256 collectionCount = proxies.length; 
        // @audit check maximum length before out of gass, depending on that, another way of doing this may be required
        for (uint256 index; index < collectionCount;) {
            address proxy = proxies[index];
            uint256 proxyVersion = proxyToVersion[proxy];
            if (proxyVersion == targetVersion) {
                _updateCollection(proxy, newVersion);
            }

            unchecked {
                ++index;
            }
        }
    }

    /// no checks here
    function _updateCollection(address proxyAddress, uint256 version) private {
        uint256 oldVersion = proxyToVersion[proxyAddress];
        address oldImplementation = versionToImplementation[oldVersion];
        address newImplementation = versionToImplementation[version];

        IERC1967Factory(SOLADY_ERC1967_FACTORY_ADDRESS).upgrade(proxyAddress, newImplementation);

        emit CollectionUpdated(oldVersion, oldImplementation, version, newImplementation, proxyAddress);

    }

    // @audit probably to be changed with a disable proxy, not remove it
    function removeProxy(address proxy) external onlyOwner {
        require(proxyToVersion[proxy] != 0, "Proxy does not exist!");
        uint256 proxiesLength = proxies.length;
        for (uint256 index; index < proxiesLength;) {
            if (proxies[index] == proxy) {
                proxies[index] = proxies[proxiesLength - 1];
                proxies.pop();
                break;
            }
            unchecked {
                ++index;
            }
        }

        proxyToVersion[proxy] = 0;
        emit ProxyRemoved(proxy);
    }
    
    ////////////////////////////////////////////////// VIEW and HELPER functions //////////////////////////////////////////////////
    function implementationExists(address implementation) public view returns (bool) {
        return implementationToVersion[implementation] != 0;
    }
    
    function getImplementationVersion(address implementation) external view returns (uint256) {
        if (!implementationExists(implementation)) revert("Implementation does not exists!");
        return implementationToVersion[implementation];
    }

    /// @dev Returns the admin of the proxy.
    function adminOf(address proxy) external view returns (address proxyOwner) {
        proxyOwner = proxyToAdmin[proxy];
        require(proxyOwner != address(0), "Address not tracked!");
    }

    /// @dev Returns whether the account is currently a contract.
    function _isContract(address account_) internal view returns (bool) {
         return account_.code.length != uint256(0);
    }

    modifier versionExists(uint256 version) {
        require(versionToImplementation[version] != address(0), "Version does not exist!");
        _;
    }

}


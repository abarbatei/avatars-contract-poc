// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
// import { BeaconProxy } from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import { CollectionProxy } from "./CollectionProxy.sol";

contract CollectionFactory is Ownable2Step, Pausable {

    /**
     * @notice Event emitted when a new implementation:version mapping was added.
     * @dev emitted when addImplementation is called
     * @param implementation the new implementation contract that was added
     * @param version the asociated version of the new implementation
     */
    event NewImplementationAdded(address implementation, uint256 version);

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployDefaultCollection or deployCollection is called
     * @param version the version asociated with the deployed implementation
     * @param beaconAddress the used beacon address for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(uint256 version, address beaconAddress, address collectionProxy);

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

    uint256 versionsCount;

    uint256[] public versions;

    mapping(address => address) public proxyToAdmin;

    mapping(uint256 => address) public versionToImplementation;

    mapping(address => uint256) public implementationToVersion;

    mapping(uint256 => address) public versionToBeacon;

    mapping(address => uint256) public proxyToVersion;

    /// @dev how many proxies are refferencing this beacon
    mapping(address => uint256) public beaconProxyRefferences;

    constructor() {

    }


    function addImplementation(address implementation, uint256 version) external onlyOwner {
        require(version != 0, "Version cannot be 0!");
        require(versionToImplementation[version] == address(0), "Version already exists!");
        require(implementationToVersion[implementation] == 0, "Implementation already exists!");

        implementationToVersion[implementation] = version;
        versionToImplementation[version] = implementation;

        versions.push(version);
        versionsCount = versions.length;

        emit NewImplementationAdded(implementation, version);
    }

    function deployCollection(uint256 version, bytes calldata initializationArgs) 
        public 
        onlyOwner 
        versionExists(version) 
        returns (address collection)  
    {   

        address implementation = versionToImplementation[version];
        
        // if there already exists a beacon with this implementation, reuse it
        // otherwise deploy a new beacon with this implementation
        address beacon = versionToBeacon[version];
        if (beacon == address(0)) {
            beacon = _addBeacon(implementation, version);
        }

        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);
        
        proxyToVersion[collection] = version;

        emit CollectionDeployed(version, beacon, collection);

    }

    function _addBeacon(address implementation, uint256 version) internal returns (address beacon) {
            beacon = address(new UpgradeableBeacon(implementation));
            versionToBeacon[version] = beacon;
            beaconProxyRefferences[beacon] += 1;
    }

    function updateCollection(address proxyAddress, uint256 toVersion, bytes memory data) 
        external 
        onlyOwner 
        versionExists(toVersion) 
    {
        uint256 currentVersion = proxyToVersion[proxyAddress];
        address currentBeacon = versionToBeacon[currentVersion];
        address currentImplementation = versionToImplementation[currentVersion];

        address newImplementation = versionToImplementation[toVersion];
        uint256 refferecingProxies = beaconProxyRefferences[currentBeacon];

        if (refferecingProxies == 1) {
            // if only 1 proxy is reffereing this beacon (meaning the current one), 
            // change the implementation of the beacon to the new one
            UpgradeableBeacon(currentBeacon).upgradeTo(newImplementation);
        } else {
            // else create a new beacon
            address newBeacon = _addBeacon(newImplementation, toVersion);
            
            // make the proxy point to this new beacon
            CollectionProxy(payable(proxyAddress)).changeBeacon(newBeacon, data);
            
            // update the old beacon refferencing
            beaconProxyRefferences[currentBeacon] -= 1;            
        }
        
        emit CollectionUpdated(currentVersion, currentImplementation, toVersion, newImplementation, proxyAddress);
    }

    function updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        external 
        onlyOwner 
        versionExists(targetVersion) 
        versionExists(newVersion) 
    {
        _updateCollectionsByVersion(targetVersion, newVersion);
    }

    function updateAllCollections(uint256 newVersion) 
        external 
        onlyOwner  
        versionExists(newVersion) 
    {
        uint256 collectionCount = versionsCount; 
        for (uint256 index; index < collectionCount;) {
            uint256 version = versions[index];
            _updateCollectionsByVersion(version, newVersion);
            unchecked {
                ++index;
            }
        }
    }

    function _updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        internal 
    {
        address beacon = versionToBeacon[targetVersion];
        address newImplementation = versionToImplementation[newVersion];
        UpgradeableBeacon(beacon).upgradeTo(newImplementation);
    }


    ////////////////////////////////////////////////// VIEW and HELPER functions //////////////////////////////////////////////////

    /// @dev Returns the admin of the proxy.
    function adminOf(address proxy) external view returns (address proxyOwner) {
        proxyOwner = proxyToAdmin[proxy];
        require(proxyOwner != address(0), "Address not tracked!");
    }


    modifier versionExists(uint256 version) {
        require(versionToBeacon[version] != address(0), "Version does not exist!");
        _;
    }
}
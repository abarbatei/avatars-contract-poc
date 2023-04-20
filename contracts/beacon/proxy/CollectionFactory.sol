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
     * @param newBeacon the beacon address that is associated with the new implementation
     * @param implementation the new implementation contract that was added
     * @param version the asociated version of the new implementation
     */
    event NewImplementationAdded(address newBeacon, address implementation, uint256 version);

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
    CollectionProxy[] public collections;

    mapping(address => address) public proxyToAdmin;

    mapping(address => address) public implementationToBeacon;

    mapping(address => address) public beaconToImplementation;

    mapping(uint256 => address) public versionToBeacon;

    mapping(address => uint256) public beaconToVersion;

    mapping(address => uint256) public proxyToVersion;

    constructor() {

    }


    function addImplementation(address implementation, uint256 version) external onlyOwner {
        require(version != 0, "Version cannot be 0!");
        require(versionToBeacon[version] == address(0), "Version already exists!");
        require(implementationToBeacon[implementation] == address(0), "Implementation already exists!");

        address newBeacon = address(new UpgradeableBeacon(implementation));
        beaconToVersion[newBeacon] = version;
        versionToBeacon[version] = newBeacon;
        implementationToBeacon[implementation] = newBeacon;
        beaconToImplementation[newBeacon] = implementation;

        versions.push(version);
        versionsCount = versions.length;

        emit NewImplementationAdded(newBeacon, implementation, version);
    }

    function deployCollection(uint256 version, bytes calldata initializationArgs) 
        public 
        onlyOwner 
        versionExists(version) 
        returns (address collection)  
    {
        address beaconAddress = versionToBeacon[version];
        CollectionProxy collectionProxy = new CollectionProxy(beaconAddress, initializationArgs);
        collection = address(collectionProxy);

        collections.push(collectionProxy);
        
        proxyToVersion[collection] = version;

        emit CollectionDeployed(version, beaconAddress, collection);

    }


    function updateCollection(address proxyAddress, uint256 version, bytes memory data) 
        external 
        onlyOwner 
        versionExists(version) 
    {
        uint256 oldVersion = proxyToVersion[proxyAddress];
        address oldBeacon = versionToBeacon[oldVersion];
        address oldImplementation = UpgradeableBeacon(oldBeacon).implementation();
        
        address newBeacon = versionToBeacon[version];
        address newImplementation = beaconToImplementation[address(newBeacon)];
         
        CollectionProxy(payable(proxyAddress)).changeBeacon(newBeacon, data);

        emit CollectionUpdated(oldVersion, oldImplementation, version, newImplementation, proxyAddress);

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
        address newBeacon = versionToBeacon[newVersion];
        address newImplementation = beaconToImplementation[newBeacon];
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
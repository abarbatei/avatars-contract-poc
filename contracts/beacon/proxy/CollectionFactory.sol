// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
// import { BeaconProxy } from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import { CollectionProxy } from "./CollectionProxy.sol";

contract CollectionFactoryV2 is Ownable2Step, Pausable {

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
     * @param proxyAddress the proxy address whose implementation has changed
     * @param newImplementation the implementation that will be associated with the proxy
     * @param newVersion the new implementation version to be asociated with the proxy
     */
    event CollectionUpdated(address proxyAddress, address newImplementation, uint256 newVersion);

    uint256[] public versions;

    mapping(uint256 => address) public versionToImplementation;

    mapping(address => uint256) public implementationToVersion;

    mapping(uint256 => address) public versionToLastestBeacon;

    mapping(uint256 => address[]) public versionToBeacons;

    mapping(address => uint256) public proxyToVersion;

    constructor() {

    }


    function addImplementation(address implementation, uint256 version) external onlyOwner {
        require(version != 0, "Version cannot be 0");
        require(versionToImplementation[version] == address(0), "Version already exists");
        require(implementationToVersion[implementation] == 0, "Implementation already exists");

        implementationToVersion[implementation] = version;
        versionToImplementation[version] = implementation;

        versions.push(version);

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
        address beacon;
        address existingVersionedBeacon = versionToLastestBeacon[version];
        if (existingVersionedBeacon != address(0)) {
            beacon = existingVersionedBeacon;
        } else {
            beacon = _deployBeacon(implementation, version);
        }

        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);
        
        proxyToVersion[collection] = version;

        emit CollectionDeployed(version, beacon, collection);
    }

    function _deployBeacon(address implementation, uint256 version) internal returns (address beacon) {
            beacon = address(new UpgradeableBeacon(implementation));
            versionToLastestBeacon[version] = beacon; 
            versionToBeacons[version].push(beacon);
    }

    function updateCollection(address proxyAddress, uint256 toVersion, bytes memory data) 
        external 
        onlyOwner 
        versionExists(toVersion) 
    {

        uint256 currentVersion = proxyToVersion[proxyAddress];
        require(currentVersion != toVersion, "proxy already at that version");
        
        address newImplementation = versionToImplementation[toVersion];
  
        address newBeacon = _deployBeacon(newImplementation, toVersion);

        // make the proxy point to this new beacon
        CollectionProxy(payable(proxyAddress)).changeBeacon(newBeacon, data); 

        proxyToVersion[proxyAddress] = toVersion;
        
        emit CollectionUpdated(proxyAddress, newImplementation, toVersion);
    }

    function updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        external 
        onlyOwner 
        versionExists(targetVersion) 
        versionExists(newVersion) 
    {
        require(versionToLastestBeacon[targetVersion] != address(0), "No collections with the that version");
        _updateCollectionsByVersion(targetVersion, newVersion);
    }

    function updateAllCollections(uint256 newVersion) 
        external 
        onlyOwner  
        versionExists(newVersion) 
    {
        uint256 collectionCount = versions.length; 
        for (uint256 index; index < collectionCount;) {
            uint256 version = versions[index];
            _updateCollectionsByVersion(version, newVersion);
            unchecked {
                ++index;
            }
        }
    }

    /**
     * @notice 
     * @dev asumptions: beacons with targetVersion exist; newVersion has an implementation mapped to id
     * @param targetVersion the old version for the default implementation; 0 means it was unset
     * @param newVersion the new version for the default implementation
     */
    function _updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        internal 
    {
        address newImplementation = versionToImplementation[newVersion];

        address[] storage beacons = versionToBeacons[targetVersion];

        for (uint256 index; index < beacons.length; index++) {
            address beacon = beacons[index];

            // upgrade beacon to point to new implementation
            UpgradeableBeacon(beacon).upgradeTo(newImplementation);

            // track this beacon in new implementation version mapping (at the end will remove them from the old version mapping)
            versionToBeacons[newVersion].push(beacon);
        }

        // all beacons were already
        delete versionToBeacons[targetVersion];
    }

    ////////////////////////////////////////////////// VIEW and HELPER functions //////////////////////////////////////////////////

    function implementationExists(address implementation) public view returns (bool) {
        return implementationToVersion[implementation] != 0;
    }
    
    function getImplementationVersion(address implementation) external view returns (uint256) {
        require(implementationExists(implementation), "Implementation does not exist");
        return implementationToVersion[implementation];
    }

    function getImplementation(uint256 version) external view versionExists(version) returns (address) {
        return versionToImplementation[version];
    }

    modifier versionExists(uint256 version) {
        require(versionToImplementation[version] != address(0), "Version does not exist");
        _;
    }
}
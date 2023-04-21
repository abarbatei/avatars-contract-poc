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

    uint256 public versionsCount;

    uint256[] public versions;

    mapping(uint256 => address) public versionToImplementation;

    mapping(address => uint256) public implementationToVersion;

    mapping(uint256 => address[]) public versionToBeacons;

    mapping(address => address) public proxyToBeacon;

    mapping(address => uint256) public proxyToVersion;

    mapping(address => address[]) public beaconToProxies;

    /////////////////////////////////////////////////////////

      
    
    // mapping(uint256 => address[]) public versionToProxies;


    // mapping(uint256 => address) public versionToBeacon;


    
    /// @dev how many proxies are refferencing this beacon


    address[] internal freeBeacons;

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
        address beacon;
        if (versionToBeacons[version].length != 0){
            beacon = versionToBeacons[version][0];
        } else {
            beacon = _deployBeacon(implementation, version);
        }

        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);
        
        proxyToBeacon[collection] = beacon;
        proxyToVersion[collection] = version;

        beaconToProxies[beacon].push(collection);

        emit CollectionDeployed(version, beacon, collection);

    }

    function _deployBeacon(address implementation, uint256 version) internal returns (address beacon) {
            beacon = address(new UpgradeableBeacon(implementation));
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
        address currentBeacon = proxyToBeacon[proxyAddress];
        address currentImplementation = versionToImplementation[currentVersion];
  
        if (beaconToProxies[currentBeacon].length == 1) {
            // if only 1 proxy is reffereing this beacon (meaning the current one), 
            // change the implementation of the beacon to the new one
            UpgradeableBeacon(currentBeacon).upgradeTo(newImplementation);
        } else {
            address newBeacon;
            // if there is a free becon, leftover from another switch, use it
            uint256 freeBeaconsCount = freeBeacons.length; 
            if (freeBeaconsCount != 0) { 
                newBeacon = freeBeacons[freeBeaconsCount - 1];
                freeBeacons.pop();
            } else {
                // else create a new beacon
                newBeacon = _deployBeacon(newImplementation, toVersion);
            }
            beaconToProxies[newBeacon].push(proxyAddress);
            // make the proxy point to this new beacon
            CollectionProxy(payable(proxyAddress)).changeBeacon(newBeacon, data); 
        }

        proxyToVersion[proxyAddress] = toVersion;
        
        emit CollectionUpdated(currentVersion, currentImplementation, toVersion, newImplementation, proxyAddress);
    }

    function updateCollectionsByVersion(uint256 targetVersion, uint256 newVersion) 
        external 
        onlyOwner 
        versionExists(targetVersion) 
        versionExists(newVersion) 
    {
        require(versionToBeacons[targetVersion].length != 0, "No collections with the that version");
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

        address[] memory beacons = versionToBeacons[targetVersion];

        address alreadyDeployedBeacon;
        address[] memory beaconsWithNewVersion = versionToBeacons[newVersion];
        if (beaconsWithNewVersion.length != 0) {
            alreadyDeployedBeacon = beaconsWithNewVersion[0];
        }
        
        for (uint256 index; index < beacons.length; index++) {
            address beacon = beacons[index];
            address[] memory previousBeaconsToProxy = beaconToProxies[beacon];
            if (previousBeaconsToProxy.length == 1 && alreadyDeployedBeacon != address(0)) {
                // if there is only 1 proxy tied to this beacon and there exists another beacon with the already existing implementation
                // then point to it and free this one
                // cornercase: if this is the first proxy to be changed, will change in place, even though after him others will follow
                address proxyAddress = previousBeaconsToProxy[0];
                delete beaconToProxies[beacon];

                bytes memory data;
                CollectionProxy(payable(proxyAddress)).changeBeacon(alreadyDeployedBeacon, data);
                freeBeacons.push(beacon);
                
            } else {
                // todo beacon to proxies here
                UpgradeableBeacon(beacon).upgradeTo(newImplementation);
            }
        }
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
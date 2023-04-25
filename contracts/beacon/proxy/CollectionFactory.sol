// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import { Address } from "openzeppelin/utils/Address.sol";
import { CollectionProxy } from "./CollectionProxy.sol";
import { IERC5131 } from "../interfaces/IERC5131.sol";

contract CollectionFactory is Ownable2Step, Pausable {

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a beacon was marked as followed by the factory
     * @dev emitted when deployBeacon or addBeacon is called
     * @param beacon the marked beacon address
     */
    event BeaconAdded(address beacon);

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployCollection is called
     * @param beaconAddress the used beacon address for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(address beaconAddress, address collectionProxy);

   /**
     * @notice Event emitted when a collection (proxy) was updated (had it's implementation change)
     * @dev emitted when updateCollection is called
     * @param proxyAddress the proxy address whose beacon has changed
     * @param beacon the new beacon address that is used
     */
    event CollectionUpdated(address proxyAddress, address beacon);

    /*//////////////////////////////////////////////////////////////
                           Global state variables
    //////////////////////////////////////////////////////////////*/

    address[] public collections;
    address[] public beacons;

    mapping(address => bool) public beaconState;
    mapping(address => address) public collectionToBeacon;

    /*//////////////////////////////////////////////////////////////
                           Constructor / Initializers
    //////////////////////////////////////////////////////////////*/

    constructor() {

    }

    /*//////////////////////////////////////////////////////////////
                    External and public functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev {UpgradeableBeacon} checks that implementation is actually a contract
     */
    function deployBeacon(address implementation) 
        external 
        onlyOwner 
        returns (address beacon) 
    {
            beacon = address(new UpgradeableBeacon(implementation));
            _saveBeacon(beacon);
    }

    function addBeacon(address beacon) external onlyOwner {
        require(Address.isContract(beacon), "CollectionFactory: beacon is not a contract");
        _saveBeacon(beacon);    }

    function deployCollection(address beacon, bytes calldata initializationArgs) 
        public 
        onlyOwner
        beaconIsAvailable(beacon)        
        returns (address collection)  
    {   
        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);

        collections.push(collection);
        collectionToBeacon[collection] = beacon;

        emit CollectionDeployed(beacon, collection);
    }

    /**
     * @param collection the collection for which the beacon to be changed
     * @param beacon the beacon contract address to be used by the collection
     * @param updateArgs if not zero, will be passed as a delegate call to the collection after beacon update
     */
    function updateCollection(address collection, address beacon, bytes memory updateArgs) 
        external 
        onlyCollectionOwner
        collectionExists(collection)
        beaconIsAvailable(beacon)
    {
        CollectionProxy(payable(collection)).changeBeacon(beacon, updateArgs); 
        collectionToBeacon[collection] = beacon;
        
        emit CollectionUpdated(collection, beacon);
    }

    /**
     * @dev {UpgradeableBeacon} checks that implementation is actually a contract
     */
    function updateBeaconImplementation(address beacon, address implementation) 
        external 
        onlyOwner 
        beaconIsAvailable(beacon)
    {
        UpgradeableBeacon(beacon).upgradeTo(implementation);
    }

    /** 
     * @notice helper function that retrieves all implementations tracked by the factory
     * @return list of implementation addresses used by the proxy
     */
    function getImplementations() external view returns (address[] memory) {
        uint256 beaconCount = beacons.length;
        address [] memory implementations = new address[](beaconCount);
        for (uint256 index = 0; index < beaconCount; index++) {
            UpgradeableBeacon beacon = UpgradeableBeacon(beacons[index]);
            implementations[index] = beacon.implementation();
        }
        return implementations;
    }

    /** 
     * @notice helper function that retrieves all implementations tracked by the factory
     * @return list of implementation addresses used by the proxy
     */
    function beaconOf(address collection) external view collectionExists(collection) returns (address) {
        return CollectionProxy(payable(collection)).beacon();
    }

    /*//////////////////////////////////////////////////////////////
                Internal, private and modifier functions
    //////////////////////////////////////////////////////////////*/

    /** 
     * @notice saves the beacon address into internal tracking
     * @dev beacon address sanity checks must be done before calling this function
     * @custom:event BeaconAdded
     * @param beacon the beacon address to me marked
     */
    function _saveBeacon(address beacon) internal {
        beacons.push(beacon);
        beaconState[beacon] = true;
        emit BeaconAdded(beacon);
    }

    /** 
     * @notice Modifier used to check if a beacon is actually tracked by factory
     * @param beacon the beacon address to check
     */
    modifier beaconIsAvailable(address beacon) {
        require(beaconState[beacon], "CollectionFactory: beacon is not tracked");
        _;
    }

    /** 
     * @notice Modifier used to check if a collection is actually tracked by factory
     * @param collection the collection address to check
     */
    modifier collectionExists(address collection) {
        require(collectionToBeacon[collection] != address(0x0), "CollectionFactory: collection is not tracked");
        _;
    }

    /** 
     * @notice Modifier used to check if a collection is actually tracked by factory
     * @param collection the collection address to check
     */
    modifier onlyCollectionOwner(address collection) {
        require(IERC5131(collection).owner() == msg.sender, "CollectionFactory: caller must be collection owner");
        _;
    }
}
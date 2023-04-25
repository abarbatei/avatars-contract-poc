// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import { Address } from "openzeppelin/utils/Address.sol";
import { CollectionProxy } from "./CollectionProxy.sol";


contract CollectionFactory is Ownable2Step, Pausable {

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployDefaultCollection or deployCollection is called
     * @param beaconAddress the used beacon address for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(address beaconAddress, address collectionProxy);

   /**
     * @notice Event emitted when a collection (proxy) was updated (had it's implementation change)
     * @dev emitted when updateCollection is called
     * @param proxyAddress the proxy address whose beacon has changed
     * @param beacon the new beacon that was used
     */
    event CollectionUpdated(address proxyAddress, address beacon);

    /*//////////////////////////////////////////////////////////////
                           Global state variables
    //////////////////////////////////////////////////////////////*/

    address[] public collections;
    address[] public beacons;

    mapping(address => bool) public beaconState;
    mapping(address => bool) public collectionState;

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
            beacons.push(beacon);
            beaconState[beacon] = true;
    }

    function addBeacon(address beacon) external onlyOwner {
        require(Address.isContract(beacon), "CollectionFactory: beacon is not a contract");
        beacons.push(beacon);
        beaconState[beacon] = true;
    }

    function deployCollection(address beacon, bytes calldata initializationArgs) 
        public 
        onlyOwner
        beaconIsAvailable(beacon)        
        returns (address collection)  
    {   
        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);
        collections.push(collection);
        collectionState[collection] = true;

        emit CollectionDeployed(beacon, collection);
    }

    /**
     * @param collection the collection for which the beacon to be changed
     * @param beacon the beacon contract address to be used by the collection
     * @param updateArgs if not zero, will be passed as a delegate call to the collection after beacon update
     */
    function updateCollection(address collection, address beacon, bytes memory updateArgs) 
        external 
        onlyOwner
        collectionExists(collection)
        beaconIsAvailable(beacon)
    {
        CollectionProxy(payable(collection)).changeBeacon(beacon, updateArgs); 
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

    /*//////////////////////////////////////////////////////////////
                           View functions
    //////////////////////////////////////////////////////////////*/

    function getImplementations() external view returns (address[] memory) {
        uint256 beaconCount = beacons.length;
        address [] memory implementations = new address[](beaconCount);
        for (uint256 index = 0; index < beaconCount; index++) {
            UpgradeableBeacon beacon = UpgradeableBeacon(beacons[index]);
            implementations[index] = beacon.implementation();
        }
        return implementations;
    }

    modifier beaconIsAvailable(address beacon) {
        require(beaconState[beacon], "CollectionFactory: beacon is not tracked");
        _;
    }

    modifier collectionExists(address collection) {
        require(collectionState[collection], "CollectionFactory: collection is not tracked");
        _;
    }
}
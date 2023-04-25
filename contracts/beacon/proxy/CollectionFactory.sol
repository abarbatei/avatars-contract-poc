// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { Pausable } from "openzeppelin/security/Pausable.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
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
    function deployBeacon(address implementation) external onlyOwner returns (address beacon) {
            beacon = address(new UpgradeableBeacon(implementation));
            beacons.push(beacon);
    }

    function addBeacon(address beacon) external onlyOwner {
        beacons.push(beacon);
    }

    function deployCollection(address beacon, bytes calldata initializationArgs) 
        public 
        onlyOwner 
        returns (address collection)  
    {   
        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);
        collections.push(collection);

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
    {
        CollectionProxy(payable(collection)).changeBeacon(beacon, updateArgs); 
        emit CollectionUpdated(collection, beacon);
    }

    function updateBeaconImplementation(address beacon, address implementation) 
        external 
        onlyOwner 
    {
        UpgradeableBeacon(beacon).upgradeTo(implementation);
    }

    /*//////////////////////////////////////////////////////////////
                           View functions
    //////////////////////////////////////////////////////////////*/

    function getImplementations() external view returns (address[] memory) {
        uint256 beaconCount = beacons.length;
        address [] memory implementations = new address[](beaconCount);
        for (uint256 index; index < beacons.length; index++) {
            UpgradeableBeacon beacon = UpgradeableBeacon(beacons[index]);
            implementations[index] = beacon.implementation();
        }
        return implementations;
    }

}
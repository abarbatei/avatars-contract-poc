// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
// import { EnumerableMap } from "openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "openzeppelin/utils/structs/EnumerableSet.sol";

import { Address } from "openzeppelin/utils/Address.sol";
import { CollectionProxy } from "./CollectionProxy.sol";
import { IERC5313 } from "../interfaces/IERC5313.sol";
import { EnumerableMap } from "./EnumerableMap.sol";

contract CollectionFactory is Ownable2Step {

    // using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                           Global state variables
    //////////////////////////////////////////////////////////////*/        

    //EnumerableMap.UintToAddressMap internal aliasToBeacon;
    EnumerableMap.AddressToUintMap internal beaconToAlias;

    /// @notice set of deployed collection addresses (Proxies)
    EnumerableSet.AddressSet internal collections;

    uint256 public collectionsCount;

    // -------------------

    // /// @notice list of tracked beacon adresses
    // address[] public beacons;

    // /// @notice helper mapping used to verify that a beacon is actually tracked by the project
    // mapping(address => bool) public beaconState;

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a beacon was marked as followed by the factory
     * @dev emitted when deployBeacon or addBeacon is called
     * @param beacon the marked beacon address
     */
    event BeaconAdded(address indexed beacon);

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployCollection is called
     * @param beaconAddress the used beacon address for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(address indexed beaconAddress, address indexed collectionProxy);

   /**
     * @notice Event emitted when a collection (proxy) was updated (had it's implementation change)
     * @dev emitted when updateCollection is called
     * @param proxyAddress the proxy address whose beacon has changed
     * @param beacon the new beacon address that is used
     */
    event CollectionUpdated(address indexed proxyAddress, address indexed beacon);

    /*//////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

    /** 
     * @notice Modifier used to check if a beacon is actually tracked by factory
     * @param beacon the beacon address to check
     */
    modifier beaconIsAvailable(address beacon) {
        require(beaconToAlias.contains(beacon), "CollectionFactory: beacon is not tracked");
        _;
    }

    /** 
     * @notice Modifier used to check if a collection is actually tracked by factory
     * @param collection the collection address to check
     */
    modifier collectionExists(address collection) {
        require(collections.contains(collection), "CollectionFactory: collection is not tracked");
        _;
    }

    /** 
     * @notice Modifier used to check if caller is the owner of the specific collection or the owner of the factory
     * @param collection the targeted collection address
     */
    modifier onlyOwners(address collection) {
        require(IERC5313(collection).owner() == msg.sender || owner() == msg.sender, "CollectionFactory: caller is not collection or factory owner");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                    External and public functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice deploys a beacon with the provided implementation address and tracks it
     * @dev {UpgradeableBeacon} checks that implementation is actually a contract
     * @custom:event BeaconAdded
     * @param implementation the beacon address to be added/tracked
     * @return beacon the newly added beacon address that was launched
     */
    function deployBeacon(address implementation, uint256 alias_) 
        external 
        onlyOwner
        returns (address beacon) 
    {
        beacon = address(new UpgradeableBeacon(implementation));
        _saveBeacon(beacon, alias_);
    }

    /**
     * @notice adds, an already deployed beacon, to be tracked/used by the factory
     *         beacon ownershi must be transfered to this contract beforehand
     * @dev checks that implementation is actually a contract and not already added
     * @custom:event BeaconAdded
     * @param beacon the beacon address to be added/tracked
     */
    function addBeacon(address beacon, uint256 alias_) 
        external 
        onlyOwner 
    {
        require(!beaconToAlias.contains(beacon), "CollectionFactory: beacon already added");
        require(Address.isContract(beacon), "CollectionFactory: beacon is not a contract");
        require(UpgradeableBeacon(beacon).owner() == address(this), "CollectionFactory: ownership must be given to factory");
        _saveBeacon(beacon, alias_);
    }

    /**
     * @notice deploys a collection, making it point to the indicated beacon address 
               and calls any initialization function if initializationArgs is provided
     * @dev checks that implementation is actually a contract and not already added
     * @custom:event CollectionDeployed
     * @param beacon the beacon address from which the collection will get its implementation
     * @param initializationArgs (encodeWithSignature) initialization function with arguments 
     *                           to be called on newly deployed collection. If not provieded,
     *                           will not call any function
     * @return collection the newly created collection address
     */
    function deployCollection(address beacon, bytes calldata initializationArgs) 
        public 
        onlyOwner
        beaconIsAvailable(beacon)        
        returns (address collection)  
    {   
        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);

        collections.add(collection);
        collectionsCount += 1;

        emit CollectionDeployed(beacon, collection);
    }

    /**
     * @notice change what beacon the collection is pointing to. If updateArgs are provided, 
     *         will also call the specified function
     * @custom:event CollectionDeployed
     * @param collection the collection for which the beacon to be changed
     * @param beacon the beacon contract address to be used by the collection
     * @param updateArgs (encodeWithSignature) update function with arguments to be called on 
     *                   the newly update collection. If not provieded, will not call any function
     */
    function updateCollection(address collection, address beacon, bytes memory updateArgs) 
        external
        beaconIsAvailable(beacon)
        collectionExists(collection)
        onlyOwners(collection)
    {
        CollectionProxy(payable(collection)).changeBeacon(beacon, updateArgs);
        
        emit CollectionUpdated(collection, beacon);
    }

    /**
     * @notice Changes the implementation pointed by the indicated beacon
     * @dev {UpgradeableBeacon.upgradeTo} checks that implementation is actually a contract
     * @custom:event {UpgradeableBeacon.Upgraded}
     * @param beacon the beacon for which to change the implementation
     * @param implementation the new implementation for the indicated beacon
     */
    function updateBeaconImplementation(address beacon, address implementation) 
        external 
        onlyOwner 
        beaconIsAvailable(beacon)
    {
        UpgradeableBeacon(beacon).upgradeTo(implementation);        
    }

    /** 
     * @notice Helper function that retrieves all beacons tracked by the factory
     * @return list of beacons used by the proxy
     */
    function getBeacons() 
        external 
        view 
        returns (address[] memory)
    {
        return beaconToAlias.keys();        
    }

    /** 
     * @notice Helper function that retrieves all collections tracked by the factory
     * @return list of collections managed by the proxy
     */
    function getCollections() 
        external 
        view 
        returns (address[] memory)
    {
        return collections.values();
    }

    /** 
     * @notice Helper function that retrieves the collection at a specific index
     * @return collection address from specific index
     */
    function getCollection(uint256 index) 
        external 
        view 
        returns (address)
    {
        return collections.at(index);
    }


    /** 
     * @notice Helper function that retrieves the beacon pointed to by the collection proxy
     * @param collection the collection for which to get the pointed beacon
     * @return the beacon address pointed by the collection
     */
    function beaconOf(address collection) 
        external 
        view 
        collectionExists(collection) 
        returns (address)
    {
        return CollectionProxy(payable(collection)).beacon();
    }

    /**
     * @notice function renounces ownership of contract. Currently it is disable,
     *         as to not risk losing the ability to manage/deploy collections
     * @dev reverts on call
     */
    function renounceOwnership() public virtual override onlyOwner {
        revert("CollectionFactory: Renounce ownership is not available");
    }

    /*//////////////////////////////////////////////////////////////
                    Internal and private functions
    //////////////////////////////////////////////////////////////*/

    /** 
     * @notice Saves the beacon address into internal tracking
     * @dev beacon address sanity checks must be done before calling this function
     * @custom:event BeaconAdded
     * @param beacon the beacon address to me marked
     */
    function _saveBeacon(address beacon, uint256 alias_) internal {
        beaconToAlias.set(beacon, alias_);
        emit BeaconAdded(beacon);
    }
}
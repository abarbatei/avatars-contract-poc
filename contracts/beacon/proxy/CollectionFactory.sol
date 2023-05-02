// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Ownable2Step } from "openzeppelin/access/Ownable2Step.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import { EnumerableSet } from "openzeppelin/utils/structs/EnumerableSet.sol";

import { Address } from "openzeppelin/utils/Address.sol";
import { CollectionProxy } from "./CollectionProxy.sol";
import { IERC5313 } from "../interfaces/IERC5313.sol";
import { EnumerableMap } from "./EnumerableMap.sol";

contract CollectionFactory is Ownable2Step {

    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                           Global state variables
    //////////////////////////////////////////////////////////////*/        

    /// @notice list of tracked beacon adresses    
    string[] public aliases;
    
    /// @notice mapping alias to beacon address
    mapping(string => address) public aliasToBeacon;

    /// @notice beacon/alias count; used as a helper for off-chain operations mostly
    uint256 public beaconCount;

    /// @notice set of deployed collection addresses (Proxies)
    EnumerableSet.AddressSet internal collections;

    /// @notice collection count; used as a helper for off-chain operations mostly
    uint256 public collectionCount;

    /*//////////////////////////////////////////////////////////////
                                Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Event emitted when a beacon was marked as followed by the factory
     * @dev emitted when deployBeacon or addBeacon is called
     * @param beaconAlias the alias (string) used for this beacon
     * @param beaconAddress the marked beacon address
     */
    event BeaconAdded(string indexed beaconAlias, address indexed beaconAddress);

    /**
     * @notice Event emitted when a collection (proxy) was deployed
     * @dev emitted when deployCollection is called
     * @param beaconAlias the alias for the used beacon
     * @param beaconAddress the used beacon address for the collection
     * @param collectionProxy the new collection proxy address
     */
    event CollectionDeployed(string indexed beaconAlias, address indexed beaconAddress, address indexed collectionProxy);

   /**
     * @notice Event emitted when a collection (proxy) was updated (had it's implementation change)
     * @dev emitted when updateCollection is called
     * @param proxyAddress the proxy address whose beacon has changed
     * @param beaconAlias the alias for the used beacon
     * @param beaconAddress the new beacon address that is used
     */
    event CollectionUpdated(address indexed proxyAddress, string indexed beaconAlias, address indexed beaconAddress);

    /*//////////////////////////////////////////////////////////////
                                Modifiers
    //////////////////////////////////////////////////////////////*/

    /** 
     * @notice Modifier used to check if a beacon is actually tracked by factory
     * @param beaconAlias the beacon address to check
     */
    modifier beaconIsAvailable(string memory beaconAlias) {
        require(aliasToBeacon[beaconAlias] != address(0x0), "CollectionFactory: beacon is not tracked");
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
     * @param beaconAlias the beacon alias to be attributed to the newly deployed beacon
     * @return beacon the newly added beacon address that was launched
     */
    function deployBeacon(address implementation, string memory beaconAlias) 
        external 
        onlyOwner
        returns (address beacon)
    {
        require(bytes(beaconAlias).length != 0, "CollectionFactory: beacon alias cannot be empty");
        require(aliasToBeacon[beaconAlias] == address(0x0), "CollectionFactory: beacon already added");        
        beacon = address(new UpgradeableBeacon(implementation));
        _saveBeacon(beacon, beaconAlias);
    }

    /**
     * @notice adds, an already deployed beacon, to be tracked/used by the factory;
     *         Beacon ownership must be transfered to this contract beforehand
     * @dev checks that implementation is actually a contract and not already added
     *      will revert if beacon owner was not transfered to the factory
     * @custom:event BeaconAdded
     * @param beacon the beacon address to be added/tracked
     * @param beaconAlias the beacon address to be added/tracked
     */
    function addBeacon(address beacon, string memory beaconAlias) 
        external 
        onlyOwner 
    {
        require(bytes(beaconAlias).length != 0, "CollectionFactory: beacon alias cannot be empty");
        require(aliasToBeacon[beaconAlias] == address(0x0), "CollectionFactory: beacon already added");
        require(Address.isContract(beacon), "CollectionFactory: beacon is not a contract");
        require(UpgradeableBeacon(beacon).owner() == address(this), "CollectionFactory: ownership must be given to factory");
        _saveBeacon(beacon, beaconAlias);
    }

    /**
     * @notice deploys a collection, making it point to the indicated beacon address 
               and calls any initialization function if initializationArgs is provided
     * @dev checks that implementation is actually a contract and not already added
     * @custom:event CollectionDeployed
     * @param beaconAlias alias for the beacon from which the collection will get its implementation
     * @param initializationArgs (encodeWithSignature) initialization function with arguments 
     *                           to be called on newly deployed collection. If not provieded,
     *                           will not call any function
     * @return collection the newly created collection address
     */
    function deployCollection(string memory beaconAlias, bytes calldata initializationArgs) 
        public 
        onlyOwner
        beaconIsAvailable(beaconAlias)
        returns (address collection)  
    {   
        address beacon = aliasToBeacon[beaconAlias];
        CollectionProxy collectionProxy = new CollectionProxy(beacon, initializationArgs);
        collection = address(collectionProxy);

        collections.add(collection);
        collectionCount += 1;

        emit CollectionDeployed(beaconAlias, beacon, collection);        
        
    }

    /**
     * @notice change what beacon the collection is pointing to. If updateArgs are provided, 
     *         will also call the specified function
     * @custom:event CollectionDeployed
     * @param collection the collection for which the beacon to be changed
     * @param beaconAlias alias for the beacon to be used by the collection
     * @param updateArgs (encodeWithSignature) update function with arguments to be called on 
     *                   the newly update collection. If not provieded, will not call any function
     */
    function updateCollection(address collection, string memory beaconAlias, bytes memory updateArgs) 
        external
        beaconIsAvailable(beaconAlias)
        collectionExists(collection)
        onlyOwners(collection)
    {
        address beacon = aliasToBeacon[beaconAlias];
        CollectionProxy(payable(collection)).changeBeacon(beacon, updateArgs);
        
        emit CollectionUpdated(collection, beaconAlias, beacon);
    }

    /**
     * @notice Changes the implementation pointed by the indicated beacon
     * @dev {UpgradeableBeacon.upgradeTo} checks that implementation is actually a contract
     * @custom:event {UpgradeableBeacon.Upgraded}
     * @param beaconAlias alias for the beacon for which to change the implementation
     * @param implementation the new implementation for the indicated beacon
     */
    function updateBeaconImplementation(string memory beaconAlias, address implementation) 
        external 
        onlyOwner 
        beaconIsAvailable(beaconAlias)
    {
        UpgradeableBeacon(aliasToBeacon[beaconAlias]).upgradeTo(implementation);        
    }

    /** 
     * @notice Helper function that retrieves all beacons tracked by the factory
     * @return list of beacons managed by the factory
     */
    function getBeacons()
        external 
        view 
        returns (address[] memory)
    {
        uint256 beaconCount_ = beaconCount;
        address [] memory beacons_ = new address[](beaconCount_);
        for (uint256 index = 0; index < beaconCount_; index++) {
            string memory beaconAlias = aliases[index];
            beacons_[index] = aliasToBeacon[beaconAlias];
        }
        return beacons_;
    }

    /** 
     * @notice Helper function that retrieves all aliases tracked by the factory
     * @return list of aliases managed by the factory
     */
    function getBeaconAliases()
        external 
        view 
        returns (string[] memory)
    {
        uint256 beaconCount_ = beaconCount;
        string [] memory aliases_ = new string[](beaconCount_);
        for (uint256 index = 0; index < beaconCount_; index++) {
            string memory beaconAlias = aliases[index];
            aliases_[index] = beaconAlias;
        }
        return aliases_;
    }

    /** 
     * @notice Helper function that retrieves all collections tracked by the factory
     * @return list of collections managed by the factory
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
     * @param beaconAlias the beacon alias to be associated with this address
     */
    function _saveBeacon(address beacon, string memory beaconAlias) internal {        
        aliases.push(beaconAlias);
        aliasToBeacon[beaconAlias] = beacon;
        beaconCount += 1;

        emit BeaconAdded(beaconAlias, beacon);
    }
}
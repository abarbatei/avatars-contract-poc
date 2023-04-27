// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { MockImplementation } from "./utils/mocks/MockImplementation.sol";
import { MockUpgradable } from "./utils/mocks/MockUpgradable.sol";
import { MockUpgradableV2 } from "./utils/mocks/MockUpgradableV2.sol";
import { CollectionFactory } from "../../contracts/beacon/proxy/CollectionFactory.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract CollectionFactoryTest is Test {

    // helper struct used for easy compare of value passing via proxy deploy to initialize
    struct TestDataForInitialize {
        address _owner;
        string _name;
        address payable _someAddress;
        address _addressTwo;
        bool _someBool;
        uint256 _maxSupply;
    }

    CollectionFactory collectionFactory;
    address collectionFactoryOwner;
    address avatarCollectionImplementation;
    address implementation;
    address implementation2;
    address alice;
    address bob;
    
    function setUp() public {
        collectionFactoryOwner = makeAddr("collectionFactoryOwner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    
        vm.prank(collectionFactoryOwner);
        collectionFactory = new CollectionFactory();

        implementation = address(new MockUpgradable());
        implementation2 = address(new MockUpgradableV2());
    }

    /*
        testing deployBeacon
            - can only be called by owner
            - successful deploy
            - input validation works
            - respects onther invariants            
    */

    function test_deployBeacon_revertsIfNotOwner() public {
        
        vm.expectRevert();
        vm.prank(alice);
        collectionFactory.deployBeacon(implementation);
    }

    function test_deployBeacon_successful() public {
        
        vm.expectRevert();
        collectionFactory.beacons(0);

        vm.prank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);

        address savedImplementation = UpgradeableBeacon(deployedBeacon).implementation();
        assertEq(savedImplementation, implementation);

        address savedBeacon = collectionFactory.beacons(0);
        assertEq(deployedBeacon, savedBeacon);

        address[] memory beacons = collectionFactory.getBeacons();
        assertEq(beacons.length, 1);
    }

    function test_deployBeacon_inputValidationWorks() public {
        
        vm.expectRevert("UpgradeableBeacon: implementation is not a contract");
        vm.prank(collectionFactoryOwner);
        collectionFactory.deployBeacon(bob);

        vm.expectRevert("UpgradeableBeacon: implementation is not a contract");
        vm.prank(collectionFactoryOwner);
        collectionFactory.deployBeacon(address(0x0));

    }

    function test_deployBeacon_respectsOtherInvariants() public {

        vm.expectRevert();
        collectionFactory.collections(0);

        vm.prank(collectionFactoryOwner);
        collectionFactory.deployBeacon(implementation);    
        
        vm.expectRevert();
        collectionFactory.collections(0);
    }

    /*
        testing addBeacon
            - can only be called by owner
            - successful deploy
            - input validation works
            - respects onther invariants            
    */

    function test_addBeacon_revertsIfNotOwner() public {
        
        vm.expectRevert();
        vm.prank(alice);
        collectionFactory.addBeacon(implementation);
    }

    function test_addBeacon_successful() public {
        
        vm.expectRevert();
        collectionFactory.collections(0);

        vm.startPrank(collectionFactoryOwner);
        address createdBeacon = address(new UpgradeableBeacon(implementation));

        UpgradeableBeacon(createdBeacon).transferOwnership(address(collectionFactory));

        collectionFactory.addBeacon(createdBeacon);
        vm.stopPrank();        

        address savedBeacon = collectionFactory.beacons(0);
        assertEq(createdBeacon, savedBeacon);

        address[] memory beacons = collectionFactory.getBeacons();
        assertEq(beacons.length, 1);
    }

    function test_addBeacon_inputValidationWorks() public {

        vm.startPrank(collectionFactoryOwner);
        address createdBeacon = address(new UpgradeableBeacon(implementation));
        
        vm.expectRevert("CollectionFactory: beacon is not a contract");
        collectionFactory.addBeacon(bob);

        vm.expectRevert("CollectionFactory: ownership must be given to factory");
        collectionFactory.addBeacon(createdBeacon);

        UpgradeableBeacon(createdBeacon).transferOwnership(address(collectionFactory));
        collectionFactory.addBeacon(createdBeacon);

        vm.expectRevert("CollectionFactory: beacon already added");
        collectionFactory.addBeacon(createdBeacon);
        vm.stopPrank();
    }

    function test_addBeacon_respectsOtherInvariants() public {

        vm.expectRevert();
        collectionFactory.collections(0);

        vm.startPrank(collectionFactoryOwner);
        address createdBeacon = address(new UpgradeableBeacon(implementation));
        UpgradeableBeacon(createdBeacon).transferOwnership(address(collectionFactory));
        collectionFactory.addBeacon(createdBeacon);
        vm.stopPrank();
                
        vm.expectRevert();
        collectionFactory.collections(0);
    }

    /*
        testing deployCollection
            - can only be called by owner
            - successful deploy
            - input validation works
            - respects onther invariants            
    */

    function test_deployCollection_revertsIfNotFactoryOwner() public {
        
        vm.prank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();

        vm.expectRevert();
        vm.prank(alice);
        collectionFactory.deployCollection(deployedBeacon, args);
    }

    function test_deployCollection_successful() public {
        
        vm.expectRevert();
        collectionFactory.collections(0);

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();
        address returnedCollection = collectionFactory.deployCollection(deployedBeacon, args);
        vm.stopPrank();
        
        address newlyAddedCollection = collectionFactory.collections(0);

        assertEq(returnedCollection, newlyAddedCollection);
        
        address mappedBeaconToCollection = collectionFactory.beaconOf(newlyAddedCollection);
        assertEq(mappedBeaconToCollection, deployedBeacon);
        
        address[] memory collections = collectionFactory.getCollections();
        assertEq(collections.length, 1);
    }

    function test_deployCollection_inputValidationWorks() public {

        vm.startPrank(collectionFactoryOwner);
        collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();

        vm.expectRevert("CollectionFactory: beacon is not tracked");
        collectionFactory.deployCollection(alice, args);

        vm.expectRevert("CollectionFactory: beacon is not tracked");
        collectionFactory.deployCollection(address(0x0), args);

        vm.stopPrank();
    }

    function test_deployCollection_respectsOtherInvariants() public {

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        
        address[] memory beforeBeacons = collectionFactory.getBeacons();
        assertEq(beforeBeacons.length, 1);        

        bytes memory args = _defaultArgsData();
        collectionFactory.deployCollection(deployedBeacon, args);
        vm.stopPrank();

        address[] memory afterBeacons = collectionFactory.getBeacons();

        assertEq(beforeBeacons.length, afterBeacons.length);
        assertEq(beforeBeacons[0], afterBeacons[0]);
    }

    /*
        testing updateCollection
            - can not be called by random address            
            - successful update from factory owner (no init args)
            - successful update from collection owner (no init args)
            - input validation works
            - respects onther invariants            
    */

    function test_updateCollection_revertsIfNotFactoryOwnerOrCollectionOwner() public {
        bytes memory updateArgs;

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();
        address returnedCollection = collectionFactory.deployCollection(deployedBeacon, args);
        
        address secondBeacon = collectionFactory.deployBeacon(implementation2);
        vm.stopPrank();

        vm.expectRevert();
        collectionFactory.updateCollection(returnedCollection, secondBeacon, updateArgs);
    }

    function _updateCollection_succesful_noUpdateArgs(address user) public {
        bytes memory updateArgs;

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();
        address returnedCollection = collectionFactory.deployCollection(deployedBeacon, args);
        
        address secondBeacon = collectionFactory.deployBeacon(implementation2);
        vm.stopPrank();

        vm.startPrank(user);
        collectionFactory.updateCollection(returnedCollection, secondBeacon, updateArgs);
        vm.stopPrank();
    }

    function test_updateCollection_succesful_factoryOwner_noUpdateArgs() public {
        _updateCollection_succesful_noUpdateArgs(collectionFactoryOwner);
    }

    function test_updateCollection_succesful_collectionOwner_noUpdateArgs() public {
        _updateCollection_succesful_noUpdateArgs(alice);
    }

    function test_updateCollection_inputValidationWorks() public {

        bytes memory updateArgs;

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);
        bytes memory args = _defaultArgsData();
        address returnedCollection = collectionFactory.deployCollection(deployedBeacon, args);
        address secondBeacon = collectionFactory.deployBeacon(implementation2);

        vm.expectRevert("CollectionFactory: beacon is not tracked");
        collectionFactory.updateCollection(returnedCollection, bob, updateArgs);

        vm.expectRevert("CollectionFactory: collection is not tracked");
        collectionFactory.updateCollection(address(0x0), secondBeacon, updateArgs);

        vm.stopPrank();
    }

    function test_updateCollection_respectsOtherInvariants() public {

        bytes memory updateArgs;

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);

        bytes memory args = _defaultArgsData();
        address returnedCollection = collectionFactory.deployCollection(deployedBeacon, args);

        address[] memory beforeCollections = collectionFactory.getCollections();
        assertEq(beforeCollections.length, 1);        

        address secondBeacon = collectionFactory.deployBeacon(implementation2);

        address[] memory beforeBeacons = collectionFactory.getBeacons();
        assertEq(beforeBeacons.length, 2);

        collectionFactory.updateCollection(returnedCollection, secondBeacon, updateArgs);
        vm.stopPrank();

        address[] memory afterCollections = collectionFactory.getCollections();
        assertEq(beforeCollections.length, afterCollections.length);
        assertEq(beforeCollections[0], afterCollections[0]);

        address[] memory afterBeacons = collectionFactory.getBeacons();

        assertEq(beforeBeacons.length, afterBeacons.length);
        assertEq(beforeBeacons[0], afterBeacons[0]);
        assertEq(beforeBeacons[1], afterBeacons[1]);
    }

    /*
        testing updateBeaconImplementation
            - can not be called by random address            
            - successful update
            - input validation works
            - respects onther invariants            
        TODO
    */

    function test_updateBeaconImplementation_revertsIfNotFactoryOwner() public {
        
        vm.prank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);

        vm.expectRevert();
        vm.prank(alice);
        collectionFactory.updateBeaconImplementation(deployedBeacon, implementation2);
    }

    function test_updateBeaconImplementation_succesful() public {
        
        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);

        collectionFactory.updateBeaconImplementation(deployedBeacon, implementation2);

        address secondImplementation = UpgradeableBeacon(deployedBeacon).implementation();

        assertEq(implementation2, secondImplementation, "updated beacon implementation should be the passed one");
        vm.stopPrank();
    }

    function test_updateBeaconImplementation_inputValidationWorks() public {

        vm.startPrank(collectionFactoryOwner);

        vm.expectRevert("CollectionFactory: beacon is not tracked");
        collectionFactory.updateBeaconImplementation(alice, implementation2);

        vm.stopPrank();

    }

    function test_updateBeaconImplementation_respectsOtherInvariants() public {

        bytes memory updateArgs;

        vm.startPrank(collectionFactoryOwner);
        address deployedBeacon = collectionFactory.deployBeacon(implementation);

        address[] memory beforeCollections = collectionFactory.getCollections();
        assertEq(beforeCollections.length, 0);

        address[] memory beforeBeacons = collectionFactory.getBeacons();
        assertEq(beforeBeacons.length, 1);

        collectionFactory.updateBeaconImplementation(deployedBeacon, implementation2);

        address[] memory afterCollections = collectionFactory.getCollections();
        assertEq(beforeCollections.length, afterCollections.length);

        address[] memory afterBeacons = collectionFactory.getBeacons();
        assertEq(beforeBeacons.length, afterBeacons.length);
        assertEq(beforeBeacons[0], afterBeacons[0]);
    }

    /*//////////////////////////////////////////////////////////////
                            Helper functions
    //////////////////////////////////////////////////////////////*/

    function _defaultArgsData() public returns (bytes memory initializationArguments) {
        TestDataForInitialize memory t;
        t._owner = alice;
        t._name = "TestContract";
        t._someAddress = payable(makeAddr("someAddress"));
        t._addressTwo = makeAddr("addressTwo");
        t._someBool = true;
        t._maxSupply = 555;
        initializationArguments = _encodeInitializationARguments(t);
    }
    //////////////////////////// HELPER FUNCTIONS ////////////////////////////
    function _encodeInitializationARguments(TestDataForInitialize memory t) internal pure returns (bytes memory initializationArguments) {
        /*
        function initialize(
            address _owner,
            string memory _name,
            address payable _someAddress,
            address _addressTwo,
            bool _someBool,
            uint256 _maxSupply)
         */
        initializationArguments = abi.encodeWithSignature(
            "initialize(address,string,address,address,bool,uint256)",
            t._owner, t._name, t._someAddress, t._addressTwo, t._someBool, t._maxSupply);
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR_ROLE");
    bytes32 public constant TRANSFORMER_ROLE = keccak256("TRANSFORMER_ROLE");

    function test_odd() public {
        console.log("ADMIN_ROLE");
        console.logBytes32(ADMIN_ROLE);
        console.log("CONFIGURATOR_ROLE");
        console.logBytes32(CONFIGURATOR_ROLE);
        console.log("TRANSFORMER_ROLE");
        console.logBytes32(TRANSFORMER_ROLE);
    }
}

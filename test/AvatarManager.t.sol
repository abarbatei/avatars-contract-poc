// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { MockImplementation } from "./utils/mocks/MockImplementation.sol";
import { MockUpgradable } from "./utils/mocks/MockUpgradable.sol";
import { MockUpgradableV2 } from "./utils/mocks/MockUpgradableV2.sol";
import { AvatarProxyManager } from "../contracts/solady/proxy/AvatarProxyManager.sol";
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { ERC1967Factory } from "solady/utils/ERC1967Factory.sol";

contract AvatarManagerTest is Test {

    // helper struct used for easy compare of value passing via proxy deploy to initialize
    struct TestDataForInitialize {
        address _owner;
        string _name;
        address payable _someAddress;
        address _addressTwo;
        bool _someBool;
        uint256 _maxSupply;
    }

    ERC1967Factory factory;
    AvatarProxyManager avatarManager;
    address avatarManagerOwner;
    address avatarCollectionImplementation;

    function setUp() public {
        factory = new ERC1967Factory();        
        avatarManagerOwner = makeAddr("avatarManagerOwner");        

        address minedFactoryAddress = 0x0000000000006396FF2a80c067f99B3d2Ab4Df24;
        vm.etch(minedFactoryAddress, address(factory).code);
        factory = ERC1967Factory(minedFactoryAddress);
    
        vm.prank(avatarManagerOwner);
        avatarManager = new AvatarProxyManager();

    }

    function testAddImplementation() public { //withFactories {
        address implementation0 = address(new MockImplementation());
        assertFalse(avatarManager.implementationExists(implementation0));

        vm.expectRevert();
        avatarManager.getImplementationVersion(implementation0);

        vm.prank(avatarManagerOwner);
        avatarManager.addImplementation(implementation0, 1);

        assertEq(avatarManager.getImplementationVersion(implementation0), 1);
    }

    function testDeploySimpleContract() public {
        uint256 implementation0Version = 1;
        address implementation0 = address(new MockImplementation());
        
        vm.startPrank(avatarManagerOwner);
        avatarManager.addImplementation(implementation0, implementation0Version);

        bytes memory data = abi.encodeWithSignature("setValue(uint256,uint256)", 1, 123);
        address avatarContract = avatarManager.deployCollection(implementation0Version, data);
        vm.stopPrank();

        assertEq(MockImplementation(avatarContract).getValue(1), 123);
    }

    function testDeployOwnableUpgradable() public {
        uint256 upgradableImplemetationVersion = 1;
        
        TestDataForInitialize memory t;
        t._owner = makeAddr("collectionOwner");
        t._name = "TestName";
        t._someAddress = payable(makeAddr("someAddress"));
        t._addressTwo = makeAddr("addressTwo");
        t._someBool = true;
        t._maxSupply = 222;

        bytes memory initializationArguments = _encodeInitializationARguments(t);
        
        MockUpgradable upgradableImplementation = new MockUpgradable();
        
        vm.startPrank(avatarManagerOwner);
        avatarManager.addImplementation(address(upgradableImplementation), upgradableImplemetationVersion);
        address avatarContractAddress = avatarManager.deployCollection(upgradableImplemetationVersion, initializationArguments);
        vm.stopPrank();

        MockUpgradable avatarContract = MockUpgradable(avatarContractAddress);
        _assetDataForInitializeIsCorrect(avatarContract, t);
    }

    function testDeployMultipleOwnableUpgradableProxiesToSameImplementation() public {
        uint256 collectionCount = 10;
        uint256 version = 1;

        MockUpgradable implementation = new MockUpgradable();
        
        vm.prank(avatarManagerOwner);
        avatarManager.addImplementation(address(implementation), version);

        // Create N random collections, each mapped to the same implementation and check that each has different inputs
        for (uint256 i = 0; i < collectionCount; i++) {            
            TestDataForInitialize memory t;
            t._owner = vm.addr(i + 1);
            t._name = vm.toString(i + 555);
            t._someAddress = payable(makeAddr(vm.toString(i)));
            t._addressTwo = makeAddr(vm.toString(i+1));
            t._someBool = true;
            t._maxSupply = i*100;            
            bytes memory initializationArguments = _encodeInitializationARguments(t);
            
            vm.prank(avatarManagerOwner);
            address avatarContractAddress = avatarManager.deployCollection(version, initializationArguments);

            MockUpgradable avatarContract = MockUpgradable(avatarContractAddress);
            _assetDataForInitializeIsCorrect(avatarContract, t);

        }
    }

    function testUpgradeImplementation() public {
        MockUpgradable implementation = new MockUpgradable();
        MockUpgradableV2 implementation2 = new MockUpgradableV2();

        vm.startPrank(avatarManagerOwner);
        avatarManager.addImplementation(address(implementation), 1);
        avatarManager.addImplementation(address(implementation2), 2);
        vm.stopPrank();
        
        TestDataForInitialize memory t;
        t._owner = makeAddr("owner");
        t._name = "TestContract";
        t._someAddress = payable(makeAddr("someAddress"));
        t._addressTwo = makeAddr("addressTwo");
        t._someBool = true;
        t._maxSupply = 555;
        bytes memory initializationArguments = _encodeInitializationARguments(t);
        
        vm.prank(avatarManagerOwner);
        address avatarContractAddress = avatarManager.deployCollection(1, initializationArguments);

        MockUpgradable avatarContract = MockUpgradable(avatarContractAddress);
        // assert that values are as expected before proxy change
        _assetDataForInitializeIsCorrect(avatarContract, t);
        
        assertEq(MockUpgradable(avatarContractAddress).VERSION(), "V1");

        vm.prank(avatarManagerOwner);
        avatarManager.updateCollection(avatarContractAddress, 2);

        // verify that the hew contract implementation is actually the new one
        assertEq(avatarContract.VERSION(), "V2");

        // assert that after the update, the proxy still holds the data, as expected
        _assetDataForInitializeIsCorrect(avatarContract, t);

    }

    function testBulkUpgradeImplementation() public {
        uint256 collectionCount = 10;

        MockUpgradable implementation = new MockUpgradable();
        MockUpgradableV2 implementation2 = new MockUpgradableV2();

        vm.startPrank(avatarManagerOwner);
        avatarManager.addImplementation(address(implementation), 1);
        avatarManager.addImplementation(address(implementation2), 2);
        vm.stopPrank();

        // Create N random collections, each mapped to the same implementation and check that each has different inputs
        for (uint256 i = 0; i < collectionCount; i++) {            
            TestDataForInitialize memory t;
            t._owner = vm.addr(i + 1);
            t._name = vm.toString(i + 555);
            t._someAddress = payable(makeAddr(vm.toString(i)));
            t._addressTwo = makeAddr(vm.toString(i+1));
            t._someBool = true;
            t._maxSupply = i*100;            
            bytes memory initializationArguments = _encodeInitializationARguments(t);
            
            vm.prank(avatarManagerOwner);
            avatarManager.deployCollection(1, initializationArguments);
        }

        // sanity check that all of them have V1 initially 
        for (uint256 i = 0; i < collectionCount; i++) {            
            assertEq(MockUpgradable(avatarManager.proxies(i)).VERSION(), "V1");
        }

        // update all of them with version 2
        vm.prank(avatarManagerOwner);
        avatarManager.updateCollectionsByVersion(1, 2);

        // check that all of them have the new implementation set
        for (uint256 i = 0; i < collectionCount; i++) {            
            assertEq(MockUpgradable(avatarManager.proxies(i)).VERSION(), "V2");
        }
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

    function _assetDataForInitializeIsCorrect(MockUpgradable avatarContract, TestDataForInitialize memory t) internal {
        assertEq(avatarContract.owner(), t._owner);
        assertEq(avatarContract.name(), t._name);
        assertEq(avatarContract.someAddress(), t._someAddress);
        assertEq(avatarContract.addressTwo(), t._addressTwo);
        assertEq(avatarContract.someBool(), t._someBool);
        assertEq(avatarContract.maxSupply(), t._maxSupply);
    }
}

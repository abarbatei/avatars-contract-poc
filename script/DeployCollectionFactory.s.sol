// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CollectionFactory } from "../contracts/beacon/proxy/CollectionFactory.sol";
import { Avatar } from "../contracts/beacon/avatar/Avatar.sol";

contract DeployCollectionFactory is Script {
    function setUp() public {}

    modifier asDeployer() {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }

    function run() public asDeployer {
        
        bytes32 beaconAlias = "avatarCollections";
        address collectionOwner = 0x4BF86138e9DC66Fb65F8b9387C53aB4439FC41FF;

        CollectionFactory collectionFactory = new CollectionFactory();
        Avatar implementation = new Avatar();

        console.log("Avatar implementation version 1 address:", address(implementation));
        console.log("Avatar implementation version 1 owner address:", address(implementation.owner()));
        console.log("collectionFactory address:", address(collectionFactory));
        console.log("collectionFactoryOwner address:", address(collectionFactory.owner()));

        collectionFactory.deployBeacon(address(implementation), beaconAlias);
        
        /*
            function initialize(
                address _collectionOwner,
                string memory _initialBaseURI,
                string memory _name,
                string memory _symbol,
                address payable _sandOwner,
                address _signAddress,
                address _initialTrustedForwarder,
                address _registry,
                address _operatorFiltererSubscription,
                bool _operatorFiltererSubscriptionSubscribe,
                uint256 _maxSupply
         */
        
        bytes memory initializationArguments = abi.encodeWithSignature(
            "initialize(address,string,string,string,address,address,address,address,address,bool,uint256)",
                collectionOwner,
                "http://google.com",
                "AvatarTest",
                "AT",
                collectionOwner, // sand owner
                collectionOwner,
                collectionOwner,
                collectionOwner,
                collectionOwner, 
                true, 
                2500);
        
        collectionFactory.deployCollection(beaconAlias, initializationArguments);
        console.log("After deployCollection");
        
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CollectionFactory } from "../contracts/beacon/proxy/FullCollectionFactory.sol";
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

        CollectionFactory collectionFactory = new CollectionFactory();
        Avatar simpleAvatarImplementation = new Avatar();

        console.log("Avatar implementation version 1 address:", address(simpleAvatarImplementation));
        console.log("Avatar implementation version 1 owner address:", address(simpleAvatarImplementation.owner()));
        console.log("collectionFactory address:", address(collectionFactory));
        console.log("collectionFactoryOwner address:", address(collectionFactory.owner()));

        collectionFactory.addImplementation(address(simpleAvatarImplementation), 1);

        address collectionOwner = 0x4BF86138e9DC66Fb65F8b9387C53aB4439FC41FF;
        
        bytes memory initializationArguments = abi.encodeWithSignature(
            "initialize(address,string,address,bool,uint256)",
            collectionOwner, "TestName", collectionOwner, true, 1000000000000000);

        collectionFactory.deployCollection(1, initializationArguments);
        console.log("After deployCollection");
    }
}
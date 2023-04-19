// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { AvatarProxyManager } from "../contracts/solady/proxy/AvatarProxyManager.sol";
import { Avatar } from "../contracts/solady/avatar/Avatar.sol";

contract AvatarProxy is Script {
    function setUp() public {}

    modifier asDeployer() {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }

    function run() public asDeployer {

        AvatarProxyManager avatarManager = new AvatarProxyManager();
        Avatar simpleAvatarImplementation = new Avatar();

        console.log("Avatar implementation version 1 address:", address(simpleAvatarImplementation));
        console.log("Avatar implementation version 1 owner address:", address(simpleAvatarImplementation.owner()));
        console.log("AvatarManager address:", address(avatarManager));
        console.log("AvatarManagerOwner address:", address(avatarManager.owner()));

        avatarManager.addImplementation(address(simpleAvatarImplementation), 1);

        address collectionOwner = 0x4BF86138e9DC66Fb65F8b9387C53aB4439FC41FF;
        
        bytes memory initializationArguments = abi.encodeWithSignature(
            "initialize(address,string,address,bool,uint256)",
            collectionOwner, "TestName", collectionOwner, true, 1000000000000000);

        avatarManager.deployCollection(1, initializationArguments);
        console.log("After deployCollection");
    }
}
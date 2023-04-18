// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { Script } from "forge-std/Script.sol";
import { AvatarProxyManager } from "../contracts/solady/proxy/AvatarProxyManager.sol";
import { Avatar } from "../contracts/solady/avatar/Avatar.sol";

contract AvatarProxy is Script {
    function setUp() public {}

    modifier asDeployer() {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        _;
        vm.stopBroadcast();
    }

    function run() public asDeployer {

        AvatarProxyManager avatarManager = new AvatarProxyManager();
        Avatar simpleAvatarImplementation = new Avatar();

        avatarManager.addImplementation(address(simpleAvatarImplementation), 1);

        address collectionOwner = 0x4BF86138e9DC66Fb65F8b9387C53aB4439FC41FF;
        
        bytes memory initializationArguments = abi.encodeWithSignature(
            "initialize(address,string,address,address,bool,uint256)",
            collectionOwner, 
            "TestName", 0x1, 0x2, false, 100);

        avatarManager.deployCollection(1, initializationArguments);
    }
}
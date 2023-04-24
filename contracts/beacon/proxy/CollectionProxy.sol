// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import { BeaconProxy } from "openzeppelin/proxy/beacon/BeaconProxy.sol";
import { StorageSlot } from "openzeppelin/utils/StorageSlot.sol";
import { Address } from "openzeppelin/utils/Address.sol";


contract CollectionProxy is BeaconProxy {

    constructor (address beacon_, bytes memory data_) BeaconProxy(beacon_, data_) {
        _changeAdmin(msg.sender);
    }

    /**
     * @dev any function from implementation address with a signature hash colistion of 59659e90 will reroute to here and cannot be executed 
     * Sighash   |   Function Signature
     * ========================  
     * 59659e90  =>  beacon()  
     */
    function beacon() external view returns (address){
        return _beacon();
    }
    
    /**
     * @dev any function from implementation address with a signature hash colistion of f8ab7198 will reroute to here and cannot be executed 
     * Sighash   |   Function Signature
     * =========================================  
     * f8ab7198  =>  changeBeacon(address,bytes)   
     */
    function changeBeacon(address newBeacon_, bytes memory data_) external {
        require (msg.sender == _getAdmin(), "CollectionProxy: only admin can change beacon");
        _setBeacon(newBeacon_, data_);
    }
}
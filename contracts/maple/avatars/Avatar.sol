pragma solidity 0.8.15;

import { ERC721Full } from "openzeppelin/token/ERC721/ERC721Full.sol";
import { Counters } from "openzeppelin/utils/Counters.sol";
import { IProxied } from "proxy-factory/interfaces/IProxied.sol";
import { ProxiedInternals } from "proxy-factory/ProxiedInternals.sol";


contract MockImplementationV1 is IProxied, ProxiedInternals {

    // Some "Nothing Up My Sleeve" Slot
    bytes32 private constant DELTA_SLOT = 0x1111111111111111111111111111111111111111111111111111111111111111;

    uint256 public constant override alpha = 1111;

    uint256 public override beta;
    uint256 public override charlie;

    // NOTE: This is implemented manually in order to support upgradeability and migrations
    // mapping(uint256 => uint256) public override deltaOf;

    function getLiteral() external pure override returns (uint256 literal_) {
        return 2222;
    }

    function getConstant() external pure override returns (uint256 constant_) {
        return alpha;
    }

    function getViewable() external view override returns (uint256 viewable_) {
        return beta;
    }

    function setBeta(uint256 beta_) external override {
        beta = beta_;
    }

    function setCharlie(uint256 charlie_) external override {
        charlie = charlie_;
    }

    function deltaOf(uint256 key_) public view override returns (uint256 delta_) {
        return uint256(_getSlotValue((_getReferenceTypeSlot(DELTA_SLOT, bytes32(key_)))));
    }

    function setDeltaOf(uint256 key_, uint256 delta_) public override {
        _setSlotValue(_getReferenceTypeSlot(DELTA_SLOT, bytes32(key_)), bytes32(delta_));
    }

    // Composability

    function getAnotherBeta(address other_) external view override returns (uint256 beta_) {
        return IMockImplementationV1(other_).beta();
    }

    function setAnotherBeta(address other_, uint256 beta_) external override {
        IMockImplementationV1(other_).setBeta(beta_);
    }

    // Proxied

    function migrate(address migrator_, bytes calldata arguments_) external override {
        require(msg.sender == _factory(),        "MI:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "MI:M:FAILED");
    }

    function setImplementation(address newImplementation_) external override {
        require(msg.sender == _factory(),               "MI:SI:NOT_FACTORY");
        require(_setImplementation(newImplementation_), "MI:SI:FAILED");
    }

    function factory() public view override returns (address factory_) {
        return _factory();
    }

    function implementation() public view override returns (address implementation_) {
        return _implementation();
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Factory for deploying and managing ERC1967 proxy contracts.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ERC1967Factory.sol)
/// @author jtriley-eth (https://github.com/jtriley-eth/minimum-viable-proxy)
interface IERC1967Factory {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The caller is not authorized to call the function.
    error Unauthorized();

    /// @dev The proxy deployment failed.
    error DeploymentFailed();

    /// @dev The upgrade failed.
    error UpgradeFailed();

    /// @dev The salt does not start with the caller.
    error SaltDoesNotStartWithCaller();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The admin of a proxy contract has been changed.
    event AdminChanged(address indexed proxy, address indexed admin);

    /// @dev The implementation for a proxy has been upgraded.
    event Upgraded(address indexed proxy, address indexed implementation);

    /// @dev A proxy has been deployed.
    event Deployed(address indexed proxy, address indexed implementation, address indexed admin);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the admin of the proxy.
    function adminOf(address proxy) external view returns (address admin);

    /// @dev Sets the admin of the proxy.
    /// The caller of this function must be the admin of the proxy on this factory.
    function changeAdmin(address proxy, address admin) external;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Upgrades the proxy to point to `implementation`.
    /// The caller of this function must be the admin of the proxy on this factory.
    function upgrade(address proxy, address implementation) external payable;

    /// @dev Upgrades the proxy to point to `implementation`.
    /// Then, calls the proxy with abi encoded `data`.
    /// The caller of this function must be the admin of the proxy on this factory.
    function upgradeAndCall(address proxy, address implementation, bytes calldata data) 
        external 
        payable;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      DEPLOY FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deploys a proxy for `implementation`, with `admin`,
    /// and returns its address.
    /// The value passed into this function will be forwarded to the proxy.
    function deploy(address implementation, address admin) external payable returns (address proxy);

    /// @dev Deploys a proxy for `implementation`, with `admin`,
    /// and returns its address.
    /// The value passed into this function will be forwarded to the proxy.
    /// Then, calls the proxy with abi encoded `data`.
    function deployAndCall(address implementation, address admin, bytes calldata data) 
        external 
        payable 
        returns (address proxy);
    

    /// @dev Deploys a proxy for `implementation`, with `admin`, `salt`,
    /// and returns its deterministic address.
    /// The value passed into this function will be forwarded to the proxy.
    function deployDeterministic(address implementation, address admin, bytes32 salt)
        external
        payable
        returns (address proxy);
    

    /// @dev Deploys a proxy for `implementation`, with `admin`, `salt`,
    /// and returns its deterministic address.
    /// The value passed into this function will be forwarded to the proxy.
    /// Then, calls the proxy with abi encoded `data`.
    function deployDeterministicAndCall(
        address implementation,
        address admin,
        bytes32 salt,
        bytes calldata data
    ) external payable returns (address proxy);

    /// @dev Returns the address of the proxy deployed with `salt`.
    function predictDeterministicAddress(bytes32 salt) external view returns (address predicted);

    /// @dev Returns the initialization code hash of the proxy.
    /// Used for mining vanity addresses with create2crunch.
    function initCodeHash() external view returns (bytes32 result);
}

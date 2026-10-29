// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Selected functions of the already-deployed Flap TokenV2 implementation.
interface IFlapTokenV2Clone {
    function initialize(
        address v2Pool, address v3Pool, string calldata name_,
        string calldata symbol_, string calldata meta_, uint256 maxSupply_
    ) external;
    function balanceOf(address account) external view returns (uint256);
    function owner() external view returns (address);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
}

/// @notice Research-only factory using the EXISTING BSC implementation.
/// @dev The implementation mints to msg.sender during initialize: that is this
/// factory. It atomically forwards all minted tokens and ownership to the caller.
/// The resulting clone is unrelated to any existing token's balances or identity.
contract FlapTokenV2CloneFactory {
    address public constant IMPLEMENTATION = 0x8B4329947e34B6d56D71A3385caC122BaDe7d78D;

    error WrongChain();
    error MissingImplementation();
    error CloneCreationFailed();
    error InvalidSupply();
    error ForwardTransferFailed();
    error OwnershipNotTransferred();

    event ResearchCloneCreated(address indexed clone, address indexed creator, uint256 supply);

    constructor() {
        if (block.chainid != 56) revert WrongChain();
        if (IMPLEMENTATION.code.length == 0) revert MissingImplementation();
    }

    function createResearchClone(
        address v2Pool,
        address v3Pool,
        string calldata name_,
        string calldata symbol_,
        string calldata meta_,
        uint256 supply
    ) external returns (address clone) {
        if (supply == 0) revert InvalidSupply();

        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            IMPLEMENTATION,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        assembly {
            clone := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        if (clone == address(0)) revert CloneCreationFailed();

        IFlapTokenV2Clone token = IFlapTokenV2Clone(clone);
        token.initialize(v2Pool, v3Pool, name_, symbol_, meta_, supply);
        // Mint in the implementation goes to address(this), not the end user.
        if (!token.transfer(msg.sender, supply)) revert ForwardTransferFailed();
        token.transferOwnership(msg.sender);
        if (token.owner() != msg.sender) revert OwnershipNotTransferred();

        emit ResearchCloneCreated(clone, msg.sender, supply);
    }
}

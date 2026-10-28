// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IResearchTokenInitializer {
    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint256 initialSupply_,
        address recipient_
    ) external;
}

/// @title CloneFactory
/// @notice Atomically deploy and initialize EIP-1167 clones for local research.
contract CloneFactory {
    address public immutable implementation;

    error InvalidImplementation();
    error CloneCreationFailed();

    event CloneCreated(address indexed clone, address indexed implementation, address indexed recipient);

    constructor(address implementation_) {
        if (implementation_.code.length == 0) revert InvalidImplementation();
        implementation = implementation_;
    }

    function createClone(
        string calldata name_,
        string calldata symbol_,
        uint256 initialSupply_
    ) external returns (address clone) {
        // 10-byte creation prefix + 45-byte EIP-1167 runtime bytecode.
        bytes memory creationCode = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        assembly {
            clone := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        if (clone == address(0)) revert CloneCreationFailed();

        // Critical: initializer executes in the SAME transaction as deployment.
        IResearchTokenInitializer(clone).initialize(name_, symbol_, initialSupply_, msg.sender);
        emit CloneCreated(clone, implementation, msg.sender);
    }
}

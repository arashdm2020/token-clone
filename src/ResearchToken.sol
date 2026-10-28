// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ResearchToken
/// @notice Educational ERC-20-like implementation for EIP-1167 clone experiments.
/// @dev The implementation is locked. Each clone has independent storage.
contract ResearchToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bool private initialized;

    error AlreadyInitialized();
    error InvalidRecipient();
    error InsufficientBalance();
    error InsufficientAllowance();

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // Prevent a third party from initializing the implementation itself.
        initialized = true;
    }

    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint256 initialSupply_,
        address recipient_
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (recipient_ == address(0)) revert InvalidRecipient();
        initialized = true;
        name = name_;
        symbol = symbol_;
        totalSupply = initialSupply_;
        balanceOf[recipient_] = initialSupply_;
        emit Transfer(address(0), recipient_, initialSupply_);
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        uint256 approved = allowance[sender][msg.sender];
        if (approved < amount) revert InsufficientAllowance();
        if (approved != type(uint256).max) {
            allowance[sender][msg.sender] = approved - amount;
            emit Approval(sender, msg.sender, approved - amount);
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        if (recipient == address(0)) revert InvalidRecipient();
        uint256 available = balanceOf[sender];
        if (available < amount) revert InsufficientBalance();
        unchecked { balanceOf[sender] = available - amount; }
        balanceOf[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
}

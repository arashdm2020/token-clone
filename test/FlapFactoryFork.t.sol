// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FlapTokenV2CloneFactory, IFlapTokenV2Clone} from "../src/FlapTokenV2CloneFactory.sol";

/// @notice Real BSC fork test. Does not broadcast transactions.
contract FactoryCaller {
    function create(FlapTokenV2CloneFactory factory) external returns (address) {
        return factory.createResearchClone(
            address(0x1001), address(0x1002),
            "Fork Research Credit", "FRCR", "fork-only-research", 1000 ether
        );
    }
}

contract FlapFactoryForkTest {
    address constant IMPL = 0x8B4329947e34B6d56D71A3385caC122BaDe7d78D;

    function testIndependentFactoryInitializesAndDeliversOwnershipAndSupply() public {
        require(block.chainid == 56, "BSC mainnet fork required");
        require(IMPL.code.length > 0, "implementation missing");
        FlapTokenV2CloneFactory factory = new FlapTokenV2CloneFactory();
        FactoryCaller user = new FactoryCaller();
        address clone = user.create(factory);
        IFlapTokenV2Clone token = IFlapTokenV2Clone(clone);

        require(clone.code.length == 45, "not EIP-1167 runtime");
        require(token.owner() == address(user), "ownership retained by factory");
        require(token.balanceOf(address(user)) == 1000 ether, "mint not forwarded");
        require(token.balanceOf(address(factory)) == 0, "factory retains token balance");

        // Verify exact embedded implementation address at bytes 10..29.
        bytes memory runtime = clone.code;
        address target;
        assembly { target := shr(96, mload(add(runtime, 42))) }
        require(target == IMPL, "wrong implementation target");

        // A second independent clone has independent state.
        address clone2 = user.create(factory);
        require(clone2 != clone, "duplicate clone address");
        require(IFlapTokenV2Clone(clone2).balanceOf(address(user)) == 1000 ether, "clone2 mint wrong");
        require(token.balanceOf(address(user)) == 1000 ether, "clone1 storage contaminated");
    }
}

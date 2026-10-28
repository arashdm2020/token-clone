// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ResearchToken} from "../src/ResearchToken.sol";
import {CloneFactory} from "../src/CloneFactory.sol";

/// @dev Self-contained Foundry tests. No forge-std or network dependencies.
contract CloneFactoryTest {
    uint256 constant ONE = 1e18;
    address constant RECIPIENT = address(0xBEEF);

    function _factory() internal returns (ResearchToken implementation, CloneFactory factory) {
        implementation = new ResearchToken();
        factory = new CloneFactory(address(implementation));
    }

    function testCloneHasCorrectEIP1167Implementation() public {
        (ResearchToken implementation, CloneFactory factory) = _factory();
        address clone = factory.createClone("Research Credit A", "RCA", 100 * ONE);
        bytes memory runtime = clone.code;
        require(runtime.length == 45, "runtime must be 45 bytes");
        address embedded;
        assembly { embedded := shr(96, mload(add(add(runtime, 0x20), 10))) }
        require(embedded == address(implementation), "wrong delegatecall target");
    }

    function testTwoClonesHaveIndependentBalances() public {
        (, CloneFactory factory) = _factory();
        ResearchToken a = ResearchToken(factory.createClone("Research Credit A", "RCA", 100 * ONE));
        ResearchToken b = ResearchToken(factory.createClone("Research Credit B", "RCB", 50 * ONE));
        require(a.balanceOf(address(this)) == 100 * ONE, "bad A initial balance");
        require(b.balanceOf(address(this)) == 50 * ONE, "bad B initial balance");
        require(a.transfer(RECIPIENT, 30 * ONE), "transfer failed");
        require(a.balanceOf(RECIPIENT) == 30 * ONE, "A receiver balance");
        require(b.balanceOf(RECIPIENT) == 0, "B storage leaked into A");
        require(b.balanceOf(address(this)) == 50 * ONE, "B balance changed");
    }

    function testTransferDoesNotRequireLiquidityPool() public {
        (, CloneFactory factory) = _factory();
        ResearchToken token = ResearchToken(factory.createClone("Research Credit", "RSCH", 30 * ONE));
        require(token.transfer(RECIPIENT, 30 * ONE), "transfer failed");
        require(token.balanceOf(RECIPIENT) == 30 * ONE, "receiver missing credits");
        // No DEX contract, liquidity pool, price feed, or stablecoin is deployed.
    }

    function testImplementationIsLocked() public {
        (ResearchToken implementation,) = _factory();
        (bool ok,) = address(implementation).call(
            abi.encodeCall(ResearchToken.initialize, ("Bad", "BAD", ONE, address(this)))
        );
        require(!ok, "implementation must be locked");
    }

    function testCloneCannotBeReinitialized() public {
        (, CloneFactory factory) = _factory();
        ResearchToken token = ResearchToken(factory.createClone("Research Credit", "RSCH", ONE));
        (bool ok,) = address(token).call(
            abi.encodeCall(ResearchToken.initialize, ("Other", "OTHER", ONE, address(this)))
        );
        require(!ok, "clone reinitialized");
        require(token.totalSupply() == ONE, "supply changed");
    }
}

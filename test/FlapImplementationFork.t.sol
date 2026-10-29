// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Run only on a BSC mainnet fork:
// forge test --match-contract FlapImplementationForkTest --fork-url "$BSC_RPC_URL" -vvv
interface IFlapTokenV2 {
    function initialize(address v2Pool, address v3Pool, string memory name_,
        string memory symbol_, string memory meta_, uint256 maxSupply_) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function owner() external view returns (address);
    function transfer(address, uint256) external returns (bool);
}

contract FlapImplementationForkTest {
    address constant IMPL = 0x8B4329947e34B6d56D71A3385caC122BaDe7d78D;
    address constant RECIPIENT = address(0xBEEF);
    uint256 constant SUPPLY = 1000 ether;
    event Note(string message, address addr);

    function _clone() internal returns (address clone) {
        bytes memory code = abi.encodePacked(
            hex"3d602d80600a3d3981f3",
            hex"363d3d373d3d3d363d73",
            IMPL,
            hex"5af43d82803e903d91602b57fd5bf3"
        );
        assembly { clone := create(0, add(code, 0x20), mload(code)) }
        require(clone != address(0), "clone failed");
        require(clone.code.length == 45, "not a minimal proxy");
    }

    function testCloneInitializeAndTransferAgainstLiveImplementation() public {
        require(block.chainid == 56, "BSC mainnet fork required");
        require(IMPL.code.length > 0, "implementation missing from fork");
        address clone = _clone();
        emit Note("implementation", IMPL);
        emit Note("fresh clone on local fork", clone);
        // Deliberately named research-only asset. No stablecoin impersonation.
        IFlapTokenV2(clone).initialize(
            address(0x1001), address(0x1002),
            "Fork Research Credit", "FRCR", "local-fork-test", SUPPLY
        );
        require(IFlapTokenV2(clone).owner() == address(this), "unexpected owner");
        require(IFlapTokenV2(clone).totalSupply() == SUPPLY, "unexpected supply");
        require(IFlapTokenV2(clone).balanceOf(address(this)) == SUPPLY, "mint receiver mismatch");
        require(IFlapTokenV2(clone).transfer(RECIPIENT, 30 ether), "transfer failed");
        require(IFlapTokenV2(clone).balanceOf(RECIPIENT) == 30 ether, "recipient mismatch");
        require(IFlapTokenV2(clone).balanceOf(address(this)) == 970 ether, "sender mismatch");
        // Reinitialization should fail on a previously initialized clone.
        (bool ok,) = clone.call(abi.encodeWithSelector(
            IFlapTokenV2.initialize.selector,
            address(0x1001), address(0x1002), "Other", "OTH", "x", SUPPLY
        ));
        require(!ok, "reinitialization unexpectedly succeeded");
    }
}

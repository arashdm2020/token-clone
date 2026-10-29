# Test the REAL Flap implementation on a BSC mainnet fork

This test does **not** deploy a new implementation. It uses the already-deployed
mainnet TokenV2 implementation at:

`0x8b4329947e34b6d56d71a3385cac122bade7d78d`

Run from repository root in WSL with Foundry installed:

```bash
export BSC_RPC_URL=https://bsc-dataseed.bnbchain.org
cast chain-id --rpc-url "$BSC_RPC_URL"  # expected: 56
forge test --match-contract FlapImplementationForkTest --fork-url "$BSC_RPC_URL" -vvv
```

The test clones the *live* implementation, initializes it with a clearly marked
research name, checks owner and supply, transfers 30 units, and checks that
re-initialization fails. All state changes occur **only on the temporary fork**.
No private key, gas payment, mainnet write, or token registry change is required.

If the RPC rejects `eth_getCode` or historical state, try a different BSC RPC
endpoint with appropriate state support. This uses the **latest** state by
default and does not require archive history.

**Caveat:** This is a direct clone plus initialization by a test contract, not a
full separate CloneFactory deployment. A Factory that directly calls
`initialize` would become `msg.sender` and receive initial mint / ownership
under the currently analyzed TokenV2 initializer. Its authorization and custody
logic must be considered separately.

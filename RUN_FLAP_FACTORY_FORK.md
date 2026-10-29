# Existing Flap Implementation: independent EIP-1167 factory fork test

The factory in `src/FlapTokenV2CloneFactory.sol` uses the live BSC TokenV2 implementation at `0x8B4329947e34B6d56D71A3385caC122BaDe7d78D`. It **does not deploy a new implementation**.

Run from WSL with Foundry:

```bash
cd ~/Projects/token-clone
export BSC_RPC_URL=https://bsc-dataseed.bnbchain.org
forge test --match-contract FlapFactoryForkTest --fork-url "$BSC_RPC_URL" -vvvv
```

Expected assertions: 45-byte EIP-1167 runtime, fixed embedded implementation address, initialization in the same transaction as deployment, forwarding the entire initial supply from the factory to its caller, ownership transfer to caller, zero tokens retained in the factory, and isolation of two clones.

**No public-network transaction is broadcast by `forge test`.** This does not test Trust Wallet discovery, logo, price assignment, Flap platform indexing, liquidity, or reserve backing.

Do not deploy before reviewing the upstream TokenV2 transfer constraints and checking every assumption on a fork. For research, use an unambiguous name and symbol rather than impersonating any established stablecoin.

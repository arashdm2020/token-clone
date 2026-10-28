# Token Clone / Wallet Price Attribution Research PoC

A defensive research project investigating EIP-1167 minimal proxies, independent ERC-20 token state, and why a wallet UI may display an apparent USD value for a token without corresponding stablecoin reserves.

Case transaction: https://bscscan.com/tx/0xb180b03b30a368c112855a79bd90cec5597204c20d6b6bdf14c5cf8ee1af8f77

This repository has three independent parts:

1. Foundry Solidity contracts and tests for atomic minimal-proxy deployment, independent storage, initialization safety, and successful transfers without any liquidity pool.
2. Read-only Go RPC analysis of the case transaction, token code, embedded EIP-1167 implementation, and balances on two different token contracts.
3. Offline JavaScript simulation of unsafe symbol-based price attribution versus price lookup keyed by chain ID and contract address.

## Run

Requirements: Foundry (Solidity 0.8.24), Go 1.22+, Node 20+.

    forge test -vvv
    go test ./...
    node --test demo/test/*.test.mjs
    node demo/pricing.mjs

Read-only chain inspector (requires a BSC RPC URL):

    export BSC_RPC_URL=https://YOUR_BSC_RPC_ENDPOINT
    go run ./cmd/inspect

## Critical distinctions

- A successful ERC-20 transfer changes the token's own storage and does not imply an equivalent USD value, stablecoin reserves, redemption, or DEX liquidity.
- A minimal proxy executes its implementation by DELEGATECALL, but each clone has its own storage and balances.
- A wallet's approximate fiat value is a UI/provider assertion, not a property established by the transfer receipt.
- The pricing example is a hypothetical vulnerable resolver, NOT a claim that Trust Wallet uses that mechanism.
- The deployable token uses an explicitly educational name (Research Credit), not the name of any existing stablecoin. No mainnet deployment or wallet-impersonation workflow is provided.

License: MIT.

# EIP-1167 Token Clone & Wallet Price Attribution — Research PoC

A **defensive, reproducible investigation** of how an ERC-20-style token can transfer successfully with **zero DEX liquidity** and how a wallet-like interface can **misattribute a USD value** if a pricing service matches on token symbols instead of `(chainId, contractAddress)`.

> **Scope:** local Foundry clones + read-only BSC inspection + a deliberately vulnerable **offline** pricing simulation. This repository does **not** establish that Trust Wallet uses the demonstrated vulnerable algorithm; the screenshot alone cannot identify the pricing provider or cache path. This PoC does not create a purported USDT asset or deploy to mainnet.

## Case being investigated

- [BSC transaction](https://bscscan.com/tx/0xb180b03b30a368c112855a79bd90cec5597204c20d6b6bdf14c5cf8ee1af8f77)
- Token addressed by transaction: `0x0d8847c7d02552bca663ab9efc0ac65437038888`
- Genuine BSC Binance-Peg USDT: `0x55d398326f99059fF775485246999027B3197955`
- Question: why does a wallet display an approximately $30 value for 30 units of a different token?

**Three independent layers:** (a) transaction success, (b) token market liquidity/redeemability, and (c) wallet's off-chain fiat valuation. A transfer event proves only (a). A successful `transfer()` is not evidence that real USDT moved or that the asset can be redeemed for $30.

## Project layout

| Path | Purpose |
| --- | --- |
| `src/ResearchToken.sol` | Minimal educational token implementation; initial supply minted once, storage per clone |
| `src/CloneFactory.sol` | EIP-1167 factory, **atomic** clone deployment + initialization |
| `test/CloneFactory.t.sol` | Clone target, independent storage, transfer with no pool, reinitialization checks |
| `cmd/inspect` | Read-only Go JSON-RPC inspector of transaction, bytecode and two separate `balanceOf()` states |
| `demo/pricing.mjs` | Deliberately incorrect Unicode-symbol price resolver vs. address-keyed price resolver |

## Requirements

- [Foundry](https://getfoundry.sh/) (Solidity 0.8.24)
- Go 1.22+
- Node.js 20+
- For live chain reads only: a **BSC mainnet JSON-RPC HTTPS** URL. No seed phrase, wallet signing, API key in source, or BNB required.

## Run locally

```sh
forge test -vvv
go test ./...
node --test demo/test/*.test.mjs
node demo/pricing.mjs
```

The Foundry tests deploy an implementation and **two independent clones** in a simulated local EVM. `testTransferDoesNotRequireLiquidityPool()` transfers 30 research credits without deploying a DEX, supplying reserves, or using an oracle. `testTwoClonesHaveIndependentBalances()` demonstrates that `DELEGATECALL` does **not** share the implementation's storage or another clone's balances.

## Inspect the provided BSC transaction (read only)

```sh
export BSC_RPC_URL='https://YOUR_BSC_RPC_ENDPOINT'
go run ./cmd/inspect
# Override transaction:
go run ./cmd/inspect -tx 0xYOUR_TRANSACTION_HASH
```

The inspector verifies chain ID `56`, reads `eth_getTransactionByHash`, receipt, runtime bytecode via `eth_getCode`, checks for the **exact 45-byte EIP-1167 pattern**, and extracts its embedded 20-byte implementation. It separately invokes `balanceOf(recipient)` on the transaction's target token and the known BSC USDT contract.

**Caveats:** `balanceOf()` values are obtained at `latest`, not at the historical transaction block; subsequent transfers can change balances. A zero `effectiveGasPrice` explains a zero displayed BNB network fee for a transaction but has no bearing on token collateral or valuation. Token names and symbols are not authoritative identifiers.

## The offline wallet-pricing hypothesis

The hypothetical vulnerable path uses **only** a Unicode-normalized symbol:

```js
symbol.normalize('NFKC').toUpperCase() // a lookalike symbol can normalize to "USDT"
```

If a toy service keys a price table as `{"USDT": 1}`, it can assign `$30` to 30 units of an unrelated token. The hardened toy resolver instead keys on `56:0x55d398...` and returns **no price** for the unrelated address. **Neither path claims to reproduce the Trust Wallet app or its servers.**

To establish the *actual* wallet failure mode, obtain the wallet app/version, token detail view, backend price-provider response and response mapping, then correlate all of these against `chainId` and `contractAddress`. An approximate dollar amount in a transaction UI is **not** an on-chain fact.

## Security constraints

- No counterfeit stablecoin naming in the deployable Solidity sample; this uses `Research Credit` / `RSCH`.
- `initialize()` is called **atomically** in the same transaction that creates the clone. Uninitialized clones can be claimed by arbitrary callers if exposed.
- The implementation constructor disables initialization of the implementation itself.
- No production launch, liquidity manipulation, phishing workflow, or instructions for tricking wallet recipients.
- This is educational code, **not audited** for use as a production asset.

## License

MIT.

## Automatic token-transfer discovery vs. enabling a wallet asset

**The reported wallet behavior does not require manual importing of the clone contract.**
An address-based transaction indexer can discover ERC-20 `Transfer` logs for an
account by looking at indexed `from` and `to` topics. The log's **emitting
contract** identifies the token. This discovery step does not mean that the
unknown token shares identity, balances, a logo, or a price with a pre-enabled
asset. `Received` and `Sent` history can also be presented separately from
portfolio asset-specific history.

Trust Wallet's public [Universal Asset ID documentation](https://developer.trustwallet.com/developer/new-asset/universal_asset_id)
uses the chain and token identifier, and the [asset registry](https://github.com/trustwallet/assets)
provides logos as **off-chain** metadata keyed by token address. The icon is
not embedded in ERC-20 or EIP-1167 bytecode. Trust Wallet's exact Android/iOS
transaction-history and caching implementation is not established by this PoC.

**Offline experiment with no manual token import**:

```sh
node demo/discovery.mjs
node --test demo/test/*.test.mjs
```

The simulated wallet has **only the known BSC USDT asset enabled**. The generic
account-history indexer still discovers the original case token's transfer.
Strict asset identity finds a separate unknown token with a generic icon and
no price; a deliberately incorrect symbol-based resolver maps a lookalike
Unicode symbol to the wrong record and can consequently misattribute **all
three fields (label, icon and value)**. This is an intentionally unsafe local
comparison, **not a Trust Wallet exploit**, logo submission workflow, or
assertion that any real wallet uses such lookup.

For authoritative chain evidence, run the read-only Go inspector. It now
parses ERC-20 `Transfer` logs in the transaction **receipt** and prints their
actual emitting contract addresses, distinguishing an event from the token
under investigation from an event emitted by the real BSC USDT contract.
This establishes which contract transferred tokens, independently of any
wallet UI or pricing service:

```sh
BSC_RPC_URL='https://YOUR_BSC_RPC_ENDPOINT' go run ./cmd/inspect
```

**Investigation checklist:** capture (a) sender *and* recipient wallet pages,
(b) the asset detail/contract page, (c) screenshot of the enabled assets and
balances before/after, (d) wallet app/version and network, and (e) full receipt
logs. The previously supplied screenshot says **Sent** and does not itself
show the token logo or the receiving wallet's balance.

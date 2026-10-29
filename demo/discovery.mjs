/**
 * Wallet discovery & identity attribution LAB, entirely offline.
 * Not Trust Wallet source code or an assertion of a real Trust Wallet defect.
 * Uses textual icon IDs rather than any third-party logos.
 */
export const incident = Object.freeze({
  chainId: 56,
  txHash: '0xb180b03b30a368c112855a79bd90cec5597204c20d6b6bdf14c5cf8ee1af8f77',
  sender: '0xfff65f924ecc07fb67a272c248010caeb1d69313',
  recipient: '0xf32565df6abb4891e5959b7291fecf61a5c6f786',
  emitterContract: '0x0d8847c7d02552bca663ab9efc0ac65437038888',
  onchainSymbol: '𝖴𝖲𝖣𝖳',
  amount: 30,
});

// A simplified fixture based on a known registry identity, not a live quote.
export const knownAsset = Object.freeze({
  chainId: 56,
  contract: '0x55d398326f99059fF775485246999027B3197955',
  symbol: 'USDT',
  label: 'Tether USD',
  iconId: 'known-asset-icon',
  iconProvenance: 'offchain-asset-registry',
  illustrativePrice: 0.99967,
});

export function assetId(chainId, contract) {
  if (!Number.isInteger(chainId) || chainId <= 0 || !/^0x[\da-fA-F]{40}$/.test(contract)) {
    throw new TypeError('Expected a valid EVM chain ID and 20-byte contract');
  }
  return `${chainId}:${contract.toLowerCase()}`;
}

export function indexedActivity(event, wallet) {
  const addr = wallet.toLowerCase();
  const direction = event.sender.toLowerCase() === addr ? 'Sent'
    : event.recipient.toLowerCase() === addr ? 'Received' : null;
  if (!direction) return null;
  return {
    txHash: event.txHash,
    direction,
    amount: event.amount,
    source: 'indexed-token-transfer',
    contract: event.emitterContract,
    assetId: assetId(event.chainId, event.emitterContract),
  };
}

export function resolvesInEnabledAssetHistory(event, enabledAssets) {
  return enabledAssets.includes(assetId(event.chainId, event.emitterContract));
}

// Proper identification: chain ID + emitting token contract.
export function strictIdentity(event, registry = [knownAsset]) {
  const id = assetId(event.chainId, event.emitterContract);
  const matched = registry.find(a => assetId(a.chainId, a.contract) === id);
  return {
    id, symbol: matched?.symbol ?? event.onchainSymbol,
    label: matched?.label ?? 'Unrecognized token',
    iconId: matched?.iconId ?? 'generic-icon',
    iconProvenance: matched?.iconProvenance ?? 'generic-fallback',
    usdValue: matched ? Number((event.amount * matched.illustrativePrice).toFixed(2)) : null,
    identityMatchedContract: matched?.contract ?? null,
  };
}

// BUG SIMULATION ONLY: how a hypothetical resolver could attach another
// asset's icon/name/price without a token import. NOT a real-wallet exploit.
export function unsafeSymbolIdentity(event, registry = [knownAsset]) {
  const matched = registry.find(a => a.symbol.normalize('NFKC').toUpperCase()
    === event.onchainSymbol.normalize('NFKC').toUpperCase());
  if (!matched) return strictIdentity(event, []);
  return {
    id: assetId(event.chainId, event.emitterContract),
    symbol: matched.symbol,
    label: matched.label,
    iconId: matched.iconId,
    iconProvenance: 'INCORRECT: matched by normalized symbol',
    usdValue: Number((event.amount * matched.illustrativePrice).toFixed(2)),
    identityMatchedContract: matched.contract,
  };
}

export function collisions(event, registry = [knownAsset]) {
  return registry.filter(a =>
    assetId(a.chainId, a.contract) !== assetId(event.chainId, event.emitterContract)
    && a.symbol.normalize('NFKC') === event.onchainSymbol.normalize('NFKC')
  ).map(a => ({kind: 'SYMBOL_COLLISION_DIFFERENT_CONTRACT', known: assetId(a.chainId, a.contract),
    observed: assetId(event.chainId, event.emitterContract)}));
}

export function report() {
  const enabledAssets = [assetId(knownAsset.chainId, knownAsset.contract)];
  console.log(JSON.stringify({
    disclaimer: 'Offline forensic model; NOT a Trust Wallet API or proof of its implementation',
    importedUnknownToken: false,
    enabledAssets,
    senderAddressActivity: indexedActivity(incident, incident.sender),
    recipientAddressActivity: indexedActivity(incident, incident.recipient),
    visibleInEnabledUSDTAssetHistory: resolvesInEnabledAssetHistory(incident, enabledAssets),
    strict: strictIdentity(incident),
    hypotheticalWrongAttribution: unsafeSymbolIdentity(incident),
    collisions: collisions(incident),
    screenshotCaveat: 'The supplied screenshot says Sent, not Received, and does not show a contract or an icon.',
  }, null, 2));
}
if (process.argv[1]?.endsWith('/discovery.mjs')) report();

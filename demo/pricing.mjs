// LOCAL SIMULATION ONLY. This does not implement or assert Trust Wallet's pricing backend.
export const sample = Object.freeze({
  chainId: 56,
  official: {
    address: '0x55d398326f99059fF775485246999027B3197955',
    symbol: 'USDT',
  },
  unrelated: {
    address: '0x0d8847c7d02552bca663ab9efc0ac65437038888',
    symbol: '𝖴𝖲𝖣𝖳',
  },
});

// Deliberately vulnerable toy resolver: keys only by a Unicode-normalized symbol.
export function unsafeSymbolPrice(symbol, symbolPrices) {
  return symbolPrices[symbol.normalize('NFKC').toUpperCase()] ?? null;
}

// Correct identity matching must use chain ID + contract address.
export function identityPrice(chainId, address, identityPrices) {
  return identityPrices[`${chainId}:${address.toLowerCase()}`] ?? null;
}

if (process.argv[1]?.endsWith('pricing.mjs')) {
  const symbolPrices = { USDT: 1.0 };
  const identityPrices = {
    [`56:${sample.official.address.toLowerCase()}`]: 1.0,
  };
  console.log('SIMULATION (not a Trust Wallet reverse engineering result)');
  console.log('Unicode normalized:', sample.unrelated.symbol.normalize('NFKC'));
  console.log('Symbol-only pseudo-value for 30 tokens: $', 30 * unsafeSymbolPrice(sample.unrelated.symbol, symbolPrices));
  console.log('Identity-based price for unrelated contract:', identityPrice(56, sample.unrelated.address, identityPrices));
}

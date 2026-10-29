import assert from 'node:assert/strict';
import { test } from 'node:test';
import { sample, unsafeSymbolPrice, identityPrice } from '../pricing.mjs';

test('NFKC normalization can collapse lookalike symbols', () => {
  assert.equal(sample.unrelated.symbol.normalize('NFKC'), 'USDT');
  assert.equal(unsafeSymbolPrice(sample.unrelated.symbol, {USDT: 1}), 1);
});

test('chain + contract keyed pricing never conflates these two identities', () => {
  const prices = { [`56:${sample.official.address.toLowerCase()}`]: 1 };
  assert.equal(identityPrice(56, sample.official.address, prices), 1);
  assert.equal(identityPrice(56, sample.unrelated.address, prices), null);
  assert.equal(identityPrice(1, sample.official.address, prices), null);
});

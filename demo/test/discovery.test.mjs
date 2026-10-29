import { test } from 'node:test';
import assert from 'node:assert/strict';
import { incident, knownAsset, assetId, indexedActivity, resolvesInEnabledAssetHistory,
  strictIdentity, unsafeSymbolIdentity, collisions } from '../discovery.mjs';

test('discovery works without adding the contract to enabled tokens', () => {
  const enabled = [assetId(knownAsset.chainId, knownAsset.contract)];
  assert.equal(indexedActivity(incident, incident.recipient).direction, 'Received');
  assert.equal(indexedActivity(incident, incident.sender).direction, 'Sent');
  assert.equal(resolvesInEnabledAssetHistory(incident, enabled), false);
});

test('strict identity never inherits another token icon, name or fiat price', () => {
  const identity = strictIdentity(incident);
  assert.equal(identity.iconId, 'generic-icon');
  assert.equal(identity.usdValue, null);
  assert.equal(identity.identityMatchedContract, null);
});

test('unsafe local model shows a symbol collision could misattribute icon and price', () => {
  const identity = unsafeSymbolIdentity(incident);
  assert.equal(identity.iconId, knownAsset.iconId);
  assert.equal(identity.usdValue, 29.99);
  assert.equal(identity.identityMatchedContract, knownAsset.contract);
  assert.equal(collisions(incident).length, 1);
});

test('asset identity rejects invalid address and never conflates contracts', () => {
  assert.notEqual(assetId(56, knownAsset.contract), assetId(56, incident.emitterContract));
  assert.notEqual(assetId(56, knownAsset.contract), assetId(1, knownAsset.contract));
  assert.throws(() => assetId(56, 'USDT'));
  assert.equal(indexedActivity(incident, '0x0000000000000000000000000000000000000000'), null);
});

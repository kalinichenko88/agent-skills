import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ownIcon } from './own-icon.js';

test('reads the icon link of the page', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => new Response('<link rel="icon" href="/fav.png">'));
  assert.equal(await ownIcon('a.example'), 'https://a.example/fav.png');
});

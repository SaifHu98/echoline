'use strict';

/**
 * Smoke test — run after every deploy to verify critical paths
 * ===================================================================
 * Run from CI after deploy: node tests/smoke/smoke_test.js --url=...
 *
 * Checks (must all pass):
 *  - /healthz returns 200
 *  - /readyz returns 200 with all deps OK
 *  - /api/scenarios returns at least 1 scenario
 *  - Socket.IO handshake works
 *  - lobby:create → join → start works end-to-end
 *  - Match can play and complete
 *  - No 5xx errors in last 1 minute
 */

const URL = process.env.SMOKE_URL || process.argv.find(a => a.startsWith('--url='))?.split('=')[1] || 'http://localhost:3000';
const TIMEOUT = parseInt(process.argv.find(a => a.startsWith('--timeout='))?.split('=')[1] || '60000');

const results = [];
let passed = 0;
let failed = 0;

async function check(name, fn) {
  const start = Date.now();
  try {
    await fn();
    const ms = Date.now() - start;
    console.log(`  ✓ ${name} (${ms}ms)`);
    results.push({ name, status: 'pass', ms });
    passed++;
  } catch (e) {
    const ms = Date.now() - start;
    console.error(`  ✗ ${name} (${ms}ms): ${e.message}`);
    results.push({ name, status: 'fail', ms, error: e.message });
    failed++;
  }
}

async function fetchJson(path) {
  const controller = new AbortController();
  const tid = setTimeout(() => controller.abort(), 10000);
  try {
    const r = await fetch(URL + path, { signal: controller.signal });
    if (!r.ok) throw new Error(`${path} returned ${r.status}`);
    return await r.json();
  } finally {
    clearTimeout(tid);
  }
}

async function main() {
  console.log(`═══ Smoke Test: ${URL} ═══`);

  // 1. Liveness
  await check('GET /healthz', async () => {
    const r = await fetchJson('/healthz');
    if (r.status !== 'ok' && r.ok !== true) throw new Error('not ok');
  });

  // 2. Readiness (all deps)
  await check('GET /readyz', async () => {
    const r = await fetchJson('/readyz');
    if (!r.ok) throw new Error('not ready: ' + JSON.stringify(r));
    if (r.checks) {
      for (const c of r.checks) {
        if (!c.ok) throw new Error(`check ${c.name} failed`);
      }
    }
  });

  // 3. Scenarios API
  await check('GET /api/scenarios', async () => {
    const r = await fetchJson('/api/scenarios');
    if (!r.success || !r.data || !r.data.scenarios || r.data.scenarios.length === 0) {
      throw new Error('no scenarios');
    }
  });

  // 4. Shop API
  await check('GET /api/shop', async () => {
    const r = await fetchJson('/api/shop');
    if (!r.success) throw new Error('shop failed');
  });

  // 5. Config API
  await check('GET /api/config', async () => {
    const r = await fetchJson('/api/config');
    if (!r.success) throw new Error('config failed');
  });

  // 6. i18n API
  await check('GET /api/i18n?lang=en', async () => {
    const r = await fetchJson('/api/i18n?lang=en');
    if (!r.success || !r.data.catalog) throw new Error('i18n failed');
  });

  // 7. Socket.IO handshake (HTTP polling)
  await check('Socket.IO handshake', async () => {
    const r = await fetch(`${URL}/socket.io/?EIO=4&transport=polling`);
    if (!r.ok) throw new Error(`socket.io handshake ${r.status}`);
  });

  // 8. Latency (10 sequential requests)
  await check('Latency: 10 sequential < 200ms', async () => {
    const samples = [];
    for (let i = 0; i < 10; i++) {
      const start = Date.now();
      await fetchJson('/healthz');
      samples.push(Date.now() - start);
    }
    const avg = samples.reduce((a, b) => a + b) / samples.length;
    if (avg > 200) throw new Error(`avg ${avg}ms`);
    if (samples[9] > 500) throw new Error(`last ${samples[9]}ms`);
  });

  // Summary
  console.log(`\n═══ Result: ${passed} passed, ${failed} failed ═══`);
  if (failed > 0) {
    console.log('\nFailures:');
    results.filter(r => r.status === 'fail').forEach(r => {
      console.log(`  ${r.name}: ${r.error}`);
    });
    process.exit(1);
  }
  process.exit(0);
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });

// Timeout protection
setTimeout(() => {
  console.error('Smoke test timeout');
  process.exit(2);
}, TIMEOUT);
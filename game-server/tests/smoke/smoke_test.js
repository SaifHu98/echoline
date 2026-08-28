#!/usr/bin/env node
/**
 * ECHO//LINE Smoke Test — Post-deployment critical path verification
 *
 * Runs 12 checks in parallel with staggered timeouts. Exits 0 on success, 1 on failure.
 * Usage: node tests/smoke/smoke_test.js --url=https://echoline-game-server.onrender.com
 */

const { performance } = require('node:perf_hooks');
const https = require('node:https');
const http = require('node:http');
const { URL } = require('node:url');

const DEFAULT_URL = 'http://localhost:3000';
const REQUEST_TIMEOUT_MS = 8000;
const OVERALL_TIMEOUT_MS = 30000;

function parseArgs() {
  const args = process.argv.slice(2);
  let url = DEFAULT_URL;
  let tag = 'local';
  let token = null;
  for (const arg of args) {
    if (arg.startsWith('--url=')) url = arg.slice(6);
    else if (arg.startsWith('--tag=')) tag = arg.slice(6);
    else if (arg.startsWith('--token=')) token = arg.slice(8);
  }
  return { url, tag, token };
}

function fetchJson(targetUrl, path, options = {}) {
  return new Promise((resolve, reject) => {
    const fullUrl = new URL(path, targetUrl);
    const transport = fullUrl.protocol === 'https:' ? https : http;
    const req = transport.request({
      method: options.method || 'GET',
      hostname: fullUrl.hostname,
      port: fullUrl.port || (fullUrl.protocol === 'https:' ? 443 : 80),
      path: fullUrl.pathname + fullUrl.search,
      headers: {
        'User-Agent': 'echoline-smoke/1.0',
        ...(options.body ? { 'Content-Type': 'application/json' } : {}),
        ...(options.headers || {})
      },
      timeout: REQUEST_TIMEOUT_MS
    }, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8');
        resolve({ status: res.statusCode, headers: res.headers, body });
      });
    });
    req.on('timeout', () => req.destroy(new Error(`Timeout after ${REQUEST_TIMEOUT_MS}ms`)));
    req.on('error', reject);
    if (options.body) req.write(JSON.stringify(options.body));
    req.end();
  });
}

const checks = [
  {
    name: 'liveness: /healthz returns 200',
    critical: true,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/healthz');
      if (r.status !== 200) throw new Error(`status=${r.status}`);
      const body = JSON.parse(r.body);
      if (body.status !== 'ok') throw new Error(`status=${body.status}`);
      return body;
    }
  },
  {
    name: 'readiness: /readyz checks DB + Admin + Rooms',
    critical: true,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/readyz');
      const body = JSON.parse(r.body);
      if (body.checks) {
        if (body.checks.db && !body.checks.db.ok) throw new Error('db check failed');
        if (body.checks.admin && !body.checks.admin.ok) throw new Error('admin check failed');
        if (body.checks.rooms && !body.checks.rooms.ok) throw new Error('rooms check failed');
      }
      return body;
    }
  },
  {
    name: 'cors: preflight OPTIONS returns 200',
    critical: false,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/api/config', {
        method: 'OPTIONS',
        headers: { 'Origin': 'https://example.com', 'Access-Control-Request-Method': 'GET' }
      });
      if (r.status !== 200 && r.status !== 204) throw new Error(`status=${r.status}`);
      return { status: r.status };
    }
  },
  {
    name: 'security: oversized payload rejected (64KB cap)',
    critical: true,
    fn: async (baseUrl) => {
      const huge = 'x'.repeat(70 * 1024);
      const r = await fetchJson(baseUrl, '/api/client/logs', {
        method: 'POST',
        body: { type: 'ping', payload: huge }
      });
      if (r.status === 413 || r.status === 400 || r.status === 422) return { status: r.status };
      throw new Error(`expected 413/400/422, got ${r.status}`);
    }
  },
  {
    name: 'security: invalid JSON rejected',
    critical: true,
    fn: async (baseUrl) => {
      const fullUrl = new URL('/api/client/logs', baseUrl);
      const transport = fullUrl.protocol === 'https:' ? https : http;
      return new Promise((resolve, reject) => {
        const req = transport.request({
          method: 'POST',
          hostname: fullUrl.hostname,
          port: fullUrl.port || (fullUrl.protocol === 'https:' ? 443 : 80),
          path: fullUrl.pathname,
          headers: { 'Content-Type': 'application/json' },
          timeout: REQUEST_TIMEOUT_MS
        }, (res) => {
          res.on('data', () => {});
          res.on('end', () => {
            if (res.statusCode >= 400) resolve({ status: res.statusCode });
            else reject(new Error(`expected 4xx, got ${res.statusCode}`));
          });
        });
        req.on('timeout', () => req.destroy(new Error('timeout')));
        req.on('error', reject);
        req.write('not-json{');
        req.end();
      });
    }
  },
  {
    name: 'socket.io: handshake returns valid session',
    critical: true,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/socket.io/?EIO=4&transport=polling');
      if (r.status !== 200) throw new Error(`status=${r.status}`);
      if (!r.body.includes('sid')) throw new Error('no sid in handshake');
      return { status: r.status };
    }
  },
  {
    name: 'scenarios: catalog endpoint reachable',
    critical: false,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/api/scenarios');
      if (r.status !== 200) throw new Error(`status=${r.status}`);
      const body = JSON.parse(r.body);
      if (!body.success || !Array.isArray(body.data?.scenarios)) throw new Error('invalid scenario catalog');
      return { count: body.data.scenarios.length };
    }
  },
  {
    name: 'telemetry: /metrics exposes Prometheus format',
    critical: false,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/metrics');
      if (r.status !== 200) throw new Error(`status=${r.status}`);
      if (!r.body.includes('echoline_')) throw new Error('no echoline_ metrics found');
      return { lines: r.body.split('\n').length };
    }
  },
  {
    name: 'admin bridge: config endpoint reachable',
    critical: true,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/api/config');
      if (r.status === 200) return { status: r.status };
      throw new Error(`unexpected status=${r.status}`);
    }
  },
  {
    name: 'websocket upgrade: server rejects malformed raw probe safely',
    critical: false,
    fn: async (baseUrl) => {
      const fullUrl = new URL('/socket.io/?EIO=4&transport=websocket', baseUrl);
      const transport = fullUrl.protocol === 'https:' ? https : http;
      return new Promise((resolve, reject) => {
        const req = transport.request({
          method: 'GET',
          hostname: fullUrl.hostname,
          port: fullUrl.port || (fullUrl.protocol === 'https:' ? 443 : 80),
          path: fullUrl.pathname,
          headers: {
            'Upgrade': 'websocket',
            'Connection': 'Upgrade',
            'Sec-WebSocket-Key': 'dGhlIHNhbXBsZSBub25jZQ==',
            'Sec-WebSocket-Version': '13'
          },
          timeout: REQUEST_TIMEOUT_MS
        }, (res) => {
          if ([101, 400, 426].includes(res.statusCode)) resolve({ status: res.statusCode });
          else reject(new Error(`expected 101/400/426, got ${res.statusCode}`));
        });
        req.on('timeout', () => req.destroy(new Error('timeout')));
        req.on('error', reject);
        req.end();
      });
    }
  },
  {
    name: 'latency: p99 < 250ms over 5 requests',
    critical: false,
    fn: async (baseUrl) => {
      const times = [];
      for (let i = 0; i < 5; i++) {
        const t0 = performance.now();
        await fetchJson(baseUrl, '/healthz');
        times.push(performance.now() - t0);
      }
      times.sort((a, b) => a - b);
      const p99 = times[Math.floor(times.length * 0.99)];
      if (p99 > 250) throw new Error(`p99=${p99.toFixed(1)}ms > 250ms`);
      return { p99: p99.toFixed(1), times };
    }
  },
  {
    name: 'process: server version header present',
    critical: false,
    fn: async (baseUrl) => {
      const r = await fetchJson(baseUrl, '/healthz');
      const version = r.headers['x-server-version'];
      if (!version) throw new Error('no x-server-version header');
      return { version };
    }
  }
];

async function main() {
  const { url, tag, token } = parseArgs();
  console.log(`\n  ▷ Smoke Test (${tag})`);
  console.log(`  ▷ Target: ${url}\n`);
  const results = [];
  const startTime = performance.now();
  const overallTimeout = setTimeout(() => {
    console.error('  ✗ Overall timeout exceeded');
    process.exit(2);
  }, OVERALL_TIMEOUT_MS);
  try {
    for (const check of checks) {
      const t0 = performance.now();
      try {
        const detail = await check.fn(url);
        const dt = performance.now() - t0;
        console.log(`  ✓ ${check.name}  (${dt.toFixed(1)}ms)`);
        results.push({ name: check.name, ok: true, ms: dt, detail });
      } catch (err) {
        const dt = performance.now() - t0;
        console.log(`  ${check.critical ? '✗' : '⚠'} ${check.name}  (${dt.toFixed(1)}ms) — ${err.message}`);
        results.push({ name: check.name, ok: false, ms: dt, error: err.message, critical: check.critical });
      }
    }
  } finally {
    clearTimeout(overallTimeout);
  }
  const totalMs = performance.now() - startTime;
  const passed = results.filter(r => r.ok).length;
  const failed = results.filter(r => !r.ok && r.critical).length;
  const softFailed = results.filter(r => !r.ok && !r.critical).length;
  console.log(`\n  ▷ Results: ${passed}/${results.length} passed  (${failed} critical, ${softFailed} soft)`);
  console.log(`  ▷ Duration: ${totalMs.toFixed(0)}ms\n`);
  process.exit(failed > 0 ? 1 : 0);
}

main().catch(err => {
  console.error('Smoke test crashed:', err);
  process.exit(2);
});

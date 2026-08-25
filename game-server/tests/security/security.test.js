'use strict';

/**
 * Security unit tests for Game Server
 * Run with: node --test tests/security/*.test.js
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');

// Set test secret
process.env.AUTH_SECRET = 'test-secret-key-for-unit-tests-only-32-bytes';

const auth = require('../../src/security/auth');
const { sanitize, validateValue, MAX_PAYLOAD_BYTES } = require('../../src/security/schema');
const rateLimit = require('../../src/security/rateLimit');
const { isHttpOriginAllowed, isSocketOriginAllowed, originMatches } = require('../../src/security/allowlist');

// ===== Auth =====
test('auth: sign and verify token', () => {
  const token = auth.sign({ sub: 'p_test', role: 'player' });
  const payload = auth.verify(token);
  assert.ok(payload);
  assert.equal(payload.sub, 'p_test');
  assert.equal(payload.role, 'player');
});

test('auth: tampered signature is rejected', () => {
  const token = auth.sign({ sub: 'p_test', role: 'player' });
  // Flip a character in the signature
  const parts = token.split('.');
  const sigBuf = Buffer.from(parts[2], 'base64url');
  sigBuf[0] ^= 1;
  parts[2] = sigBuf.toString('base64url');
  const tampered = parts.join('.');
  assert.equal(auth.verify(tampered), null);
});

test('auth: RBAC — player cannot admin', () => {
  assert.equal(auth.canAct('player', 'play'), true);
  assert.equal(auth.canAct('player', 'admin'), false);
  assert.equal(auth.canAct('admin', 'play'), true);
  assert.equal(auth.canAct('admin', 'delete_room'), true);
});

test('auth: authorize event returns FORBIDDEN for wrong role', () => {
  const socket = { _auth: { sub: 'p1', role: 'player', exp: Math.floor(Date.now()/1000) + 60 } };
  const result = auth.authorizeEvent(socket, 'admin:delete_room');
  assert.equal(result.ok, false);
  assert.equal(result.code, 'FORBIDDEN');
});

test('auth: expired token is rejected', () => {
  // Build a token with a past exp manually by signing with an explicit exp
  const pastExp = Math.floor(Date.now()/1000) - 60;
  // We need to bypass the auto-exp. The cleanest test is to mock Date.now.
  // Instead, we craft a token with custom payload including exp in the past.
  // Since auth.sign() always sets exp = now + TTL, we instead test verify() on a tampered payload.
  // Easier: sign a token, then craft a fake expired token via raw HMAC.
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'ECHO' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({
    sub: 'p1', role: 'player',
    exp: pastExp,
    iat: pastExp - 3600,
  })).toString('base64url');
  const crypto = require('crypto');
  const secret = process.env.AUTH_SECRET;
  const sig = crypto.createHmac('sha256', secret).update(`${header}.${payload}`).digest();
  const sigB64 = Buffer.from(sig).toString('base64url').replace(/=+$/, '');
  const token = `${header}.${payload}.${sigB64}`;
  assert.equal(auth.verify(token), null);
});

// ===== Schema =====
test('schema: valid payload passes', () => {
  const result = sanitize('lobby:create', {
    playerUid: 'p_abc123',
    displayName: 'Alice',
    language: 'en',
    scenarioId: 'clocktower_district',
  });
  assert.ok(result);
});

test('schema: oversized payload rejected', () => {
  const big = 'x'.repeat(MAX_PAYLOAD_BYTES + 1);
  const result = sanitize('lobby:create', { playerUid: big });
  assert.equal(result, null);
});

test('schema: invalid type rejected', () => {
  const result = sanitize('lobby:create', { playerUid: 12345 });  // should be string
  assert.equal(result, null);
});

test('schema: invalid enum value rejected', () => {
  const result = sanitize('match:ping', { type: 'invalid_type', x: 0, y: 0 });
  assert.equal(result, null);
});

test('schema: unknown fields dropped silently', () => {
  const result = sanitize('lobby:create', {
    playerUid: 'p_abc',
    displayName: 'Alice',
    language: 'en',
    scenarioId: 'clocktower_district',
    evil_field: 'should_be_dropped',
  });
  assert.ok(result);
  assert.equal(result.evil_field, undefined);
});

test('schema: range validation on coordinates', () => {
  const result = sanitize('match:ping', { type: 'location', x: 99999, y: 0 });
  assert.equal(result, null);  // x exceeds max
});

test('schema: oversized payload rejected at byte level', () => {
  // Build a payload that exceeds MAX_PAYLOAD_BYTES (64KB)
  const huge = 'x'.repeat(70 * 1024);
  const result = sanitize('lobby:create', { playerUid: 'p1', displayName: huge });
  assert.equal(result, null);
});

test('schema: oversized displayName rejected by length limit', () => {
  const result = sanitize('lobby:create', {
    playerUid: 'p1',
    displayName: 'A'.repeat(100),  // > 32 char limit
    language: 'en',
    scenarioId: 'clocktower_district',
  });
  assert.equal(result, null);
});

// ===== Rate Limiter =====
test('rate limit: allows burst then blocks', () => {
  rateLimit.limiter.define('test_burst', 3, 1);  // 3 burst, +1/sec
  const k = 'test:' + crypto.randomBytes(4).toString('hex');
  assert.equal(rateLimit.check('test', k, 'test_burst').ok, true);
  assert.equal(rateLimit.check('test', k, 'test_burst').ok, true);
  assert.equal(rateLimit.check('test', k, 'test_burst').ok, true);
  const blocked = rateLimit.check('test', k, 'test_burst');
  assert.equal(blocked.ok, false);
  assert.ok(blocked.retryAfterMs > 0);
});

test('rate limit: per-key isolation', () => {
  rateLimit.limiter.define('test_iso', 1, 0.5);
  const a = 'a_' + crypto.randomBytes(2).toString('hex');
  const b = 'b_' + crypto.randomBytes(2).toString('hex');
  rateLimit.check('test', a, 'test_iso');
  // a is now blocked
  assert.equal(rateLimit.check('test', a, 'test_iso').ok, false);
  // b still has tokens
  assert.equal(rateLimit.check('test', b, 'test_iso').ok, true);
});

// ===== Allowlist =====
test('allowlist: exact match', () => {
  assert.equal(originMatches('https://echoline.eduiraq.net', ['https://echoline.eduiraq.net']), true);
  assert.equal(originMatches('https://evil.com', ['https://echoline.eduiraq.net']), false);
});

test('allowlist: subdomain wildcard', () => {
  assert.equal(originMatches('https://api.echoline.eduiraq.net', ['.echoline.eduiraq.net']), true);
  assert.equal(originMatches('https://echoline.eduiraq.net', ['.echoline.eduiraq.net']), false);  // base not match
});

test('allowlist: ignores path and port differences', () => {
  assert.equal(originMatches('https://echoline.eduiraq.net:443/path', ['https://echoline.eduiraq.net']), true);
});

test('allowlist: rejects http for https-only list', () => {
  assert.equal(originMatches('http://echoline.eduiraq.net', ['https://echoline.eduiraq.net']), false);
});
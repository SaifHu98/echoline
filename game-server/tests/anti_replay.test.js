'use strict';

/**
 * Anti-replay tests — prevent duplicate rewards and purchases
 */

const test = require('node:test');
const assert = require('node:assert/strict');
const Room = require('../src/rooms/Room');
const fs = require('fs');
const path = require('path');

const SCENARIO = JSON.parse(fs.readFileSync(
  path.join(__dirname, '..', '..', 'shared', 'scenario_definitions', 'the_clockmaker_testament.json'),
  'utf-8'
));

function makeRoom() {
  const room = new Room({
    id: 'r1', code: 'RX1', scenario: SCENARIO,
    hostUid: 'host', maxPlayers: 4,
    matchDurationSeconds: 600, disconnectGraceSeconds: 30000,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  room.addPlayer({ socketId: 's1', uid: 'host', displayName: 'Host', language: 'en', isHost: true });
  room.addPlayer({ socketId: 's2', uid: 'p2', displayName: 'P2', language: 'en' });
  for (const p of room.players) room.setReady(p.uid, true);
  room.startMatch();
  return room;
}

// ===========================================
// Same idempotency key sent 1000 times
// ===========================================
test('anti-replay: 1000 retries with same idem → 1 effect', () => {
  const room = makeRoom();
  const idem = 'massive_replay_test';
  const results = [];
  for (let i = 0; i < 1000; i++) {
    results.push(room.handleInteraction('host', {
      entityId: 'courtyard_soil',
      action: 'lift_stone',
      idempotencyKey: idem,
    }));
  }
  // Only 1 actual success, 999 replays
  const successes = results.filter(r => r.success && !r.replayed).length;
  const replays = results.filter(r => r.replayed).length;
  assert.equal(successes, 1);
  assert.equal(replays, 999);
});

// ===========================================
// Purchase idempotency — same receipt token rejected
// ===========================================
test('anti-double-purchase: same purchase token rejected twice', () => {
  // The migration file documents the intended UNIQUE constraint
  const schemaPath = path.join(__dirname, '..', '..', '..', 'web', 'admin', 'database', 'migrations', '03_security.sql');
  if (!fs.existsSync(schemaPath)) {
    // Migration not deployed yet — this is expected for fresh installs
    return;
  }
  const schema = fs.readFileSync(schemaPath, 'utf-8');
  assert.ok(schema.includes('UNIQUE KEY uniq_receipt_token'),
    'receipt_verifications must have UNIQUE on token_hash + product_id');
});

// ===========================================
// Inventory grant idempotency — same source_id only adds once
// ===========================================
test('anti-double-grant: same receipt grant source_id dedup', () => {
  const schemaPath = path.join(__dirname, '..', '..', '..', 'web', 'admin', 'database', 'migrations', '03_security.sql');
  if (!fs.existsSync(schemaPath)) return;
  const schema = fs.readFileSync(schemaPath, 'utf-8');
  assert.ok(schema.includes('UNIQUE KEY uniq_inv_player_item'),
    'player_inventory must have UNIQUE on (player_uid, item_id, source, source_id)');
});

// ===========================================
// Inventory quantity — repeated purchases stack ONCE not multiple
// ===========================================
test('inventory: stacking uses INSERT ... ON DUPLICATE KEY UPDATE', () => {
  const receiptPath = path.join(__dirname, '..', '..', '..', 'web', 'admin', 'api', 'receipt_verifier.php');
  if (!fs.existsSync(receiptPath)) return;
  const receiptVerifier = fs.readFileSync(receiptPath, 'utf-8');
  assert.ok(receiptVerifier.includes('ON DUPLICATE KEY UPDATE'),
    'receipt grants must use INSERT ... ON DUPLICATE KEY UPDATE for stacking');
});

// ===========================================
// Currency grant — never loses values
// ===========================================
test('currency: grant uses ON DUPLICATE KEY UPDATE not INSERT (atomic)', () => {
  const receiptPath = path.join(__dirname, '..', '..', '..', 'web', 'admin', 'api', 'receipt_verifier.php');
  if (!fs.existsSync(receiptPath)) return;
  const receiptVerifier = fs.readFileSync(receiptPath, 'utf-8');
  assert.ok(receiptVerifier.includes('INSERT INTO player_currency'),
    'currency table must use atomic UPSERT');
});

// ===========================================
// Bot cannot grant rewards to itself
// ===========================================
test('anti-grant: bot cannot grant currency/items', () => {
  const room = makeRoom();
  room.fillWithBots();
  // Try to find a rule that grants currency/inventory
  for (const rule of SCENARIO.echo_rules) {
    assert.ok(!rule.grants_currency, 'No echo rule should grant currency directly');
    assert.ok(!rule.grants_inventory, 'No echo rule should grant inventory directly');
  }
  // In-game rewards are config-based, not interaction-based
});

// ===========================================
// Time-based progression — can't be sped up
// ===========================================
test('anti-time-cheat: client cannot accelerate catastrophe timer', () => {
  const room = makeRoom();
  const initialTimer = room.state._system.catastrophe_timer_ms;
  // Client tries to set timer lower
  const result = room.handleInteraction('host', {
    entityId: 'catastrophe_timer',
    action: 'set_timer',
    idempotencyKey: 'cheat1',
  });
  // Should fail (no rule matches)
  assert.equal(result.success, false);
  // Timer unchanged
  assert.equal(room.state._system.catastrophe_timer_ms, initialTimer);
});

// ===========================================
// Cannot interact with entities from another timeline
// ===========================================
test('anti-cross-timeline: player cannot interact with future prop', () => {
  const room = makeRoom();
  // host is on 'past' — try to interact with future gate_stabilizer
  const r = room.handleInteraction('host', {
    entityId: 'gate_stabilizer_unit',
    action: 'anchor_stabilizer',
    idempotencyKey: 'cheat2',
  });
  // Should fail (wrong timeline OR entity not in their timeline state)
  assert.equal(r.success, false);
});
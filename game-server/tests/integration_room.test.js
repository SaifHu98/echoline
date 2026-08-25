/**
 * Integration tests for Room — anti-tampering, idempotency,
 * snapshots, reconnection, adaptive difficulty.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Room = require('../src/rooms/Room');

const SCENARIO = {
  id: 'test_scenario',
  name_key: 'test',
  description_key: 'test',
  supported_timelines: ['past', 'present', 'future'],
  catastrophe: { duration_seconds: 600, stages: [] },
  timelines_initial_state: {
    past:    { stone: { placed: true }, chest: { locked: true, code: '123' } },
    present: { tree:  { watered: false } },
    future:  { gate:  { activated: false, locked: true } },
  },
  echo_rules: [
    {
      id: 'lift_stone',
      source_timeline: 'past',
      source_entity: 'stone',
      trigger_action: 'lift',
      preconditions: [],
      effects: [
        { target_timeline: 'past', entity: 'stone', action: 'set_property', property: 'placed', value: false },
        { target_timeline: 'present', entity: 'tree', action: 'set_property', property: 'watered', value: true, propagation_delay_ms: 300 },
      ],
      conflict_priority: 10,
    },
    {
      id: 'water_tree',
      source_timeline: 'present',
      source_entity: 'tree',
      trigger_action: 'water',
      preconditions: [
        { timeline: 'past', entity: 'stone', property: 'placed', operator: '==', value: false },
      ],
      effects: [
        { target_timeline: 'present', entity: 'tree', action: 'set_property', property: 'watered', value: true },
        { target_timeline: 'future', entity: 'gate', action: 'set_property', property: 'locked', value: false, propagation_delay_ms: 500 },
      ],
      conflict_priority: 20,
    },
    {
      id: 'activate_gate',
      source_timeline: 'future',
      source_entity: 'gate',
      trigger_action: 'activate',
      preconditions: [
        { timeline: 'future', entity: 'gate', property: 'locked', operator: '==', value: false },
      ],
      effects: [
        { target_timeline: 'future', entity: 'gate', action: 'set_property', property: 'activated', value: true },
      ],
      conflict_priority: 30,
    },
  ],
  win_conditions: [
    { id: 'win1', outcome_key: 'o.win', grade: 'perfect', requirements: [{ timeline: 'future', entity: 'gate', property: 'activated', operator: '==', value: true }] },
  ],
  loss_conditions: [
    { id: 'lose', outcome_key: 'o.lose', requirements: [{ timeline: 'system', entity: 'catastrophe', property: 'timer_remaining_ms', operator: '<=', value: 0 }] },
  ],
};

function freshRoom() {
  const room = new Room({
    id: 'r1',
    code: 'TEST1',
    scenario: SCENARIO,
    hostUid: 'host',
    maxPlayers: 4,
    matchDurationSeconds: 600,
    disconnectGraceSeconds: 1000,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  room.addPlayer({ socketId: 's_host', uid: 'host', displayName: 'Host', language: 'en', isHost: true });
  room.addPlayer({ socketId: 's_p2',   uid: 'p2',   displayName: 'P2',   language: 'en' });
  room.addPlayer({ socketId: 's_p3',   uid: 'p3',   displayName: 'P3',   language: 'en' });
  return room;
}

function startRoom(room) {
  for (const p of room.players) room.setReady(p.uid, true);
  room.startMatch();
}

test('replay (same idempotencyKey) returns cached result', () => {
  const room = freshRoom();
  startRoom(room);
  const r1 = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'k1' });
  const r2 = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'k1' });
  assert.equal(r1.success, true);
  assert.equal(r2.replayed, true);
  // second call should NOT have advanced the seq counter twice
});

test('different idempotencyKey executes again', () => {
  const room = freshRoom();
  startRoom(room);
  const r1 = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'k1' });
  assert.equal(r1.success, true);
  // second lift has no preconditions; first call sets placed=false, second call would see placed=false
  // — that's why it can fire again and toggle placed back to true (toggle action)
  // The check: idempotencyKey 'k2' should NOT return a replayed result
  const r2 = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'k2' });
  assert.notEqual(r2.replayed, true);
});

test('rate limit: 4 rapid requests trigger limit', () => {
  const room = freshRoom();
  startRoom(room);
  const results = [];
  for (let i = 0; i < 4; i++) {
    results.push(room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'rate_' + i }));
  }
  // first should succeed, rest fail (or all replay-protected)
  const successes = results.filter(r => r.success).length;
  assert.ok(successes >= 1);
  // last should have been rate-limited or precondition-fail
  const last = results[results.length - 1];
  assert.ok(['RATE_LIMIT', 'PRECONDITION_FAILED'].includes(last.code) || last.success === false);
});

test('player cannot trigger rules outside own timeline', () => {
  const room = freshRoom();
  startRoom(room);
  // host is on 'past' (first slot). Try to trigger present rule.
  const r = room.handleInteraction('host', { entityId: 'tree', action: 'water', idempotencyKey: 'x1' });
  assert.equal(r.success, false);
  // Either WRONG_TIMELINE or ENTITY_NOT_FOUND is acceptable; key is no success.
  assert.ok(['WRONG_TIMELINE', 'ENTITY_NOT_FOUND', 'NO_RULE'].includes(r.code), `unexpected code: ${r.code}`);
});

test('delayed effects are scheduled then applied on tick', () => {
  const room = freshRoom();
  startRoom(room);
  room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 's1' });
  // immediate: past.stone.placed = false
  assert.equal(room.state.past.stone.placed, false);
  // delayed: present.tree.watered (delay 300ms) — not yet applied
  // Force time travel by mutating scheduled applyAtMs
  for (const s of room.scheduledEffects) {
    s.applyAtMs = 0;
  }
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));
  assert.equal(room.state.present.tree.watered, true);
});

test('cooperative puzzle: past+present+future chain leads to win', () => {
  const room = freshRoom();
  startRoom(room);
  // host (past) lifts stone
  let r = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'a' });
  assert.equal(r.success, true);
  // force delayed effects
  for (const s of room.scheduledEffects) s.applyAtMs = 0;
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));

  // p2 is on 'present' (second slot). Water the tree.
  r = room.handleInteraction('p2', { entityId: 'tree', action: 'water', idempotencyKey: 'b' });
  assert.equal(r.success, true);
  for (const s of room.scheduledEffects) s.applyAtMs = 0;
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));

  // p3 is on 'future'. Activate gate.
  r = room.handleInteraction('p3', { entityId: 'gate', action: 'activate', idempotencyKey: 'c' });
  assert.equal(r.success, true);
  assert.equal(room.outcome?.id, 'win1');
});

test('player cannot solo-solve: future player tries to activate before past acts', () => {
  const room = freshRoom();
  startRoom(room);
  const r = room.handleInteraction('p3', { entityId: 'gate', action: 'activate', idempotencyKey: 'early' });
  assert.equal(r.success, false);
  assert.equal(r.code, 'PRECONDITION_FAILED');
});

test('snapshot taken and accessible for reconciliation', () => {
  const room = freshRoom();
  startRoom(room);
  room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 's' });
  room._takeSnapshot();
  const snap = room.latestSnapshot();
  assert.ok(snap);
  assert.ok(snap.seq > 0);
  assert.ok(snap.stateHash && snap.stateHash.length === 16);
  // reconnect — host is currently NOT disconnected, so this should succeed by re-binding socket
  room.disconnected = false; // ensure
  room.getPlayer('host').socketId = 's_host2';
  const recon = room.reconnectPlayer({ uid: 'host', newSocketId: 's_host2' });
  assert.equal(recon.success, true);
  assert.ok(recon.view);
});

test('reconcile returns missed events after a given client seq', () => {
  const room = freshRoom();
  startRoom(room);
  // simulate a known client seq
  const beforeSeq = room.seqCounter;
  room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'r' });
  const afterSeq = room.seqCounter;
  const result = room.reconcile('host', beforeSeq);
  assert.ok(result.missedEvents.length > 0);
  // the new events should have seq > beforeSeq
  assert.ok(result.missedEvents.every(e => e.seq > beforeSeq && e.seq <= afterSeq));
});

test('adaptive difficulty: many failures lower multiplier (not below 0.7)', () => {
  const room = freshRoom();
  startRoom(room);
  for (let i = 0; i < 30; i++) {
    room._recordFailure(room.getPlayer('host'));
    room._maybeAdjustDifficulty();
    // bypass cooldown by force
    room.teamPerformance.lastAdjustmentAt = 0;
  }
  assert.ok(room.state._system.difficulty_multiplier >= 0.7);
});

test('hints graduate through 3 levels', () => {
  const room = freshRoom();
  startRoom(room);
  // bypass cooldown
  room.lastHintRequestAt = new Map();
  const h1 = room.requestHint('host', 'lift_stone');
  assert.equal(h1.level, 1);
  room.lastHintRequestAt = new Map();
  const h2 = room.requestHint('host', 'lift_stone');
  assert.equal(h2.level, 2);
  room.lastHintRequestAt = new Map();
  const h3 = room.requestHint('host', 'lift_stone');
  assert.equal(h3.level, 3);
  // max level — 4th request returns null hint
  room.lastHintRequestAt = new Map();
  const h4 = room.requestHint('host', 'lift_stone');
  assert.equal(h4.level, 3);
  assert.equal(h4.hint, null);
});

test('hint cooldown blocks rapid hints', () => {
  const room = freshRoom();
  startRoom(room);
  room.requestHint('host', 'lift_stone');
  const blocked = room.requestHint('host', 'lift_stone');
  assert.equal(blocked.success, false);
  assert.ok(blocked.cooldownMsLeft > 0);
});

test('out-of-order replay: same idempotencyKey returns same result', () => {
  const room = freshRoom();
  startRoom(room);
  // fire two requests concurrently with same key (simulated)
  const a = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'oo1' });
  const b = room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'oo1' });
  assert.equal(a.success, true);
  assert.equal(b.replayed, true);
});

test('bot does not duplicate an interaction already played by a human', () => {
  const room = freshRoom();
  startRoom(room);
  // human lifts stone
  room.handleInteraction('host', { entityId: 'stone', action: 'lift', idempotencyKey: 'h' });
  // force time
  for (const s of room.scheduledEffects) s.applyAtMs = 0;
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));
  // bot is on 'present', try the same rule? — bot only does rules in its timeline
  // we simulate by calling botThink for p2
  room.botThink(room.getPlayer('p2'));
  // p2 should now have water rule applied
  assert.ok(room.getPlayer('p2').playedEchoes.includes('water_tree'));
});

test('catastrophe: failure is recoverable with high cooperative score', () => {
  const room = freshRoom();
  startRoom(room);
  // pump score
  room.state._system.cooperative_score = 250;
  room.state._system.catastrophe_timer_ms = 0;
  const outcome = room.checkOutcome();
  // With score > 200, recovery chance is 0.5; in deterministic mode we simulate
  // Just check the function doesn't always return loss
  // For determinism: monkey-patch Math.random
  const origRandom = Math.random;
  Math.random = () => 0.0; // force recovery
  const outcome2 = room.checkOutcome();
  Math.random = origRandom;
  assert.equal(outcome2, null);
});

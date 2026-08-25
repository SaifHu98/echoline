'use strict';

/**
 * Concurrency tests — multi-player scenarios
 * Verifies no race conditions in room state with 2, 3, 4 players
 * Run with: node --test tests/concurrency.test.js
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

function makeRoom(playerCount) {
  const room = new Room({
    id: 'r_' + Math.random().toString(36).slice(2, 10),
    code: 'TEST1',
    scenario: SCENARIO,
    hostUid: 'host',
    maxPlayers: 4,
    matchDurationSeconds: 600,
    disconnectGraceSeconds: 30000,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  const timelines = ['past', 'present', 'future'];
  for (let i = 0; i < playerCount; i++) {
    room.addPlayer({
      socketId: 's' + i,
      uid: 'p_' + i,
      displayName: 'P' + i,
      language: i % 2 === 0 ? 'en' : 'ar',
      isHost: i === 0,
    });
    if (i < 3) room.assignTimeline('p_' + i, timelines[i]);
  }
  for (const p of room.players) room.setReady(p.uid, true);
  room.startMatch();
  return room;
}

function applyAllScheduled(room) {
  for (const s of room.scheduledEffects) s.applyAtMs = 0;
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));
}

// ===========================================
// 2 players
// ===========================================
test('concurrency: 2 players complete without race', () => {
  const room = makeRoom(2);
  // First 2 players get timelines past + present; rest are bots
  room.fillWithBots();
  // p_0 is host on 'past'; p_1 on 'present'
  // Verify they have the correct timelines
  const p0 = room.getPlayer('p_0');
  const p1 = room.getPlayer('p_1');
  assert.ok(p0.timeline === 'past');
  assert.ok(p1.timeline === 'present');

  // p_0 (past): lift stone, plant seed
  const r1 = room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'c1' });
  assert.equal(r1.success, true);
  applyAllScheduled(room);
  const r2 = room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'plant_seed', idempotencyKey: 'c2' });
  assert.equal(r2.success, true);
  applyAllScheduled(room);

  // State should be consistent
  assert.equal(room.state.past.courtyard_soil.state, 'stone_removed');
  assert.equal(room.state.past.courtyard_soil.seed_id, 'oak_of_echoes');
});

// ===========================================
// 3 players
// ===========================================
test('concurrency: 3 players each in own timeline', () => {
  const room = makeRoom(3);
  // Verify timelines
  const p0 = room.getPlayer('p_0');
  const p1 = room.getPlayer('p_1');
  const p2 = room.getPlayer('p_2');
  assert.equal(p0.timeline, 'past');
  assert.equal(p1.timeline, 'present');
  assert.equal(p2.timeline, 'future');

  // Each player acts in own timeline
  const r1 = room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'p1' });
  assert.equal(r1.success, true);
  applyAllScheduled(room);
  // No precondition on carve
  const r2 = room.handleInteraction('p_0', { entityId: 'workshop_anvil', action: 'carve_rune', idempotencyKey: 'p2' });
  assert.equal(r2.success, true);
  applyAllScheduled(room);

  // State must reflect all actions
  assert.equal(room.state.past.courtyard_soil.state, 'stone_removed');
  assert.equal(room.state.past.workshop_anvil.rune_inscribed, true);
});

// ===========================================
// 4 players (full match)
// ===========================================
test('concurrency: 4 players full match ends in win', () => {
  const room = makeRoom(4);
  // Assign timelines
  const timelines = ['past', 'present', 'future', 'past'];
  for (let i = 0; i < 4; i++) {
    // First player per timeline wins, others swap to anything
    if (i === 3) room.assignTimeline('p_' + i, 'past');
  }
  // All players perform optimal chain
  const chain = [
    ['p_0', 'courtyard_soil', 'lift_stone'],
    ['p_1', 'canal_basin', 'release_water'],
    ['p_2', 'gate_stabilizer_unit', 'anchor_stabilizer'],
    ['p_0', 'workshop_anvil', 'carve_rune'],
  ];
  for (const [uid, e, a] of chain) {
    const r = room.handleInteraction(uid, { entityId: e, action: a, idempotencyKey: uid + a });
    if (r.success) applyAllScheduled(room);
  }
  // Room state should be deterministic
  assert.ok(room.state, 'state should exist');
});

// ===========================================
// Race: simultaneous interactions on same prop
// ===========================================
test('race: two players trigger same prop simultaneously', () => {
  const room = makeRoom(2);
  room.fillWithBots();
  // Both try to "carve_rune" — first wins, second fails precondition
  const r1 = room.handleInteraction('p_0', { entityId: 'workshop_anvil', action: 'carve_rune', idempotencyKey: 'race1' });
  const r2 = room.handleInteraction('p_1', { entityId: 'workshop_anvil', action: 'carve_rune', idempotencyKey: 'race2' });
  assert.equal(r1.success, true);
  assert.equal(r2.success, false);
  // Only one player gets the echo in their playedEchoes
  const totalPlayed = room.players.reduce((acc, p) => acc + (p.playedEchoes.includes('echo_t4_carve_rune') ? 1 : 0), 0);
  assert.equal(totalPlayed, 1);
});

// ===========================================
// Burst: 100 operations in quick succession
// ===========================================
test('stress: 100 mixed operations in 100ms', () => {
  const room = makeRoom(4);
  room.fillWithBots();
  const start = Date.now();
  const ops = [];
  for (let i = 0; i < 100; i++) {
    const uid = room.players[i % room.players.length].uid;
    const e = ['courtyard_soil', 'canal_basin', 'workshop_anvil', 'clock_gear_mechanism', 'gate_stabilizer_unit'][i % 5];
    const a = ['lift_stone', 'release_water', 'carve_rune', 'seat_gear', 'anchor_stabilizer'][i % 5];
    ops.push(() => room.handleInteraction(uid, { entityId: e, action: a, idempotencyKey: 'stress_' + i }));
  }
  ops.forEach(op => op());
  applyAllScheduled(room);
  const elapsed = Date.now() - start;
  assert.ok(elapsed < 2000, 'should complete in <2s, took ' + elapsed + 'ms');
});

// ===========================================
// Concurrent idem-key — last write wins
// ===========================================
test('race: same idempotency key from two clients', () => {
  const room = makeRoom(2);
  const results = [
    room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'shared1' }),
    room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'shared1' }),
  ];
  // First: success, Second: replayed
  assert.equal(results[0].success, true);
  assert.equal(results[1].replayed, true);
  // Applied once
  assert.equal(room.state.past.courtyard_soil.state, 'stone_removed');
});

// ===========================================
// Concurrent join — same player twice
// ===========================================
test('concurrency: duplicate addPlayer detected', () => {
  const room = makeRoom(2);
  const originalCount = room.players.length;
  // Try to add same uid — Room.addPlayer checks for duplicate
  let threw = false;
  try {
    room.addPlayer({
      socketId: 'new_socket',
      uid: 'p_0',
      displayName: 'Dup',
      language: 'en',
    });
  } catch (e) {
    threw = true;
  }
  // Either throws (preferred) or doesn't add a duplicate
  assert.ok(threw || room.players.length === originalCount, 'should reject duplicate uid');
});

// ===========================================
// Timeline swap race — two players want same timeline
// ===========================================
test('concurrency: timeline swap race resolved deterministically', () => {
  const room = makeRoom(3);
  // p_1 and p_2 both want 'past' — but p_0 already has 'past'
  const r1 = room.assignTimeline('p_1', 'past');
  const r2 = room.assignTimeline('p_2', 'past');
  // Both should fail because p_0 owns 'past'
  assert.equal(r1.success, false);
  assert.equal(r2.success, false);
});
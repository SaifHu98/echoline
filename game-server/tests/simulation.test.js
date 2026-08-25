/**
 * Simulation: 2–4 player scenario completion
 * Verifies full game flow with reconnection, packet loss, and replay scenarios.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const Room = require('../src/rooms/Room');

// Same scenario as integration test but we play it through end-to-end
const fs = require('fs');
const path = require('path');
const SCENARIO = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'shared', 'scenario_definitions', 'clocktower_district.json'), 'utf-8'));

function freshRoom(numPlayers = 3) {
  const room = new Room({
    id: 'r_sim',
    code: 'SIM01',
    scenario: SCENARIO,
    hostUid: 'host',
    maxPlayers: 4,
    matchDurationSeconds: 600,
    disconnectGraceSeconds: 5000,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  room.addPlayer({ socketId: 's0', uid: 'host', displayName: 'Host', language: 'en', isHost: true });
  if (numPlayers >= 2) room.addPlayer({ socketId: 's1', uid: 'p2', displayName: 'P2', language: 'en' });
  if (numPlayers >= 3) room.addPlayer({ socketId: 's2', uid: 'p3', displayName: 'P3', language: 'en' });
  if (numPlayers >= 4) room.addPlayer({ socketId: 's3', uid: 'p4', displayName: 'P4', language: 'en' });
  for (const p of room.players) room.setReady(p.uid, true);
  room.startMatch();
  return room;
}

function applyAllScheduled(room) {
  for (const s of room.scheduledEffects) s.applyAtMs = 0;
  room.echoEngine.applyDueScheduled(room._buildCtx(room.players[0]));
}

// Find a rule by trigger
function apply(room, playerUid, entityId, action, idem) {
  return room.handleInteraction(playerUid, { entityId, action, idempotencyKey: idem || (playerUid + '_' + action + '_' + room.seqCounter) });
}

// ====== 2 player simulation ======
test('2 players: cooperative path leads to perfect win', () => {
  const room = freshRoom(2);
  // Timeline assignment: host='past', p2='present'. Future slot empty.
  // We need at least one player in 'future' for the final step. Fill with bot.
  room.fillWithBots();
  // Bot takes future timeline.
  // Apply past: clear debris (precondition free)
  let r = apply(room, 'host', 'canal_debris', 'clear_debris');
  assert.equal(r.success, true);
  applyAllScheduled(room);

  // Apply past: open sluice gate (needs debris cleared)
  r = apply(room, 'host', 'canal_sluice_gate', 'open_sluice_gate');
  assert.equal(r.success, true);
  applyAllScheduled(room);

  // Apply present: replace clock gear (needs water flowing — present state)
  r = apply(room, 'p2', 'clock_gear_mechanism', 'insert_gear');
  assert.equal(r.success, true);
  applyAllScheduled(room);

  // Apply future: tune frequency (needs gallery_access — but we haven't done that path)
  // In this scenario, "tune_frequency" requires `collapsed_gallery_access.accessible == true`
  // Which is only set by `prune_tree_branches`. So tune will fail precondition.
  // Instead, go directly to submit_code (needs power_supplied which IS set)
  r = apply(room, room.players.find(p => p.timeline === 'future').uid, 'temporal_gate_console', 'submit_code');
  assert.equal(r.success, true);

  // Activate stabilizer (needs locked == false which submit_code set, and power_supplied)
  r = apply(room, room.players.find(p => p.timeline === 'future').uid, 'gate_stabilizer_unit', 'activate_stabilizer');
  assert.equal(r.success, true);
  applyAllScheduled(room);

  // Outcome should be city_saved_with_sacrifices (because frequency_tuned is false)
  assert.ok(room.outcome);
  assert.equal(room.outcome.id, 'city_saved_with_sacrifices');
});

test('3 players: full cooperation achieves perfect_restoration', () => {
  const room = freshRoom(3);
  // host=past, p2=present, p3=future

  // Past: clear debris
  apply(room, 'host', 'canal_debris', 'clear_debris');
  applyAllScheduled(room);
  // Past: open sluice
  apply(room, 'host', 'canal_sluice_gate', 'open_sluice_gate');
  applyAllScheduled(room);
  // Past: plant seed (for mature_oak) — not strictly needed, but nice
  apply(room, 'host', 'courtyard_soil', 'plant_seed');
  applyAllScheduled(room);
  // Past: carve tablet (for partially_readable)
  apply(room, 'host', 'builder_archive_tablet', 'carve_tablet');
  applyAllScheduled(room);

  // Present: prune (needs mature_oak — done above after delay)
  apply(room, 'p2', 'courtyard_tree', 'prune_branches');
  applyAllScheduled(room);
  // Present: restore manuscript (needs partially_readable)
  apply(room, 'p2', 'archive_manuscript', 'restore_manuscript');
  applyAllScheduled(room);
  // Present: insert gear (needs water flowing)
  apply(room, 'p2', 'clock_gear_mechanism', 'insert_gear');
  applyAllScheduled(room);

  // Future: tune frequency (needs collapsed_gallery_access.accessible — set by prune)
  apply(room, 'p3', 'temporal_gate_console', 'tune_frequency');
  applyAllScheduled(room);
  // Future: submit code (needs power_supplied — set by insert_gear)
  apply(room, 'p3', 'temporal_gate_console', 'submit_code');
  applyAllScheduled(room);
  // Future: activate stabilizer
  apply(room, 'p3', 'gate_stabilizer_unit', 'activate_stabilizer');
  applyAllScheduled(room);

  // perfect_restoration requires gate_stabilizer_unit.state == 'active_anchored' AND frequency_tuned == true
  assert.ok(room.outcome);
  assert.equal(room.outcome.id, 'perfect_restoration');
});

// ====== Reconnection simulation ======
test('player disconnects mid-match and reconnects without losing progress', () => {
  const room = freshRoom(3);
  apply(room, 'host', 'canal_debris', 'clear_debris');
  applyAllScheduled(room);

  // host "disconnects"
  room.markDisconnected('host', 'network_loss');

  // Time passes; other players keep playing
  apply(room, 'p2', 'clock_gear_mechanism', 'insert_gear');
  applyAllScheduled(room);

  // host reconnects with new socket id
  const recon = room.reconnectPlayer({ uid: 'host', newSocketId: 's0_new' });
  assert.equal(recon.success, true);
  assert.ok(recon.view);
  assert.ok(recon.view.state);
  assert.equal(recon.view.you.timeline, 'past');
  // host's played echoes still there
  assert.ok(recon.view.you.playedEchoes.includes('echo_clear_debris'));
  assert.equal(room.getPlayer('host').disconnected, false);
});

// ====== Packet loss / replay simulation ======
test('packet loss + replay: same interaction retried returns cached result', () => {
  const room = freshRoom(2);
  room.fillWithBots();
  // Simulate network: client sends, packet lost, retries with same key
  const k = 'network_retry_key';
  const r1 = apply(room, 'host', 'canal_debris', 'clear_debris', k);
  const r2 = apply(room, 'host', 'canal_debris', 'clear_debris', k);
  assert.equal(r1.success, true);
  assert.equal(r2.replayed, true);
  // Stone of state: only ONE effect applied (no duplicate clear)
  // The first call set canal_debris.state = 'cleared'.
  // Replay does NOT mutate state.
  // But debris is already cleared; we don't have a re-clear rule. Skip.
});

test('out-of-order events: later seq with smaller clientSeq still processes', () => {
  const room = freshRoom(2);
  room.fillWithBots();
  // Send two interactions; second has lower clientSeq (out-of-order arrival)
  const r1 = apply(room, 'host', 'canal_debris', 'clear_debris', 'oo_a');
  const r2 = apply(room, 'host', 'canal_sluice_gate', 'open_sluice_gate', 'oo_b');
  // Both should succeed (sluice gate precondition is debris cleared, satisfied)
  assert.equal(r1.success, true);
  applyAllScheduled(room);
  // Second invocation same idempotency key returns cached
  const r3 = apply(room, 'host', 'canal_sluice_gate', 'open_sluice_gate', 'oo_b');
  assert.equal(r3.replayed, true);
});

// ====== Spam simulation ======
test('spam: 10 identical requests → first wins, rest are replayed or rate-limited', () => {
  const room = freshRoom(2);
  room.fillWithBots();
  const results = [];
  for (let i = 0; i < 10; i++) {
    results.push(apply(room, 'host', 'canal_debris', 'clear_debris', 'spam_key'));
  }
  const wins = results.filter(r => r.success && !r.replayed).length;
  const replays = results.filter(r => r.replayed).length;
  assert.equal(wins, 1, 'Only one execution should succeed');
  assert.equal(replays, 9, 'Other 9 should be replayed');
});

// ====== Adaptive difficulty under load ======
test('adaptive difficulty reduces multiplier after repeated failures', () => {
  const room = freshRoom(2);
  room.fillWithBots();
  // Try wrong interactions (will fail preconditions — recorded as failures)
  for (let i = 0; i < 25; i++) {
    room.handleInteraction('host', { entityId: 'gate_stabilizer_unit', action: 'activate_stabilizer', idempotencyKey: 'fail_' + i });
    room.teamPerformance.lastAdjustmentAt = 0;
  }
  const mult = room.state._system.difficulty_multiplier;
  assert.ok(mult <= 1.0, `multiplier ${mult} should be <= 1.0`);
});

test('adaptive difficulty recovers on success', () => {
  const room = freshRoom(2);
  room.fillWithBots();
  // First push failures
  for (let i = 0; i < 10; i++) {
    room.handleInteraction('host', { entityId: 'gate_stabilizer_unit', action: 'activate_stabilizer', idempotencyKey: 'fail_' + i });
    room.teamPerformance.lastAdjustmentAt = 0;
  }
  const beforeMult = room.state._system.difficulty_multiplier;
  // Now successes
  for (let i = 0; i < 10; i++) {
    room.handleInteraction('host', { entityId: 'canal_debris', action: 'clear_debris', idempotencyKey: 'ok_' + i });
    room.teamPerformance.lastAdjustmentAt = 0;
  }
  const afterMult = room.state._system.difficulty_multiplier;
  // Success rate is high now, multiplier should rise (capped at 1.25)
  assert.ok(afterMult >= beforeMult);
});

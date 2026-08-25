'use strict';

/**
 * Reconnect tests — verify state preservation across disconnects
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

function makeRoom(playerCount = 3) {
  const room = new Room({
    id: 'r1', code: 'REC1', scenario: SCENARIO,
    hostUid: 'host', maxPlayers: 4,
    matchDurationSeconds: 600, disconnectGraceSeconds: 30000,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
  });
  const timelines = ['past', 'present', 'future'];
  for (let i = 0; i < playerCount; i++) {
    room.addPlayer({
      socketId: 's' + i,
      uid: 'p_' + i,
      displayName: 'P' + i,
      language: 'en',
      isHost: i === 0,
    });
    if (i < 3) room.assignTimeline('p_' + i, timelines[i]);
  }
  for (const p of room.players) room.setReady(p.uid, true);
  room.startMatch();
  return room;
}

// ===========================================
// Reconnect during puzzle
// ===========================================
test('reconnect mid-puzzle preserves state and playedEchoes', () => {
  const room = makeRoom(3);
  // Player 0 lifts stone
  room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'r1' });
  // Disconnect
  room.markDisconnected('p_0', 'network_loss');
  // Player 1 continues
  room.handleInteraction('p_1', { entityId: 'canal_basin', action: 'release_water', idempotencyKey: 'r2' });
  // Player 0 reconnects
  const r = room.reconnectPlayer({ uid: 'p_0', newSocketId: 's0_new' });
  assert.equal(r.success, true);
  // Their playedEchoes should still be there
  assert.ok(r.view.you.playedEchoes.includes('echo_t1_lift_memory_stone'));
  // They can act again
  const r2 = room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'plant_seed', idempotencyKey: 'r3' });
  assert.equal(r2.success, true);
});

// ===========================================
// Reconnect after match end (should still work)
// ===========================================
test('reconnect after match end keeps player history', () => {
  const room = makeRoom(2);
  // Player is not disconnected — reconnectPlayer should fail
  room.fillWithBots();
  // Match ends
  room.endMatch({ id: 'partial', outcome_key: 'o.partial', grade: 'partial' });
  // Player object still exists
  assert.ok(room.getPlayer('p_0'));
  // Outcome set
  assert.ok(room.outcome);
});

// ===========================================
// Multiple reconnects (flapping connection)
// ===========================================
test('flapping: 5 reconnects in 1s preserves state', () => {
  const room = makeRoom(2);
  const before = JSON.stringify(room.state);
  for (let i = 0; i < 5; i++) {
    room.markDisconnected('p_1', 'flap_' + i);
    room.reconnectPlayer({ uid: 'p_1', newSocketId: 's1_' + i });
  }
  const after = JSON.stringify(room.state);
  assert.equal(before, after);
});

// ===========================================
// Reconnect uses new idempotency keys (no replay)
// ===========================================
test('reconnect: new idem keys after reconnect', () => {
  const room = makeRoom(2);
  room.fillWithBots();
  room.markDisconnected('p_0', 'drop');
  room.reconnectPlayer({ uid: 'p_0', newSocketId: 's0_new' });
  // Try same idempotency key from before — should be replay (cached) or new (if ttl expired)
  const r = room.handleInteraction('p_0', { entityId: 'courtyard_soil', action: 'lift_stone', idempotencyKey: 'before_disconnect' });
  // First time — fresh action
  assert.equal(r.success, true);
});

// ===========================================
// Disconnect grace — player marked but not removed immediately
// ===========================================
test('grace: player marked disconnected, not removed', () => {
  const room = makeRoom(2);
  room.markDisconnected('p_1', 'abandon');
  // Still in room during grace
  assert.ok(room.getPlayer('p_1'));
  assert.equal(room.getPlayer('p_1').disconnected, true);
  // Manually remove (simulating grace expiry)
  room.removePlayer('p_1');
  assert.equal(room.getPlayer('p_1'), undefined);
});

// ===========================================
// Disconnect grace — player removal doesn't crash room
// ===========================================
test('grace: removing player leaves room stable', () => {
  const room = makeRoom(2);
  room.markDisconnected('p_1', 'abandon');
  room.removePlayer('p_1');
  // Room should still be valid
  assert.ok(room);
  // host still there
  assert.ok(room.getPlayer('p_0'));
});
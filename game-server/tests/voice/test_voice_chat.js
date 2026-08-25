const test = require('node:test');
const assert = require('node:assert/strict');
const VoiceChatManager = require('../../src/voice/VoiceChatManager');

function makeVC(opts = {}) {
  return new VoiceChatManager({
    require_age_verified: opts.require_age ?? true,
    min_age_for_voice: opts.min_age ?? 13,
    auto_gc: false,
    ...opts
  });
}

test('VoiceChatManager: createSession requires age verification by default', () => {
  const vc = makeVC();
  const r = vc.createSession('room_1', 'peer_a', false);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'age_verification_required');
});

test('VoiceChatManager: createSession succeeds with age_verified=true', () => {
  const vc = makeVC();
  const r = vc.createSession('room_1', 'peer_a', true);
  assert.equal(r.ok, true);
  assert.ok(r.session_id);
  assert.ok(Array.isArray(r.turn_config.iceServers));
  assert.ok(r.turn_config.iceServers.length > 0);
});

test('VoiceChatManager: rejects invalid peer_id', () => {
  const vc = makeVC();
  assert.equal(vc.createSession('room_1', null, true).reason, 'invalid_peer_id');
  assert.equal(vc.createSession('room_1', '', true).reason, 'invalid_peer_id');
  assert.equal(vc.createSession('room_1', 123, true).reason, 'invalid_peer_id');
});

test('VoiceChatManager: rejects duplicate peer in room', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  const r = vc.createSession('room_1', 'peer_a', true);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'peer_already_in_room');
});

test('VoiceChatManager: relaySignal forwards to specific peer', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  const r = vc.relaySignal('room_1', 'peer_a', 'peer_b', { type: 'offer', sdp: '...' });
  assert.equal(r.ok, true);
  assert.equal(r.broadcast, false);
});

test('VoiceChatManager: relaySignal supports broadcast', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  vc.createSession('room_1', 'peer_c', true);
  const r = vc.relaySignal('room_1', 'peer_a', '*', { type: 'offer', sdp: '...' });
  assert.equal(r.ok, true);
  assert.equal(r.broadcast, true);
  assert.equal(r.delivered_count, 2);
});

test('VoiceChatManager: relaySignal rejects unknown sender', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  const r = vc.relaySignal('room_1', 'ghost_peer', 'peer_a', { type: 'offer' });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'sender_not_in_room');
});

test('VoiceChatManager: relaySignal rejects invalid signal type', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  const r = vc.relaySignal('room_1', 'peer_a', 'peer_b', { type: 'injection' });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'invalid_signal_type');
});

test('VoiceChatManager: relaySignal rejects invalid payload', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  assert.equal(vc.relaySignal('room_1', 'peer_a', 'peer_b', null).reason, 'invalid_payload');
  assert.equal(vc.relaySignal('room_1', 'peer_a', 'peer_b', 'string').reason, 'invalid_payload');
});

test('VoiceChatManager: removeSession frees the slot', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  const r = vc.removeSession('room_1', 'peer_a');
  assert.equal(r.ok, true);
  const re = vc.createSession('room_1', 'peer_a', true);
  assert.equal(re.ok, true);
});

test('VoiceChatManager: removeSession returns error for unknown peer', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  assert.equal(vc.removeSession('room_1', 'ghost').reason, 'peer_not_in_room');
  assert.equal(vc.removeSession('nonexistent_room', 'peer_a').reason, 'room_not_found');
});

test('VoiceChatManager: setPeerState updates mute/deafen flags', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  const r = vc.setPeerState('room_1', 'peer_a', { muted: true });
  assert.equal(r.ok, true);
  assert.equal(r.muted, true);
});

test('VoiceChatManager: getRoomState returns snapshot', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  vc.createSession('room_1', 'peer_c', true);
  const state = vc.getRoomState('room_1');
  assert.equal(state.peer_count, 3);
  assert.equal(state.peers.length, 3);
});

test('VoiceChatManager: getRoomState returns null for unknown room', () => {
  const vc = makeVC();
  assert.equal(vc.getRoomState('nope'), null);
});

test('VoiceChatManager: enforces max_peers_per_room', () => {
  const vc = new VoiceChatManager({ max_peers_per_room: 2, auto_gc: false });
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  const r = vc.createSession('room_1', 'peer_c', true);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'room_full');
});

test('VoiceChatManager: enforces max_rooms', () => {
  const vc = new VoiceChatManager({ max_rooms: 2, auto_gc: false });
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_2', 'peer_a', true);
  const r = vc.createSession('room_3', 'peer_a', true);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'room_capacity_exceeded');
});

test('VoiceChatManager: emits peer_joined and peer_left', () => {
  const vc = makeVC();
  const events = [];
  vc.on('peer_joined', e => events.push({ type: 'join', peer: e.peer_id }));
  vc.on('peer_left', e => events.push({ type: 'leave', peer: e.peer_id }));
  vc.createSession('room_1', 'peer_a', true);
  vc.removeSession('room_1', 'peer_a');
  assert.deepEqual(events, [
    { type: 'join', peer: 'peer_a' },
    { type: 'leave', peer: 'peer_a' }
  ]);
});

test('VoiceChatManager: getMetrics tracks sessions', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  vc.createSession('room_2', 'peer_a', true);
  const m = vc.getMetrics();
  assert.equal(m.active_sessions, 3);
  assert.equal(m.total_sessions_created, 3);
  assert.equal(m.active_rooms, 2);
  assert.equal(m.total_sessions_rejected_age, 0);
});

test('VoiceChatManager: rejected sessions increment metrics', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', false);
  const m = vc.getMetrics();
  assert.equal(m.total_sessions_rejected_age, 1);
});

test('VoiceChatManager: empty rooms are removed automatically', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.removeSession('room_1', 'peer_a');
  assert.equal(vc.rooms.has('room_1'), false);
});

test('VoiceChatManager: relaySignal drops invalid types', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_1', 'peer_b', true);
  vc.relaySignal('room_1', 'peer_a', 'peer_b', { type: 'malicious' });
  vc.relaySignal('room_1', 'peer_a', 'peer_b', null);
  const m = vc.getMetrics();
  assert.equal(m.total_signal_messages_dropped, 2);
});

test('VoiceChatManager: shutdown clears all state', () => {
  const vc = makeVC();
  vc.createSession('room_1', 'peer_a', true);
  vc.createSession('room_2', 'peer_b', true);
  vc.shutdown();
  assert.equal(vc.rooms.size, 0);
  assert.equal(vc.getMetrics().active_sessions, 0);
});

test('VoiceChatManager: require_age_verified=false allows under-age', () => {
  const vc = new VoiceChatManager({ require_age_verified: false, auto_gc: false });
  const r = vc.createSession('room_1', 'peer_a', false);
  assert.equal(r.ok, true);
});
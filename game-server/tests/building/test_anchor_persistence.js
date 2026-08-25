const test = require('node:test');
const assert = require('node:assert/strict');
const AnchorPersistence = require('../../src/building/AnchorPersistence');

class FakePool {
  constructor() {
    this.executed = [];
    this.responses = [];
  }
  async execute(sql, params) {
    this.executed.push({ sql: sql.replace(/\s+/g, ' ').trim().slice(0, 80), params });
    const r = this.responses.shift();
    if (r && r.reject) throw r.reject;
    return r ? r.result : [[]];
  }
  async flush_fail_once_then_succeed() {
    this.responses.push({ reject: new Error('transient') });
  }
}

test('AnchorPersistence: requires pool', () => {
  assert.throws(() => new AnchorPersistence(null), /pool required/);
});

test('AnchorPersistence: persistAnchorCreate inserts row', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const anchor = {
    anchor_id: 'aid_1',
    room_id: 'r1',
    blueprint_id: 'echo_triad_anchor',
    state: 'in_progress',
    progress: 0,
    cooperation_count: 4,
    started_at: Date.now(),
    deadline_at: Date.now() + 60000,
    place_seq: 0
  };
  const r = await ap.persistAnchorCreate(anchor);
  assert.equal(r.ok, true);
  assert.ok(pool.executed.length >= 1);
  assert.equal(pool.executed[0].params[0], 'aid_1');
});

test('AnchorPersistence: persistSlotPlacement updates state', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  await ap.persistSlotPlacement('aid_1', 0, {
    state: 'filled',
    placed_shard_id: 'past_memorial_stone',
    place_seq: 1,
    placed_at: Date.now()
  }, 'player_0', 'idem_001');
  assert.ok(pool.executed.length >= 1);
  assert.equal(pool.executed[0].params[1], 'aid_1');
});

test('AnchorPersistence: persistSlotRemoval resets slot', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  await ap.persistSlotRemoval('aid_1', 0, 'past_memorial_stone', 'player_0', 'idem_002');
  assert.ok(pool.executed.length >= 1);
});

test('AnchorPersistence: persistAnchorComplete marks complete', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  await ap.persistAnchorComplete('aid_1', {}, 'perfect_testament', 500);
  assert.ok(pool.executed.length >= 1);
});

test('AnchorPersistence: persistAuditEvent inserts with idempotency', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  await ap.persistAuditEvent('aid_1', 'place_shard', {
    actor_player_id: 'player_0',
    slot_index: 0,
    shard_id: 'past_memorial_stone',
    event_id: 'evt_001',
    place_seq: 1,
    ok: true,
    ts: Date.now()
  });
  assert.ok(pool.executed.length >= 1);
});

test('AnchorPersistence: getAnchorSnapshot returns null when not found', async () => {
  const pool = new FakePool();
  pool.responses.push({ result: [[]] });
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const r = await ap.getAnchorSnapshot('ghost');
  assert.equal(r, null);
});

test('AnchorPersistence: getAnchorSnapshot returns anchor + slots', async () => {
  const pool = new FakePool();
  pool.responses.push({ result: [[{ anchor_id: 'aid_1', state: 'in_progress' }]] });
  pool.responses.push({ result: [[{ slot_id: 'aid_1:0', state: 'filled' }]] });
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const r = await ap.getAnchorSnapshot('aid_1');
  assert.ok(r.anchor);
  assert.equal(r.slots.length, 1);
});

test('AnchorPersistence: listRecentAnchors returns up to limit', async () => {
  const pool = new FakePool();
  pool.responses.push({ result: [[{ anchor_id: 'aid_1' }, { anchor_id: 'aid_2' }]] });
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const r = await ap.listRecentAnchors('room_1', 50);
  assert.equal(r.length, 2);
});

test('AnchorPersistence: getPlayerStats returns null when not found', async () => {
  const pool = new FakePool();
  pool.responses.push({ result: [[]] });
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const r = await ap.getPlayerStats('ghost');
  assert.equal(r, null);
});

test('AnchorPersistence: getLeaderboard returns top entries', async () => {
  const pool = new FakePool();
  pool.responses.push({ result: [[{ player_id: 'p1', total_score: 1000 }, { player_id: 'p2', total_score: 500 }]] });
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const r = await ap.getLeaderboard(100);
  assert.equal(r.length, 2);
});

test('AnchorPersistence: computeHash is SHA256', () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const anchor = { anchor_id: 'aid_1', slots: [{ slot_id: 's1', placed_shard: 'stone', place_seq: 1 }], place_seq: 1 };
  const h = ap.computeHash(anchor);
  assert.match(h, /^[0-9a-f]{64}$/);
});

test('AnchorPersistence: same state produces same hash (deterministic)', () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  const a = { anchor_id: 'aid_1', slots: [{ slot_id: 's1', placed_shard: 'stone', place_seq: 1 }], place_seq: 1 };
  const b = { anchor_id: 'aid_1', slots: [{ slot_id: 's1', placed_shard: 'stone', place_seq: 1 }], place_seq: 1 };
  assert.equal(ap.computeHash(a), ap.computeHash(b));
});

test('AnchorPersistence: bufferWrite accepts up to max_buffer_size', () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false, max_buffer_size: 3 });
  assert.equal(ap.bufferWrite(() => Promise.resolve()), true);
  assert.equal(ap.bufferWrite(() => Promise.resolve()), true);
  assert.equal(ap.bufferWrite(() => Promise.resolve()), true);
  assert.equal(ap.bufferWrite(() => Promise.resolve()), false);
});

test('AnchorPersistence: getMetrics tracks operations', async () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: false });
  await ap.persistAnchorCreate({ anchor_id: 'a1', blueprint_id: 'b1', state: 'in_progress' });
  await ap.persistAuditEvent('a1', 'place_shard', { event_id: 'e1' });
  const m = ap.getMetrics();
  assert.equal(m.persisted_anchors, 1);
  assert.equal(m.persisted_audit, 1);
});

test('AnchorPersistence: shutdown clears interval', () => {
  const pool = new FakePool();
  const ap = new AnchorPersistence(pool, { auto_flush: true });
  ap.shutdown();
  assert.equal(ap._flush_interval, null);
});
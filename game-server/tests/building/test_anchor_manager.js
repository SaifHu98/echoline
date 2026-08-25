const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ShardEngine = require('../../src/building/ShardEngine');
const AnchorEngine = require('../../src/building/AnchorEngine');
const AnchorManager = require('../../src/building/AnchorManager');

const CATALOG_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'shards', 'catalog.json');
const BLUEPRINTS_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'anchors', 'blueprints.json');

function makeFixture() {
  const shardEngine = ShardEngine.loadFromFile(CATALOG_PATH);
  const anchorEngine = AnchorEngine.loadFromFile(BLUEPRINTS_PATH, shardEngine);
  const manager = new AnchorManager(anchorEngine, 'room_test_001');
  return { shardEngine, anchorEngine, manager };
}

function makePlayers(n = 4) {
  const timelines = ['past', 'present', 'future', 'neutral'];
  return Array.from({ length: n }, (_, i) => ({
    id: `player_${i}`,
    name: `P${i}`,
    timeline: timelines[i % timelines.length]
  }));
}

test('AnchorManager: createAnchor stores anchor and returns serialized snapshot', () => {
  const { manager } = makeFixture();
  const result = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  assert.equal(result.ok, true);
  assert.ok(result.anchor.anchor_id);
  assert.equal(manager.listAnchors().length, 1);
});

test('AnchorManager: getAnchor returns null for unknown id', () => {
  const { manager } = makeFixture();
  assert.equal(manager.getAnchor('nonexistent'), null);
});

test('AnchorManager: processEvent handles place_shard', () => {
  const { manager, anchorEngine } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const anchorId = create.anchor.anchor_id;
  const r = manager.processEvent(anchorId, {
    type: 'place_shard',
    slot_index: 0,
    shard_id: 'past_memorial_stone',
    player_id: 'player_0'
  });
  assert.equal(r.ok, true);
  assert.ok(r.snapshot);
});

test('AnchorManager: processEvent rejects invalid payload', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const r = manager.processEvent(create.anchor.anchor_id, null);
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'invalid_payload');
});

test('AnchorManager: processEvent rejects unknown anchor', () => {
  const { manager } = makeFixture();
  const r = manager.processEvent('nope', { type: 'place_shard', slot_index: 0 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'anchor_not_found');
});

test('AnchorManager: processEvent rejects missing event type', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const r = manager.processEvent(create.anchor.anchor_id, { slot_index: 0 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'missing_event_type');
});

test('AnchorManager: processEvent rejects unknown event type', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const r = manager.processEvent(create.anchor.anchor_id, { type: 'fly_to_moon', slot_index: 0 });
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'unknown_event_type');
});

test('AnchorManager: processEvent idempotent replay returns same result', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const anchorId = create.anchor.anchor_id;
  const payload = {
    event_id: 'evt_001',
    type: 'place_shard',
    slot_index: 0,
    shard_id: 'past_memorial_stone',
    player_id: 'player_0'
  };
  const r1 = manager.processEvent(anchorId, payload);
  const r2 = manager.processEvent(anchorId, payload);
  assert.equal(r1.ok, true);
  assert.equal(r2.ok, true);
  assert.equal(r2.idempotent, true);
  assert.equal(r1.place_seq, r2.place_seq);
});

test('AnchorManager: processEvent complete anchor triggers effects', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('support_wall', makePlayers(2));
  const anchorId = create.anchor.anchor_id;
  const placements = [
    { slot_index: 0, shard_id: 'past_memorial_stone', player_id: 'player_0' },
    { slot_index: 1, shard_id: 'present_steel_frame', player_id: 'player_0' },
    { slot_index: 2, shard_id: 'future_holographic_crystal', player_id: 'player_0' },
    { slot_index: 3, shard_id: 'present_quartz_panel', player_id: 'player_0' }
  ];
  let lastResult = null;
  for (const p of placements) {
    lastResult = manager.processEvent(anchorId, { type: 'place_shard', ...p });
  }
  assert.equal(lastResult.complete, true);
  assert.ok(lastResult.effects);
  assert.equal(lastResult.effects.score_award, 150);
});

test('AnchorManager: processEvent remove_shard updates state', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('support_wall', makePlayers(2));
  const anchorId = create.anchor.anchor_id;
  manager.processEvent(anchorId, {
    type: 'place_shard',
    slot_index: 0,
    shard_id: 'past_memorial_stone',
    player_id: 'player_0'
  });
  const r = manager.processEvent(anchorId, {
    type: 'remove_shard',
    slot_index: 0,
    player_id: 'player_0'
  });
  assert.equal(r.ok, true);
  assert.equal(r.snapshot.slots[0].state, 'empty');
});

test('AnchorManager: syncStateTo returns compact state', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  manager.processEvent(create.anchor.anchor_id, {
    type: 'place_shard',
    slot_index: 0,
    shard_id: 'past_memorial_stone',
    player_id: 'player_0'
  });
  const sync = manager.syncStateTo(create.anchor.anchor_id);
  assert.equal(sync.slots[0].placed_shard, 'past_memorial_stone');
  assert.ok(sync.place_seq > 0);
});

test('AnchorManager: syncStateTo returns null for unknown anchor', () => {
  const { manager } = makeFixture();
  assert.equal(manager.syncStateTo('nope'), null);
});

test('AnchorManager: hashState returns SHA256', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const hash = manager.hashState(create.anchor.anchor_id);
  assert.match(hash, /^[0-9a-f]{64}$/);
});

test('AnchorManager: destroyAnchor removes from map', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const id = create.anchor.anchor_id;
  assert.equal(manager.destroyAnchor(id), true);
  assert.equal(manager.getAnchor(id), null);
});

test('AnchorManager: destroyAnchor returns false for unknown id', () => {
  const { manager } = makeFixture();
  assert.equal(manager.destroyAnchor('nope'), false);
});

test('AnchorManager: rejects createAnchor with invalid blueprint', () => {
  const { manager } = makeFixture();
  const r = manager.createAnchor('ghost_blueprint', makePlayers(4));
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'unknown_blueprint');
});

test('AnchorManager: rejects processEvent with missing shard_id', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const r = manager.processEvent(create.anchor.anchor_id, {
    type: 'place_shard',
    slot_index: 0,
    player_id: 'player_0'
  });
  assert.equal(r.ok, false);
});

test('AnchorManager: rejects processEvent with invalid slot_index', () => {
  const { manager } = makeFixture();
  const create = manager.createAnchor('echo_triad_anchor', makePlayers(4));
  const r = manager.processEvent(create.anchor.anchor_id, {
    type: 'place_shard',
    slot_index: -1,
    shard_id: 'past_memorial_stone',
    player_id: 'player_0'
  });
  assert.equal(r.ok, false);
});
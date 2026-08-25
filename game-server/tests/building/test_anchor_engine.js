const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ShardEngine = require('../../src/building/ShardEngine');
const AnchorEngine = require('../../src/building/AnchorEngine');

const CATALOG_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'shards', 'catalog.json');
const BLUEPRINTS_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'anchors', 'blueprints.json');

function makeEngines() {
  const shardEngine = ShardEngine.loadFromFile(CATALOG_PATH);
  const anchorEngine = AnchorEngine.loadFromFile(BLUEPRINTS_PATH, shardEngine);
  return { shardEngine, anchorEngine };
}

function makePlayers(n = 4) {
  const timelines = ['past', 'present', 'future', 'neutral'];
  return Array.from({ length: n }, (_, i) => ({
    id: `player_${i}`,
    name: `P${i}`,
    timeline: timelines[i % timelines.length]
  }));
}

test('AnchorEngine: loads blueprints from JSON', () => {
  const { anchorEngine } = makeEngines();
  assert.equal(anchorEngine.listBlueprints().length, 2);
});

test('AnchorEngine: createAnchor returns in_progress anchor with empty slots', () => {
  const { anchorEngine } = makeEngines();
  const result = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  assert.equal(result.ok, true);
  assert.equal(result.anchor.state, 'in_progress');
  assert.equal(result.anchor.slots.length, 6);
  assert.equal(result.anchor.progress, 0);
});

test('AnchorEngine: createAnchor fails with unknown blueprint', () => {
  const { anchorEngine } = makeEngines();
  const result = anchorEngine.createAnchor('nonexistent', makePlayers(4));
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'unknown_blueprint');
});

test('AnchorEngine: createAnchor fails when too many players', () => {
  const { anchorEngine } = makeEngines();
  const result = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(8));
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'too_many_players');
});

test('AnchorEngine: cooperation_required rejects single player', () => {
  const { anchorEngine } = makeEngines();
  const result = anchorEngine.createAnchor('echo_triad_anchor', [{ id: 'p1', name: 'solo' }]);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'insufficient_players');
});

test('AnchorEngine: support_wall allows single player (cooperation not required)', () => {
  const { anchorEngine } = makeEngines();
  const result = anchorEngine.createAnchor('support_wall', [{ id: 'p1', name: 'solo' }]);
  assert.equal(result.ok, true);
});

test('AnchorEngine: placeShard fills slot and updates progress', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  const result = anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  assert.equal(result.ok, true);
  assert.equal(result.progress, 1 / 6);
  assert.equal(create.anchor.slots[0].state, 'filled');
  assert.equal(create.anchor.slots[0].placed_shard, 'past_memorial_stone');
});

test('AnchorEngine: placeShard rejects wrong shard type', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  const result = anchorEngine.placeShard(create.anchor, 0, 'player_0', 'future_holographic_crystal');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'invalid_shard_for_slot');
});

test('AnchorEngine: placeShard enforces owner_index_required', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  const result = anchorEngine.placeShard(create.anchor, 0, 'player_1', 'past_memorial_stone');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'wrong_owner');
});

test('AnchorEngine: placeShard rejects double-fill', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const result = anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'slot_already_filled');
});

test('AnchorEngine: complete anchor when all slots filled', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  const placements = [
    { slot: 0, player: 'player_0', shard: 'past_memorial_stone' },
    { slot: 1, player: 'player_1', shard: 'present_steel_frame' },
    { slot: 2, player: 'player_2', shard: 'future_holographic_crystal' },
    { slot: 3, player: 'player_3', shard: 'epoch_alignment_marker' },
    { slot: 4, player: 'player_0', shard: 'past_carved_wood' },
    { slot: 5, player: 'player_2', shard: 'future_quantum_thread' }
  ];
  for (const p of placements) {
    const r = anchorEngine.placeShard(create.anchor, p.slot, p.player, p.shard);
    assert.equal(r.ok, true, `placeShard(${p.slot}, ${p.shard}) should succeed`);
  }
  assert.equal(create.anchor.state, 'complete');
  assert.equal(create.anchor.progress, 1);
});

test('AnchorEngine: removeShard resets slot to empty', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const result = anchorEngine.removeShard(create.anchor, 0, 'player_0');
  assert.equal(result.ok, true);
  assert.equal(create.anchor.slots[0].state, 'empty');
  assert.equal(create.anchor.progress, 0);
});

test('AnchorEngine: removeShard enforces owner_index_required', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const result = anchorEngine.removeShard(create.anchor, 0, 'player_1');
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'wrong_owner');
});

test('AnchorEngine: placeShard rejects on complete anchor', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('support_wall', makePlayers(2));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  anchorEngine.placeShard(create.anchor, 1, 'player_0', 'present_steel_frame');
  anchorEngine.placeShard(create.anchor, 2, 'player_0', 'future_holographic_crystal');
  anchorEngine.placeShard(create.anchor, 3, 'player_0', 'present_quartz_panel');
  const result = anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  assert.equal(result.ok, false);
  assert.equal(create.anchor.state, 'complete');
});

test('AnchorEngine: getCompletionEffects returns null on incomplete', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  assert.equal(anchorEngine.getCompletionEffects(create.anchor), null);
});

test('AnchorEngine: getCompletionEffects returns effects when complete', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('support_wall', makePlayers(2));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  anchorEngine.placeShard(create.anchor, 1, 'player_0', 'present_steel_frame');
  anchorEngine.placeShard(create.anchor, 2, 'player_0', 'future_holographic_crystal');
  anchorEngine.placeShard(create.anchor, 3, 'player_0', 'present_quartz_panel');
  const effects = anchorEngine.getCompletionEffects(create.anchor);
  assert.ok(effects);
  assert.equal(effects.score_award, 150);
});

test('AnchorEngine: serialize produces compact snapshot', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const snap = anchorEngine.serialize(create.anchor);
  assert.equal(snap.anchor_id, create.anchor.anchor_id);
  assert.equal(snap.slots[0].placed_shard, 'past_memorial_stone');
  assert.equal(snap.slots[1].state, 'empty');
});

test('AnchorEngine: hashState changes when shard placed', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  const h1 = anchorEngine.hashState(create.anchor);
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const h2 = anchorEngine.hashState(create.anchor);
  assert.notEqual(h1, h2);
});

test('AnchorEngine: idempotent place (same idem key) returns same result', () => {
  const { anchorEngine } = makeEngines();
  const create = anchorEngine.createAnchor('echo_triad_anchor', makePlayers(4));
  anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  const r1 = anchorEngine.placeShard(create.anchor, 0, 'player_0', 'past_memorial_stone');
  assert.equal(r1.ok, false);
  assert.equal(r1.reason, 'slot_already_filled');
});
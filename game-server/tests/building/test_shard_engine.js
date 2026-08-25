const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('path');
const ShardEngine = require('../../src/building/ShardEngine');

const CATALOG_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'shards', 'catalog.json');

test('ShardEngine: loads from JSON catalog', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  assert.ok(engine);
  assert.equal(engine.listShards().length, 10);
});

test('ShardEngine: getShard returns correct shard by id', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const shard = engine.getShard('past_memorial_stone');
  assert.ok(shard);
  assert.equal(shard.timeline, 'past');
  assert.equal(shard.tier, 'common');
});

test('ShardEngine: getShard returns null for unknown id', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  assert.equal(engine.getShard('does_not_exist'), null);
});

test('ShardEngine: computeDropRate applies base + cooperation bonus', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const solo = engine.computeDropRate('past_memorial_stone', { cooperation_count: 1 });
  const coop = engine.computeDropRate('past_memorial_stone', { cooperation_count: 4 });
  assert.ok(coop > solo, `coop (${coop}) should be > solo (${solo})`);
  assert.ok(coop <= engine.drop_rate_cap);
});

test('ShardEngine: computeDropRate grants rare bonus when rare_unlock true', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const base = engine.computeDropRate('past_runic_iron', { cooperation_count: 1 });
  const boosted = engine.computeDropRate('past_runic_iron', { cooperation_count: 1, rare_unlock: true });
  assert.ok(boosted > base);
});

test('ShardEngine: rollDrop returns matching shards for trigger', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const drops = engine.rollDrop(
    'echo_past_resolved',
    { players: [{ id: 'p1', online: true }] },
    () => 0
  );
  assert.ok(Array.isArray(drops));
  for (const drop of drops) {
    assert.ok(drop.shard_id);
    assert.ok(['past', 'present', 'future', 'neutral'].includes(drop.timeline));
  }
});

test('ShardEngine: rollDrop with rng=0 produces all eligible shards', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const drops = engine.rollDrop(
    'echo_past_resolved',
    { players: [{ id: 'p1', online: true }] },
    () => 0
  );
  assert.ok(drops.length >= 1, 'should drop at least one past shard');
});

test('ShardEngine: rollDrop with rng=1 produces no drops', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const drops = engine.rollDrop(
    'echo_past_resolved',
    { players: [{ id: 'p1', online: true }] },
    () => 1
  );
  assert.equal(drops.length, 0);
});

test('ShardEngine: rollDrop requires players in context', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  assert.throws(() => engine.rollDrop('echo_past_resolved', {}), /players required/);
});

test('ShardEngine: assignToInventory updates counts and returns add events', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = {};
  const drops = [
    { shard_id: 'past_memorial_stone', drop_id: 'd1' },
    { shard_id: 'past_memorial_stone', drop_id: 'd2' },
    { shard_id: 'present_steel_frame', drop_id: 'd3' }
  ];
  const events = engine.assignToInventory(inv, drops);
  assert.equal(events.length, 3);
  assert.equal(inv.past_memorial_stone, 2);
  assert.equal(inv.present_steel_frame, 1);
});

test('ShardEngine: assignToInventory ignores unknown shards', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = {};
  const drops = [{ shard_id: 'ghost_shard', drop_id: 'x' }];
  const events = engine.assignToInventory(inv, drops);
  assert.equal(events.length, 0);
});

test('ShardEngine: convertDuplicates removes every Nth shard', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = { past_memorial_stone: 7 };
  const events = engine.convertDuplicates(inv);
  assert.equal(events.length, 1);
  assert.equal(events[0].converted_count, 2);
  assert.equal(inv.past_memorial_stone, 1);
});

test('ShardEngine: convertDuplicates returns empty when below threshold', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = { past_memorial_stone: 2 };
  const events = engine.convertDuplicates(inv);
  assert.equal(events.length, 0);
  assert.equal(inv.past_memorial_stone, 2);
});

test('ShardEngine: validateForSlot returns ok when inventory has valid shard', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = { past_memorial_stone: 1 };
  const slot = { slot_id: 's1', valid_shards: ['past_memorial_stone', 'past_carved_wood'], preferred_timeline: 'past' };
  const result = engine.validateForSlot(inv, slot);
  assert.equal(result.ok, true);
  assert.equal(result.candidates.length, 1);
  assert.equal(result.candidates[0].preferred_match, true);
});

test('ShardEngine: validateForSlot returns no_shards_available when inventory empty', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const inv = {};
  const slot = { slot_id: 's1', valid_shards: ['past_memorial_stone'] };
  const result = engine.validateForSlot(inv, slot);
  assert.equal(result.ok, false);
  assert.equal(result.reason, 'no_shards_available');
});

test('ShardEngine: listShardsForSlot returns full shard definitions', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const slot = { valid_shards: ['past_memorial_stone', 'present_steel_frame'] };
  const list = engine.listShardsForSlot(slot);
  assert.equal(list.length, 2);
  assert.ok(list.find(s => s.id === 'past_memorial_stone'));
});

test('ShardEngine: drop rate capped at 1.0', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  const rate = engine.computeDropRate('future_singularity_core', {
    cooperation_count: 4,
    rare_unlock: true,
    legendary_match: true
  });
  assert.ok(rate <= 1.0);
  assert.ok(rate >= 0);
});

test('ShardEngine: deterministic drop with seeded RNG', () => {
  const engine = ShardEngine.loadFromFile(CATALOG_PATH);
  let seed = 42;
  const rng = () => {
    seed = (seed * 9301 + 49297) % 233280;
    return seed / 233280;
  };
  const drops1 = engine.rollDrop('echo_present_resolved', { players: [{ id: 'p1', online: true }] }, rng);
  seed = 42;
  const drops2 = engine.rollDrop('echo_present_resolved', { players: [{ id: 'p1', online: true }] }, rng);
  assert.equal(drops1.length, drops2.length);
  for (let i = 0; i < drops1.length; i++) {
    assert.equal(drops1[i].shard_id, drops2[i].shard_id);
  }
});

test('ShardEngine: invalid catalog throws on construction', () => {
  assert.throws(() => new ShardEngine(null), /invalid catalog/);
  assert.throws(() => new ShardEngine({}), /invalid catalog/);
});
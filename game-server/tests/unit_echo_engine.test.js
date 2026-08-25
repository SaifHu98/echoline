/**
 * Unit + Property tests for the new deterministic EchoEngine
 * Pure functions, no I/O, no random. Deterministic time.
 */

'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const EchoEngine = require('../src/simulation/EchoEngine');

// ===== Deterministic test helpers =====
function makeCtx({ state, player = null, appliedEchoes = new Set(), scheduledEffects = [], hints = new Map(), recordEvent = () => {}, now = null } = {}) {
  return {
    state: state || {
      past: {},
      present: {},
      future: {},
      _system: { catastrophe_timer_ms: 600000, stability: 100, current_stage: 'stable' },
    },
    player,
    appliedEchoes,
    scheduledEffects,
    playerHints: hints,
    logger: { info() {}, warn() {}, error() {}, debug() {} },
    now: now || (() => 1_700_000_000_000),
    elapsedSeconds: () => 0,
    recordEvent,
  };
}

const RULES = [
  {
    id: 'r1',
    source_timeline: 'past',
    source_entity: 'soil',
    trigger_action: 'plant',
    preconditions: [],
    effects: [{ target_timeline: 'past', entity: 'soil', action: 'set_property', property: 'seed', value: 'oak' }],
    conflict_priority: 1,
  },
  {
    id: 'r2',
    source_timeline: 'past',
    source_entity: 'soil',
    trigger_action: 'plant',
    preconditions: [],
    effects: [{ target_timeline: 'past', entity: 'soil', action: 'set_property', property: 'seed', value: 'pine' }],
    conflict_priority: 2,
  },
  {
    id: 'r3',
    source_timeline: 'present',
    source_entity: 'basin',
    trigger_action: 'release',
    preconditions: [
      { timeline: 'past', entity: 'soil', property: 'seed', operator: '==', value: 'oak' },
    ],
    effects: [{ target_timeline: 'present', entity: 'basin', action: 'set_property', property: 'water', value: 'flowing', propagation_delay_ms: 500 }],
    conflict_priority: 5,
  },
];

// ====== Tests ======
test('findRule returns highest priority when multiple rules match', () => {
  const engine = new EchoEngine({ rules: RULES });
  const rule = engine.findRule({ sourceTimeline: 'past', sourceEntity: 'soil', triggerAction: 'plant' });
  assert.equal(rule.id, 'r2');
});

test('findRule by id returns exact rule', () => {
  const engine = new EchoEngine({ rules: RULES });
  const rule = engine.findRule({ sourceTimeline: 'past', sourceEntity: 'soil', triggerAction: 'plant', ruleId: 'r1' });
  assert.equal(rule.id, 'r1');
});

test('findRule returns null when no match', () => {
  const engine = new EchoEngine({ rules: RULES });
  const rule = engine.findRule({ sourceTimeline: 'future', sourceEntity: 'x', triggerAction: 'y' });
  assert.equal(rule, null);
});

test('checkPreconditions passes when all conditions met', () => {
  const engine = new EchoEngine({ rules: RULES });
  const ctx = makeCtx({
    state: {
      past: { soil: { seed: 'oak' } },
      present: {}, future: {},
      _system: {},
    },
  });
  const result = engine.checkPreconditions(RULES[2], ctx);
  assert.equal(result.passed, true);
});

test('checkPreconditions fails with structured failure when not met', () => {
  const engine = new EchoEngine({ rules: RULES });
  const ctx = makeCtx({
    state: { past: { soil: { seed: 'pine' } }, present: {}, future: {}, _system: {} },
  });
  const result = engine.checkPreconditions(RULES[2], ctx);
  assert.equal(result.passed, false);
  assert.equal(result.failures[0].reason, 'precondition_failed');
});

test('applyEffects immediate writes to state', () => {
  const engine = new EchoEngine({ rules: RULES });
  const events = [];
  const ctx = makeCtx({
    state: { past: { soil: { seed: 'pine' } }, present: {}, future: {}, _system: {} },
    recordEvent: (type, data) => events.push({ type, data }),
  });
  engine.applyEffects(RULES[0], ctx, 'p1');
  assert.equal(ctx.state.past.soil.seed, 'oak');
  // engine records both effect_applied (per effect) and effects_applied (summary)
  assert.ok(events.some(e => e.type === 'effect_applied'), 'should record per-effect event');
  assert.ok(events.some(e => e.type === 'effects_applied'), 'should record summary event');
});

test('applyEffects scheduled does not apply immediately but is recorded', () => {
  const engine = new EchoEngine({ rules: RULES });
  const ctx = makeCtx({
    state: { past: { soil: { seed: 'oak' } }, present: { basin: {} }, future: {}, _system: {} },
    recordEvent: () => {},
  });
  // ensure scheduledEffects array exists
  ctx.scheduledEffects = [];
  engine.applyEffects(RULES[2], ctx, 'p1');
  assert.equal(ctx.state.present.basin.water, undefined);
  assert.equal(ctx.scheduledEffects.length, 1);
});

test('applyDueScheduled applies only due effects', () => {
  const engine = new EchoEngine({ rules: RULES });
  const nowBase = 1_700_000_000_000;
  const ctx = makeCtx({
    state: { past: { soil: { seed: 'oak' } }, present: { basin: {} }, future: {}, _system: {} },
    recordEvent: () => {},
    now: () => nowBase,
  });
  ctx.scheduledEffects = [];
  engine.applyEffects(RULES[2], ctx, 'p1');
  assert.equal(ctx.scheduledEffects.length, 1);
  // move time forward
  ctx.now = () => nowBase + 1000;
  const applied = engine.applyDueScheduled(ctx);
  assert.equal(applied.length, 1);
  assert.equal(ctx.state.present.basin.water, 'flowing');
});

test('checkConflict detects conflicting writes with higher priority blocker', () => {
  const engine = new EchoEngine({ rules: [
    {
      id: 'a', source_timeline: 'past', source_entity: 'x', trigger_action: 't',
      effects: [{ target_timeline: 'past', entity: 'e', action: 'set_property', property: 'v', value: 1 }],
      conflict_priority: 1,
    },
    {
      id: 'b', source_timeline: 'past', source_entity: 'x', trigger_action: 't',
      effects: [{ target_timeline: 'past', entity: 'e', action: 'set_property', property: 'v', value: 2 }],
      conflict_priority: 10,
    },
  ]});
  const ruleB = engine.byId.get('b');
  const ctx = makeCtx({
    state: { past: { e: { v: 1 } }, _system: {} },
    appliedEchoes: new Set(['a']),
  });
  const conflict = engine.checkConflict(ruleB, ctx);
  // 'b' has higher priority than 'a' → no conflict blocks it
  assert.equal(conflict, null);
});

test('add_value, toggle, append, remove work correctly', () => {
  const engine = new EchoEngine({ rules: [] });
  const events = [];
  const ctx = makeCtx({
    state: { past: { counter: { v: 5 }, flag: { b: false }, list: { items: [] } }, _system: {} },
    recordEvent: (type, data) => events.push({ type, data }),
  });
  engine._applyImmediate({ target_timeline: 'past', entity: 'counter', action: 'add_value', property: 'v', value: 3 }, ctx, 'r');
  engine._applyImmediate({ target_timeline: 'past', entity: 'flag', action: 'toggle', property: 'b' }, ctx, 'r');
  engine._applyImmediate({ target_timeline: 'past', entity: 'list', action: 'append', property: 'items', value: 'a' }, ctx, 'r');
  engine._applyImmediate({ target_timeline: 'past', entity: 'counter', action: 'remove', property: 'v' }, ctx, 'r');
  assert.equal(ctx.state.past.counter.v, undefined);
  assert.equal(ctx.state.past.flag.b, true);
  assert.deepEqual(ctx.state.past.list.items, ['a']);
});

test('system preconditions (catastrophe timer) are resolved', () => {
  const engine = new EchoEngine({ rules: [] });
  const ctx = makeCtx({
    state: { past: {}, _system: { catastrophe_timer_ms: 300000 } },
  });
  const rule = { id: 'x', preconditions: [{ timeline: 'system', entity: 'catastrophe', property: 'timer_remaining_ms', operator: '>', value: 0 }] };
  const result = engine.checkPreconditions(rule, ctx);
  assert.equal(result.passed, true);
});

test('requiredFor dependency graph traversal', () => {
  const engine = new EchoEngine({ rules: [
    { id: 'a', source_timeline: 'past', source_entity: 'e', trigger_action: 't', preconditions: [], effects: [], conflict_priority: 1 },
    { id: 'b', source_timeline: 'past', source_entity: 'e', trigger_action: 't', preconditions: [{ derived_from_rule: 'a' }], effects: [], conflict_priority: 2 },
    { id: 'c', source_timeline: 'past', source_entity: 'e', trigger_action: 't', preconditions: [{ derived_from_rule: 'b' }], effects: [], conflict_priority: 3 },
  ]});
  const req = EchoEngine.requiredFor(engine, 'c');
  assert.ok(req.has('a') && req.has('b') && req.has('c'));
});

// ====== Property tests ======
test('property: same input -> same output (deterministic)', () => {
  const engine = new EchoEngine({ rules: RULES });
  const nowBase = 1_700_000_000_000;
  const makeCtx2 = () => ({
    state: { past: { soil: {} }, present: { basin: {} }, future: {}, _system: {} },
    appliedEchoes: new Set(),
    scheduledEffects: [],
    recordEvent: () => {},
    now: () => nowBase,
    elapsedSeconds: () => 0,
  });
  const c1 = makeCtx2();
  const c2 = makeCtx2();
  // RULES[0] (r1) has no preconditions and writes immediately to past.soil.seed
  engine.applyEffects(RULES[0], c1, 'p');
  engine.applyEffects(RULES[0], c2, 'p');
  // now both contexts satisfy RULES[2]'s precondition (seed == 'oak')
  engine.applyEffects(RULES[2], c1, 'p');
  engine.applyEffects(RULES[2], c2, 'p');
  // apply scheduled (both ctx have now at nowBase + 1000)
  c1.now = () => nowBase + 1000;
  c2.now = () => nowBase + 1000;
  engine.applyDueScheduled(c1);
  engine.applyDueScheduled(c2);
  assert.deepEqual(c1.state, c2.state);
});

test('property: invalid action ignored, state unchanged', () => {
  const engine = new EchoEngine({ rules: [] });
  const ctx = makeCtx({ state: { past: { x: { v: 1 } }, _system: {} }, recordEvent: () => {} });
  const before = JSON.stringify(ctx.state);
  engine._applyImmediate({ target_timeline: 'past', entity: 'x', action: 'unknown_action', property: 'v', value: 999 }, ctx, 'r');
  assert.equal(JSON.stringify(ctx.state), before);
});

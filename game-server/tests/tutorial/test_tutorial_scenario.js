const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { TutorialScenario, TutorialProgress } = require('../../src/tutorial/TutorialScenario');

const TUTORIAL_PATH = path.join(__dirname, '..', '..', '..', 'shared', 'scenarios', 'tutorial_first_anchor.json');

test('TutorialScenario: loads from JSON file', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  assert.equal(s.scenario_id, 'tutorial_first_anchor_v1');
});

test('TutorialScenario: requires scenario_id', () => {
  assert.throws(() => new TutorialScenario(null), /invalid json/);
  assert.throws(() => new TutorialScenario({}), /invalid json/);
});

test('TutorialScenario: rejects invalid step types', () => {
  const json = {
    scenario_id: 'bad',
    duration_target_seconds: 60,
    echoes: [{ echo_id: 'e1', timeline: 'past', type: 'single_choice', prompt: {}, options: [], completion_effects: [] }],
    anchor_blueprint_id: 'support_wall',
    intro_sequence: [{ type: 'malformed_step', step_id: 'x' }]
  };
  assert.throws(() => new TutorialScenario(json), /invalid intro step type/);
});

test('TutorialScenario: rejects missing echoes', () => {
  const json = {
    scenario_id: 'no_echoes',
    duration_target_seconds: 60,
    anchor_blueprint_id: 'support_wall'
  };
  assert.throws(() => new TutorialScenario(json), /at least one echo required/);
});

test('TutorialScenario: rejects missing anchor_blueprint_id', () => {
  const json = {
    scenario_id: 'no_bp',
    duration_target_seconds: 60,
    echoes: [{ echo_id: 'e1' }]
  };
  assert.throws(() => new TutorialScenario(json), /anchor_blueprint_id required/);
});

test('TutorialScenario: getTotalSteps counts all phases', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const total = s.getTotalSteps();
  const expected = s.intro_sequence.length + 1 + s.anchor_guidance.length + s.completion_sequence.length;
  assert.equal(total, expected);
});

test('TutorialScenario: getStepAtIndex returns correct phase', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const first = s.getStepAtIndex(0);
  assert.equal(first.phase, 'intro');
  const lastIntroIdx = s.intro_sequence.length - 1;
  assert.equal(s.getStepAtIndex(lastIntroIdx).phase, 'intro');
  assert.equal(s.getStepAtIndex(s.intro_sequence.length).phase, 'anchor_intro');
  assert.equal(s.getStepAtIndex(s.intro_sequence.length + 1).phase, 'anchor_guidance');
  const completionIdx = s.intro_sequence.length + 1 + s.anchor_guidance.length;
  assert.equal(s.getStepAtIndex(completionIdx).phase, 'completion');
});

test('TutorialScenario: getStepAtIndex returns null for out-of-bounds', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  assert.equal(s.getStepAtIndex(-1), null);
  assert.equal(s.getStepAtIndex(99999), null);
});

test('TutorialScenario: getStepById searches all phases', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const introStep = s.getStepById('welcome');
  assert.ok(introStep);
  assert.equal(introStep.phase, 'intro');
  const completionStep = s.getStepById('celebration');
  assert.ok(completionStep);
  assert.equal(completionStep.phase, 'completion');
  assert.equal(s.getStepById('nonexistent'), null);
});

test('TutorialScenario: validateShardForStep checks timeline', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const step = s.anchor_guidance.find(g => g.validation && g.validation.shard_must_be_timeline === 'past');
  assert.ok(step);
  const r1 = s.validateShardForStep(step.step_id, 'past_memorial_stone', 'past');
  assert.equal(r1.ok, true);
  const r2 = s.validateShardForStep(step.step_id, 'present_steel_frame', 'present');
  assert.equal(r2.ok, false);
  assert.equal(r2.reason, 'wrong_shard_timeline');
});

test('TutorialScenario: validateShardForStep handles steps without validation', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const r = s.validateShardForStep('welcome', 'past_memorial_stone', 'past');
  assert.equal(r.ok, true);
});

test('TutorialScenario: validateShardForStep returns unknown_step for bad id', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const r = s.validateShardForStep('nonexistent', 'past_memorial_stone', 'past');
  assert.equal(r.ok, false);
  assert.equal(r.reason, 'unknown_step');
});

test('TutorialProgress: starts at step 0', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  assert.equal(p.current_step_index, 0);
  assert.equal(p.isComplete(), false);
  assert.equal(p.isFailed(), false);
});

test('TutorialProgress: advance increments step index', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  p.advance();
  assert.equal(p.current_step_index, 1);
  assert.equal(p.isComplete(), false);
});

test('TutorialProgress: advancing past end marks complete', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  for (let i = 0; i < s.getTotalSteps() + 5; i++) p.advance();
  assert.equal(p.isComplete(), true);
});

test('TutorialProgress: recordEchoResolved tracks echoes', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  p.recordEchoResolved('echo_intro_001', 'listen', 'shard_past_memorial_stone');
  p.recordEchoResolved('echo_intro_002', 'examine', 'shard_present_steel_frame');
  assert.equal(p.echoes_resolved.length, 2);
});

test('TutorialProgress: recordShardPlaced tracks placements', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  p.recordShardPlaced('past_memorial_stone', 0);
  p.recordShardPlaced('present_steel_frame', 1);
  p.recordShardPlaced('future_holographic_crystal', 2);
  assert.equal(p.shards_placed.length, 3);
});

test('TutorialProgress: fail sets failed_at and dropped step', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  p.advance();
  p.advance();
  p.fail('anchor_incomplete_at_timeout');
  assert.equal(p.isFailed(), true);
  assert.equal(p.dropped_at_step, 2);
});

test('TutorialProgress: getDurationSeconds returns wall time', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  assert.equal(p.getDurationSeconds() >= 0, true);
});

test('TutorialProgress: toJSON returns compact snapshot', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const p = new TutorialProgress(s, 'player_0');
  p.recordEchoResolved('echo_intro_001', 'listen', 'shard_past_memorial_stone');
  p.recordShardPlaced('past_memorial_stone', 0);
  const json = p.toJSON();
  assert.equal(json.scenario_id, 'tutorial_first_anchor_v1');
  assert.equal(json.echoes_resolved_count, 1);
  assert.equal(json.shards_placed_count, 1);
  assert.ok(json.session_id);
});

test('TutorialScenario: completion rewards defined', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  assert.ok(s.rewards);
  assert.equal(typeof s.rewards.completion_credits, 'number');
  assert.equal(typeof s.rewards.first_completion_bonus_shards, 'number');
});

test('TutorialScenario: all 3 timelines present in echoes', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const timelines = new Set(s.echoes.map(e => e.timeline));
  assert.ok(timelines.has('past'));
  assert.ok(timelines.has('present'));
  assert.ok(timelines.has('future'));
});

test('TutorialScenario: anchor_guidance has at least 3 timeline-specific placements', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const timelinePlacements = s.anchor_guidance.filter(g =>
    g.validation && g.validation.shard_must_be_timeline
  );
  const timelines = new Set(timelinePlacements.map(g => g.validation.shard_must_be_timeline));
  assert.ok(timelines.size >= 3, `expected ≥3 timeline-specific placements, got ${timelines.size}`);
});

test('TutorialScenario: completion has matchmaking next_action', () => {
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  const lastStep = s.completion_sequence[s.completion_sequence.length - 1];
  assert.match(lastStep.next_action || '', /^matchmake_into_scenario:/);
});

test('TutorialProgress: rejects missing scenario or playerId', () => {
  assert.throws(() => new TutorialProgress(null, 'p1'), /scenario \+ playerId required/);
  const s = TutorialScenario.loadFromFile(TUTORIAL_PATH);
  assert.throws(() => new TutorialProgress(s, null), /scenario \+ playerId required/);
});
const test = require('node:test');
const assert = require('node:assert');
const path = require('path');
const fs = require('fs');
const { TemporalEchoEngine } = require('../src/simulation/echo_engine');

const scenarioPath = path.join(__dirname, '../../shared/scenario_definitions/clocktower_district.json');
const scenarioDef = JSON.parse(fs.readFileSync(scenarioPath, 'utf-8'));

test('Temporal Echo Engine - Unit Tests', async (t) => {
  await t.test('initializes state correctly from scenario', () => {
    const engine = new TemporalEchoEngine(scenarioDef.timelines_initial_state, scenarioDef.echo_rules);
    const state = engine.getState();
    assert.strictEqual(state.past.canal_debris.state, 'blocking');
    assert.strictEqual(state.past.canal_sluice_gate.state, 'closed');
    assert.strictEqual(state.present.canal_basin.water_level, 'dry');
    assert.strictEqual(state.future.hydro_turbine.status, 'offline_dry');
  });

  await t.test('rejects echo when timeline does not match', () => {
    const engine = new TemporalEchoEngine(scenarioDef.timelines_initial_state, scenarioDef.echo_rules);
    const res = engine.triggerEcho('echo_clear_debris', 'future', 'player_future');
    assert.strictEqual(res.success, false);
    assert.match(res.reason, /Timeline mismatch/);
  });

  await t.test('rejects echo when preconditions are not met', () => {
    const engine = new TemporalEchoEngine(scenarioDef.timelines_initial_state, scenarioDef.echo_rules);
    // echo_divert_canal_water requires canal_debris == 'cleared', but it is 'blocking'
    const res = engine.triggerEcho('echo_divert_canal_water', 'past', 'player_past');
    assert.strictEqual(res.success, false);
    assert.match(res.reason, /Preconditions not satisfied/);
  });

  await t.test('propagates cross-timeline echoes in causal order', () => {
    const engine = new TemporalEchoEngine(scenarioDef.timelines_initial_state, scenarioDef.echo_rules);
    
    // 1. Clear debris
    const res1 = engine.triggerEcho('echo_clear_debris', 'past', 'p1');
    assert.strictEqual(res1.success, true);
    assert.strictEqual(engine.getState().past.canal_debris.state, 'cleared');

    // 2. Open sluice gate (propagates water to Present and Future)
    const res2 = engine.triggerEcho('echo_divert_canal_water', 'past', 'p1');
    assert.strictEqual(res2.success, true);
    
    const state = engine.getState();
    assert.strictEqual(state.past.canal_sluice_gate.state, 'open');
    assert.strictEqual(state.present.canal_basin.water_level, 'flowing');
    assert.strictEqual(state.future.hydro_turbine.status, 'water_powered');
    assert.strictEqual(state.future.hydro_turbine.power_output, 50);

    // 3. Verify causal log recording
    const history = engine.getCausalHistory();
    assert.strictEqual(history.length, 2);
    assert.strictEqual(history[0].echo_id, 'echo_clear_debris');
    assert.strictEqual(history[1].echo_id, 'echo_divert_canal_water');
  });
});

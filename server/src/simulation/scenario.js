/**
 * Authoritative Scenario Simulation Controller for ECHO//LINE (أصداء)
 * Manages catastrophe decay timer, stability index, stage warnings, and win/loss checks.
 */

const { TemporalEchoEngine } = require('./echo_engine');
const { CausalRecapBuilder } = require('./causal_recap');

class MatchScenario {
  constructor(scenarioDefinition, matchId = 'match_01', seed = 12345) {
    this.def = scenarioDefinition;
    this.matchId = matchId;
    this.seed = seed;
    this.echoEngine = new TemporalEchoEngine(
      scenarioDefinition.timelines_initial_state,
      scenarioDefinition.echo_rules
    );

    this.durationMs = scenarioDefinition.catastrophe.duration_seconds * 1000;
    this.remainingMs = this.durationMs;
    this.startTime = Date.now();
    this.endTime = null;
    this.status = 'active'; // 'active', 'concluded'
    this.outcome = null;
    this.currentStage = 'stable';
    this.timerInterval = null;
    this.onTick = null; // (scenarioState) => {}
    this.onMatchEnded = null; // (recap) => {}
  }

  start() {
    this.startTime = Date.now();
    this.status = 'active';
  }

  tick(deltaMs) {
    if (this.status !== 'active') return;

    this.remainingMs = Math.max(0, this.remainingMs - deltaMs);
    const pct = (this.remainingMs / this.durationMs) * 100;

    // Update catastrophe stage
    for (const stage of this.def.catastrophe.stages) {
      if (pct <= stage.threshold_pct) {
        this.currentStage = stage.name;
      }
    }

    // Check Win/Loss conditions
    const state = this.echoEngine.getState();

    // 1. Check Win
    for (const win of this.def.win_conditions) {
      if (this.evaluateCondition(state, win.requirements)) {
        this.concludeMatch(win.id, win.outcome_key, win.grade);
        return;
      }
    }

    // 2. Check Loss (Timeout)
    if (this.remainingMs <= 0) {
      const loss = this.def.loss_conditions[0];
      this.concludeMatch(loss.id, loss.outcome_key, 'failure');
      return;
    }

    if (typeof this.onTick === 'function') {
      this.onTick({
        remaining_ms: this.remainingMs,
        stability_pct: Math.round(pct * 10) / 10,
        stage: this.currentStage
      });
    }
  }

  evaluateCondition(state, requirements) {
    for (const req of requirements) {
      const { timeline, entity, property, operator = '==', value } = req;
      if (!state[timeline] || !state[timeline][entity]) return false;
      const actual = state[timeline][entity][property];

      if (operator === '==' && actual !== value) return false;
      if (operator === '!=' && actual === value) return false;
    }
    return true;
  }

  handlePlayerIntent(echoId, timeline, playerId) {
    if (this.status !== 'active') {
      return { success: false, reason: 'Match is not active' };
    }
    const result = this.echoEngine.triggerEcho(echoId, timeline, playerId);
    
    // Check if triggering this echo immediately satisfies victory
    if (result.success) {
      const state = this.echoEngine.getState();
      for (const win of this.def.win_conditions) {
        if (this.evaluateCondition(state, win.requirements)) {
          this.concludeMatch(win.id, win.outcome_key, win.grade);
          break;
        }
      }
    }

    return result;
  }

  concludeMatch(outcomeId, outcomeKey, grade) {
    this.status = 'concluded';
    this.endTime = Date.now();
    this.outcome = { id: outcomeId, key: outcomeKey, grade };

    const recap = CausalRecapBuilder.buildRecap(this.echoEngine.getCausalHistory(), {
      match_id: this.matchId,
      outcome_id: outcomeId,
      outcome_key: outcomeKey,
      outcome_grade: grade,
      start_time: this.startTime,
      end_time: this.endTime
    });

    if (typeof this.onMatchEnded === 'function') {
      this.onMatchEnded(recap);
    }

    return recap;
  }
}

module.exports = {
  MatchScenario
};

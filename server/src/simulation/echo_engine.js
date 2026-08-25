/**
 * Temporal Echo Simulation Engine for ECHO//LINE (أصداء)
 * Handles deterministic causal graph propagation, state updates, and echo causality tracking.
 */

class TemporalEchoEngine {
  constructor(initialState, echoRules = []) {
    this.state = JSON.parse(JSON.stringify(initialState));
    this.echoRules = new Map();
    echoRules.forEach(rule => this.echoRules.set(rule.id, rule));
    this.causalLog = [];
    this.sequenceId = 0;
    this.onStateDelta = null; // Callback: (delta, echoRule) => {}
  }

  getState() {
    return JSON.parse(JSON.stringify(this.state));
  }

  evaluatePreconditions(preconditions) {
    if (!preconditions || preconditions.length === 0) return true;

    for (const cond of preconditions) {
      const { timeline, entity, property, operator = '==', value } = cond;
      if (!this.state[timeline] || !this.state[timeline][entity]) return false;
      const actual = this.state[timeline][entity][property];

      if (operator === '==' && actual !== value) return false;
      if (operator === '!=' && actual === value) return false;
      if (operator === '>' && !(actual > value)) return false;
      if (operator === '<' && !(actual < value)) return false;
      if (operator === '>=' && !(actual >= value)) return false;
      if (operator === '<=' && !(actual <= value)) return false;
    }
    return true;
  }

  /**
   * Process a player intent against the authoritative echo rules.
   * @param {string} echoId 
   * @param {string} requestingTimeline 
   * @param {string} playerId 
   * @returns {{ success: boolean, reason?: string, deltas?: Array, echo?: Object }}
   */
  triggerEcho(echoId, requestingTimeline, playerId = 'anon') {
    const rule = this.echoRules.get(echoId);
    if (!rule) {
      return { success: false, reason: `Unknown echo rule: ${echoId}` };
    }

    if (rule.source_timeline !== requestingTimeline) {
      return { 
        success: false, 
        reason: `Timeline mismatch: Rule requires '${rule.source_timeline}', triggered by '${requestingTimeline}'` 
      };
    }

    if (!this.evaluatePreconditions(rule.preconditions)) {
      return { success: false, reason: 'Preconditions not satisfied in current world state' };
    }

    // Apply effects and generate deltas
    const deltas = [];
    const now = Date.now();

    for (const effect of rule.effects) {
      const { target_timeline, entity, action, property, value, propagation_delay_ms = 0 } = effect;
      if (!this.state[target_timeline]) {
        this.state[target_timeline] = {};
      }
      if (!this.state[target_timeline][entity]) {
        this.state[target_timeline][entity] = {};
      }

      if (action === 'set_property') {
        this.state[target_timeline][entity][property] = value;
        const delta = {
          seq: ++this.sequenceId,
          timeline: target_timeline,
          entity,
          property,
          value,
          delay_ms: propagation_delay_ms,
          timestamp: now
        };
        deltas.push(delta);
      }
    }

    // Append to immutable causal recap log
    const causalEvent = {
      seq: this.sequenceId,
      echo_id: rule.id,
      source_timeline: rule.source_timeline,
      triggered_by: playerId,
      timestamp: now,
      loc_key: rule.localization_key,
      audio_cue: rule.audio_cue,
      visual_ripple: rule.visual_ripple,
      deltas
    };
    this.causalLog.push(causalEvent);

    if (typeof this.onStateDelta === 'function') {
      this.onStateDelta(deltas, rule, causalEvent);
    }

    return {
      success: true,
      echo: rule,
      deltas,
      causalEvent
    };
  }

  getCausalHistory() {
    return [...this.causalLog];
  }
}

module.exports = {
  TemporalEchoEngine
};

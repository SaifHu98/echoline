const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const DEFAULT_SCENARIO_PATH = path.join(__dirname, '..', '..', 'shared', 'scenarios', 'tutorial_first_anchor.json');

const STEP_TYPES = new Set(['narrator_card', 'guided_action', 'feedback', 'celebration_card', 'reward']);

class TutorialScenario {
  constructor(json) {
    if (!json || !json.scenario_id) {
      throw new Error('TutorialScenario: invalid json (missing scenario_id)');
    }
    this.json = json;
    this.scenario_id = json.scenario_id;
    this.duration_target_seconds = json.duration_target_seconds ?? 300;
    this.min_players = json.min_players ?? 1;
    this.max_players = json.max_players ?? 4;
    this.recommended_players = json.recommended_players ?? 2;
    this.intro_sequence = json.intro_sequence || [];
    this.echoes = json.echoes || [];
    this.anchor_blueprint_id = json.anchor_blueprint_id;
    this.anchor_intro = json.anchor_intro || {};
    this.anchor_guidance = json.anchor_guidance || [];
    this.completion_sequence = json.completion_sequence || [];
    this.failure_outcomes = json.failure_outcomes || [];
    this.rewards = {
      completion_credits: json.completion_credits ?? 0,
      first_completion_bonus_shards: json.first_completion_bonus_shards ?? 0
    };
    this._validate();
  }

  static loadFromFile(filePath = DEFAULT_SCENARIO_PATH) {
    const raw = fs.readFileSync(filePath, 'utf8');
    const json = JSON.parse(raw);
    return new TutorialScenario(json);
  }

  _validate() {
    for (const step of this.intro_sequence) {
      if (!STEP_TYPES.has(step.type)) {
        throw new Error(`TutorialScenario: invalid intro step type: ${step.type}`);
      }
    }
    for (const step of this.anchor_guidance) {
      if (!STEP_TYPES.has(step.type)) {
        throw new Error(`TutorialScenario: invalid anchor guidance step type: ${step.type}`);
      }
    }
    for (const step of this.completion_sequence) {
      if (!STEP_TYPES.has(step.type)) {
        throw new Error(`TutorialScenario: invalid completion step type: ${step.type}`);
      }
    }
    if (this.echoes.length === 0) {
      throw new Error('TutorialScenario: at least one echo required');
    }
    if (!this.anchor_blueprint_id) {
      throw new Error('TutorialScenario: anchor_blueprint_id required');
    }
  }

  getTotalSteps() {
    return this.intro_sequence.length + 1 + this.anchor_guidance.length + this.completion_sequence.length;
  }

  getStepAtIndex(index) {
    if (typeof index !== 'number' || index < 0) return null;
    if (index < this.intro_sequence.length) {
      return { phase: 'intro', step: this.intro_sequence[index], global_index: index };
    }
    const introOffset = this.intro_sequence.length;
    if (index === introOffset) {
      return { phase: 'anchor_intro', step: this.anchor_intro, global_index: index };
    }
    const anchorIntroOffset = introOffset + 1;
    const anchorEnd = anchorIntroOffset + this.anchor_guidance.length;
    if (index < anchorEnd) {
      const stepIdx = index - anchorIntroOffset;
      return { phase: 'anchor_guidance', step: this.anchor_guidance[stepIdx], global_index: index };
    }
    const completionOffset = anchorEnd;
    const completionIdx = index - completionOffset;
    if (completionIdx < this.completion_sequence.length) {
      return { phase: 'completion', step: this.completion_sequence[completionIdx], global_index: index };
    }
    return null;
  }

  getStepById(stepId) {
    for (const s of this.intro_sequence) if (s.step_id === stepId) return { phase: 'intro', step: s };
    if (this.anchor_intro && this.anchor_intro.step_id === stepId) return { phase: 'anchor_intro', step: this.anchor_intro };
    for (const s of this.anchor_guidance) if (s.step_id === stepId) return { phase: 'anchor_guidance', step: s };
    for (const s of this.completion_sequence) if (s.step_id === stepId) return { phase: 'completion', step: s };
    return null;
  }

  validateShardForStep(stepId, shardId, shardTimeline) {
    const found = this.getStepById(stepId);
    if (!found) return { ok: false, reason: 'unknown_step' };
    const validation = found.step.validation;
    if (!validation) return { ok: true };
    if (validation.shard_must_be_timeline && validation.shard_must_be_timeline !== shardTimeline) {
      return {
        ok: false,
        reason: 'wrong_shard_timeline',
        expected: validation.shard_must_be_timeline,
        got: shardTimeline
      };
    }
    return { ok: true };
  }
}

class TutorialProgress {
  constructor(scenario, playerId) {
    if (!scenario || !playerId) {
      throw new Error('TutorialProgress: scenario + playerId required');
    }
    this.scenario = scenario;
    this.player_id = playerId;
    this.session_id = crypto.randomUUID();
    this.current_step_index = 0;
    this.started_at = Date.now();
    this.completed_at = null;
    this.failed_at = null;
    this.dropped_at_step = null;
    this.first_attempt = true;
    this.events = [];
    this.echoes_resolved = [];
    this.shards_placed = [];
  }

  advance() {
    const total = this.scenario.getTotalSteps();
    if (this.current_step_index + 1 >= total) {
      this.completed_at = Date.now();
      return { ok: true, completed: true };
    }
    this.current_step_index += 1;
    this.events.push({ type: 'advance', step_index: this.current_step_index, ts: Date.now() });
    return { ok: true, step: this.scenario.getStepAtIndex(this.current_step_index) };
  }

  recordEchoResolved(echoId, choice, outcome) {
    this.echoes_resolved.push({ echo_id: echoId, choice, outcome, ts: Date.now() });
    this.events.push({ type: 'echo_resolved', echo_id: echoId, choice, outcome });
  }

  recordShardPlaced(shardId, slotIndex) {
    this.shards_placed.push({ shard_id: shardId, slot_index: slotIndex, ts: Date.now() });
    this.events.push({ type: 'shard_placed', shard_id: shardId, slot_index: slotIndex });
  }

  fail(reason) {
    this.failed_at = Date.now();
    this.dropped_at_step = this.current_step_index;
    this.events.push({ type: 'fail', reason, ts: Date.now() });
    return { ok: true };
  }

  setFirstAttempt(value) {
    this.first_attempt = !!value;
  }

  getCurrentStep() {
    return this.scenario.getStepAtIndex(this.current_step_index);
  }

  getDurationSeconds() {
    const endTs = this.completed_at || this.failed_at || Date.now();
    return Math.floor((endTs - this.started_at) / 1000);
  }

  isComplete() {
    return this.completed_at !== null;
  }

  isFailed() {
    return this.failed_at !== null;
  }

  toJSON() {
    return {
      session_id: this.session_id,
      player_id: this.player_id,
      scenario_id: this.scenario.scenario_id,
      current_step_index: this.current_step_index,
      total_steps: this.scenario.getTotalSteps(),
      started_at: this.started_at,
      completed_at: this.completed_at,
      failed_at: this.failed_at,
      dropped_at_step: this.dropped_at_step,
      duration_seconds: this.getDurationSeconds(),
      first_attempt: this.first_attempt,
      echoes_resolved_count: this.echoes_resolved.length,
      shards_placed_count: this.shards_placed.length,
      events: this.events.length
    };
  }
}

module.exports = { TutorialScenario, TutorialProgress };
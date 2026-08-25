/**
 * Room — single authoritative match session
 * Holds: players, scenario state, echo engine, catastrophe timer, causal log
 */
'use strict';

const crypto = require('crypto');
const EchoEngine = require('../simulation/EchoEngine');

class Room {
  constructor({ id, code, scenario, hostUid, maxPlayers, matchDurationSeconds, disconnectGraceSeconds, logger }) {
    this.id = id;
    this.code = code;
    this.scenario = scenario;
    this.hostUid = hostUid;
    this.maxPlayers = maxPlayers;
    this.matchDurationSeconds = matchDurationSeconds;
    this.disconnectGraceSeconds = disconnectGraceSeconds;
    this.logger = logger;

    this.players = []; // [{ uid, socketId, displayName, language, timeline, isHost, isReady, x, y, dir, disconnected, disconnectTime, inventory, playedEchoes }]
    this.hasStarted = false;
    this.startedAt = null;
    this.endedAt = null;
    this.outcome = null;

    // Authoritative scenario state — copied from scenario definition
    this.state = JSON.parse(JSON.stringify(scenario.timelines_initial_state || {}));
    this.state._system = {
      catastrophe_timer_ms: scenario.catastrophe?.duration_seconds
        ? scenario.catastrophe.duration_seconds * 1000
        : matchDurationSeconds * 1000,
      stability: 100,
      current_stage: 'stable',
    };

    this.echoEngine = new EchoEngine({
      rules: scenario.echo_rules || [],
      logger,
    });

    this.eventLog = []; // causal history for recap
    this.seqCounter = 0;
    this.createdAt = Date.now();
    this.lastActivity = Date.now();
  }

  // ============= Player management =============
  addPlayer({ socketId, uid, displayName, language, isHost = false }) {
    if (this.players.length >= this.maxPlayers) throw new Error('Room is full');
    if (this.players.find(p => p.uid === uid)) throw new Error('Player already in room');

    const timeline = this.assignNextTimeline();
    const player = {
      uid,
      socketId,
      displayName: String(displayName || 'Player').substring(0, 32),
      language: ['en', 'ar'].includes(language) ? language : 'en',
      timeline,
      isHost,
      isReady: false,
      x: 400,
      y: 300,
      dir: 0,
      inventory: [],
      playedEchoes: [],
      disconnected: false,
      disconnectTime: 0,
      joinedAt: Date.now(),
    };
    this.players.push(player);
    this.lastActivity = Date.now();
    return { success: true, timeline };
  }

  assignNextTimeline() {
    const taken = new Set(this.players.map(p => p.timeline).filter(Boolean));
    const preferred = ['past', 'present', 'future'];
    for (const tl of preferred) if (!taken.has(tl)) return tl;
    return 'past';
  }

  assignTimeline(uid, timeline) {
    if (!['past', 'present', 'future'].includes(timeline)) return { success: false, error: 'Invalid timeline' };
    const player = this.getPlayer(uid);
    if (!player) return { success: false, error: 'Player not found' };
    if (player.timeline === timeline) return { success: true, timeline };
    // Allow swapping only if no one else has the requested timeline
    const conflict = this.players.find(p => p.uid !== uid && p.timeline === timeline);
    if (conflict) return { success: false, error: 'Timeline already taken' };
    player.timeline = timeline;
    this.lastActivity = Date.now();
    return { success: true, timeline };
  }

  removePlayer(uid) {
    const idx = this.players.findIndex(p => p.uid === uid);
    if (idx < 0) return false;
    const removed = this.players.splice(idx, 1)[0];
    // If host left, transfer host
    if (removed.isHost && this.players.length > 0) {
      this.players[0].isHost = true;
    }
    return true;
  }

  getPlayer(uid) { return this.players.find(p => p.uid === uid); }
  isHost(uid) { const p = this.getPlayer(uid); return p && p.isHost; }
  isFull() { return this.players.length >= this.maxPlayers; }
  isEmpty() { return this.players.length === 0; }

  setReady(uid, ready) {
    const p = this.getPlayer(uid);
    if (p) p.isReady = ready;
    this.lastActivity = Date.now();
  }

  fillWithBots() {
    const taken = new Set(this.players.map(p => p.timeline).filter(Boolean));
    const available = ['past', 'present', 'future'].filter(t => !taken.has(t));
    const botNames = ['Aria (Bot)', 'Kael (Bot)', 'Zara (Bot)'];
    for (let i = 0; i < available.length && this.players.length < this.maxPlayers; i++) {
      this.players.push({
        uid: 'bot_' + crypto.randomBytes(4).toString('hex'),
        socketId: null,
        displayName: botNames[i % botNames.length],
        language: 'en',
        timeline: available[i],
        isHost: false,
        isReady: true,
        x: 400 + i * 40, y: 300 + i * 40, dir: 0,
        inventory: [],
        playedEchoes: [],
        disconnected: false,
        disconnectTime: 0,
        isBot: true,
        botPersonality: ['cautious', 'aggressive', 'support'][i] || 'support',
        joinedAt: Date.now(),
      });
    }
    this.lastActivity = Date.now();
  }

  // ============= Match control =============
  canStart() {
    return this.players.length >= 2 &&
      this.players.every(p => p.isReady) &&
      !this.hasStarted;
  }

  startMatch() {
    if (!this.canStart()) throw new Error('Cannot start match');
    this.hasStarted = true;
    this.startedAt = Date.now();
    this.recordEvent('match_started', { players: this.players.length, scenario: this.scenario.id });
  }

  updatePlayerPosition(uid, x, y, dir) {
    const p = this.getPlayer(uid);
    if (!p) return;
    p.x = Math.max(0, Math.min(800, x));
    p.y = Math.max(0, Math.min(600, y));
    if (typeof dir === 'number') p.dir = dir;
    this.lastActivity = Date.now();
  }

  // ============= Interaction & Echo =============
  handleInteraction(playerUid, entityId, action) {
    if (!this.hasStarted) return { success: false, error: 'Match not started' };
    const player = this.getPlayer(playerUid);
    if (!player) return { success: false, error: 'Player not found' };

    // 1. Find entity in player's timeline
    const tlState = this.state[player.timeline];
    if (!tlState) return { success: false, error: 'Invalid timeline' };

    // 2. Find matching echo rule
    const echoRule = this.echoEngine.findRule({
      sourceTimeline: player.timeline,
      sourceEntity: entityId,
      triggerAction: action,
    });
    if (!echoRule) return { success: false, error: 'Action not allowed here' };

    // 3. Validate preconditions
    const preCheck = this.echoEngine.checkPreconditions(echoRule, this);
    if (!preCheck.passed) return { success: false, error: preCheck.reason };

    // 4. Check conflicts (other rules that target same entity with different outcome)
    const conflict = this.echoEngine.checkConflict(echoRule, this);
    if (conflict) return { success: false, error: conflict.reason };

    // 5. Apply effects (with delays)
    const applied = this.echoEngine.applyEffects(echoRule, this, playerUid);

    // 6. Mark echo as played
    player.playedEchoes.push(echoRule.id);

    // 7. Log for recap
    this.recordEvent('echo', {
      ruleId: echoRule.id,
      sourceTimeline: player.timeline,
      sourceEntity: entityId,
      action,
      playerUid,
      effects: applied.effects,
      ts: Date.now(),
    });

    // 8. Recalculate catastrophe
    this.updateCatastrophe();

    // 9. Check win/loss
    const outcome = this.checkOutcome();
    if (outcome) this.endMatch(outcome);

    this.lastActivity = Date.now();
    return { success: true, echo: echoRule.id, effects: applied.effects };
  }

  updateCatastrophe() {
    // Decay timer
    if (this.hasStarted && this.state._system.catastrophe_timer_ms > 0) {
      this.state._system.catastrophe_timer_ms = Math.max(0, this.state._system.catastrophe_timer_ms - 1000);
    }
    // Recalculate stability based on progress
    const progress = this.calculateProgress();
    this.state._system.stability = progress;
    // Update stage
    const stages = this.scenario.catastrophe?.stages || [
      { name: 'stable', threshold_pct: 100 },
      { name: 'destabilizing', threshold_pct: 75 },
      { name: 'critical', threshold_pct: 35 },
      { name: 'imminent_collapse', threshold_pct: 10 },
    ];
    let currentStage = 'stable';
    for (const stage of stages) {
      if (progress <= stage.threshold_pct) currentStage = stage.name;
    }
    this.state._system.current_stage = currentStage;
  }

  calculateProgress() {
    // Heuristic: stability = 100 - decay; decay driven by missing objectives
    const objectives = this.scenario.win_conditions?.[0]?.requirements || [];
    if (objectives.length === 0) return 100;
    let done = 0;
    for (const req of objectives) {
      if (this.evaluateCondition(req)) done++;
    }
    return Math.round((done / objectives.length) * 100);
  }

  evaluateCondition(cond) {
    if (cond.timeline === 'system') {
      if (cond.entity === 'catastrophe' && cond.property === 'timer_remaining_ms') {
        return this.state._system.catastrophe_timer_ms > cond.value;
      }
      return false;
    }
    const tlState = this.state[cond.timeline];
    if (!tlState) return false;
    const entity = tlState[cond.entity];
    if (!entity) return false;
    const val = entity[cond.property];
    switch (cond.operator) {
      case '==': return val == cond.value;
      case '!=': return val != cond.value;
      case '>': return val > cond.value;
      case '<': return val < cond.value;
      case '>=': return val >= cond.value;
      case '<=': return val <= cond.value;
      default: return false;
    }
  }

  checkOutcome() {
    if (this.state._system.catastrophe_timer_ms <= 0) {
      return { id: 'temporal_erasure', outcome_key: 'outcome.temporal_erasure', grade: 'loss', causalLog: this.eventLog };
    }
    for (const cond of this.scenario.win_conditions || []) {
      if ((cond.requirements || []).every(r => this.evaluateCondition(r))) {
        return { id: cond.id, outcome_key: cond.outcome_key, grade: cond.grade, causalLog: this.eventLog };
      }
    }
    return null;
  }

  endMatch(outcome) {
    this.hasStarted = false;
    this.endedAt = Date.now();
    this.outcome = outcome;
    this.recordEvent('match_ended', outcome);
    this.logger.info({ roomId: this.id, code: this.code, outcome: outcome.id }, 'Match ended');
  }

  markDisconnected(uid, reason) {
    const p = this.getPlayer(uid);
    if (!p) return;
    p.disconnected = true;
    p.disconnectTime = Date.now();
    this.recordEvent('player_disconnected', { uid, reason });
  }

  // ============= Helpers =============
  nextSeq() { return ++this.seqCounter; }

  recordEvent(type, data) {
    this.eventLog.push({ seq: this.nextSeq(), type, data, ts: Date.now() });
    if (this.eventLog.length > 200) this.eventLog.shift();
  }

  shouldCleanup() {
    if (this.endedAt && Date.now() - this.endedAt > 5 * 60 * 1000) return true;
    if (this.isEmpty()) return true;
    if (Date.now() - this.lastActivity > 30 * 60 * 1000) return true;
    return false;
  }

  tick(now) {
    if (!this.hasStarted) return;
    this.updateCatastrophe();
    // Drive bot AI
    for (const p of this.players) {
      if (p.isBot && Math.random() < 0.15) {
        this.botThink(p);
      }
    }
    const outcome = this.checkOutcome();
    if (outcome) this.endMatch(outcome);
  }

  botThink(bot) {
    // Simple heuristic: try next un-played echo in bot's timeline
    const candidates = (this.scenario.echo_rules || []).filter(r =>
      r.source_timeline === bot.timeline &&
      !bot.playedEchoes.includes(r.id)
    );
    if (candidates.length === 0) return;
    const rule = candidates[0];
    const check = this.echoEngine.checkPreconditions(rule, this);
    if (check.passed) {
      this.handleInteraction(bot.uid, rule.source_entity, rule.trigger_action);
    }
  }

  // ============= Serialization =============
  publicState() {
    return {
      id: this.id,
      code: this.code,
      scenarioId: this.scenario.id,
      scenarioNameKey: this.scenario.name_key,
      maxPlayers: this.maxPlayers,
      hasStarted: this.hasStarted,
      startedAt: this.startedAt,
      endedAt: this.endedAt,
      players: this.players.map(p => ({
        uid: p.uid,
        displayName: p.displayName,
        language: p.language,
        timeline: p.timeline,
        isHost: p.isHost,
        isReady: p.isReady,
        disconnected: p.disconnected,
        isBot: !!p.isBot,
      })),
      supportedTimelines: this.scenario.supported_timelines || [],
    };
  }

  playerView(uid) {
    const player = this.getPlayer(uid);
    if (!player) return null;
    return {
      matchId: this.id,
      scenarioId: this.scenario.id,
      scenario: {
        id: this.scenario.id,
        nameKey: this.scenario.name_key,
        descriptionKey: this.scenario.description_key,
        supportedTimelines: this.scenario.supported_timelines,
        catastrophe: this.scenario.catastrophe,
      },
      you: {
        uid: player.uid,
        timeline: player.timeline,
        language: player.language,
        x: player.x, y: player.y, dir: player.dir,
        inventory: player.inventory,
      },
      players: this.players.map(p => ({
        uid: p.uid,
        displayName: p.displayName,
        language: p.language,
        timeline: p.timeline,
        isBot: !!p.isBot,
        disconnected: p.disconnected,
        x: p.x, y: p.y, dir: p.dir,
      })),
      state: {
        your_timeline: this.state[player.timeline],
        other_timelines_summary: this.summarizeOtherTimelines(player.timeline),
        system: this.state._system,
      },
      eventLog: this.eventLog.slice(-50),
      durationSeconds: this.matchDurationSeconds,
    };
  }

  summarizeOtherTimelines(myTimeline) {
    const out = {};
    for (const tl of Object.keys(this.state)) {
      if (tl === '_system' || tl === myTimeline) continue;
      const tlState = this.state[tl];
      out[tl] = {
        entityCount: Object.keys(tlState).length,
        // Don't leak full state — only public-facing indicators
        hint: this.scenario.timelines_initial_state[tl] ? Object.keys(tlState).slice(0, 5) : [],
      };
    }
    return out;
  }
}

module.exports = Room;
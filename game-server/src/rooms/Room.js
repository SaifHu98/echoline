/**
 * Room — single authoritative match session
 * -----------------------------------------
 * يحمل:
 * - اللاعبين + الحالة الكاملة للسيناريو
 * - الـ EchoEngine + dependency graph
 * - سجل السبب والنتيجة (causal log)
 * - اللقطات الدورية + استعادة الاتصال
 * - صعوبة تكيفية + نظام تلميحات
 */

'use strict';

const crypto = require('crypto');
const EchoEngine = require('../simulation/EchoEngine');
const { COMPARATORS } = EchoEngine;

const SNAPSHOT_INTERVAL_MS = 5_000;
const MAX_INTERACTIONS_PER_SECOND = 3;
const RECONNECT_GRACE_MS_DEFAULT = 30_000;
const HINT_BASE_COOLDOWN_MS = 18_000;
const HINT_FAILURE_BACKOFF_MS = 8_000;

class Room {
  constructor({ id, code, scenario, hostUid, maxPlayers, matchDurationSeconds, disconnectGraceSeconds, logger, adaptiveDifficulty = true }) {
    this.id = id;
    this.code = code;
    this.scenario = scenario;
    this.hostUid = hostUid;
    this.maxPlayers = maxPlayers;
    this.matchDurationSeconds = matchDurationSeconds;
    this.disconnectGraceSeconds = disconnectGraceSeconds || RECONNECT_GRACE_MS_DEFAULT;
    this.logger = logger;
    this.adaptiveDifficulty = adaptiveDifficulty;

    this.players = [];
    this.hasStarted = false;
    this.startedAt = null;
    this.endedAt = null;
    this.outcome = null;

    // ===== Authoritative state =====
    this.state = deepClone(scenario.timelines_initial_state || {});
    this.state._system = {
      catastrophe_timer_ms: (scenario.catastrophe?.duration_seconds || matchDurationSeconds) * 1000,
      stability: 100,
      current_stage: 'stable',
      difficulty_multiplier: 1.0,
      cooperative_score: 0,
    };

    // ===== Echo engine with full causal graph =====
    this.echoEngine = new EchoEngine({
      rules: scenario.echo_rules || [],
      logger,
      scenario,
    });

    // ===== Causal log (deterministic, monotonic seq) =====
    this.seqCounter = 0;
    this.eventLog = [];

    // ===== Idempotency cache =====
    // كل (playerUid, idempotencyKey) → { result, ts }
    // TTL محدود لتفادي استهلاك الذاكرة
    this.idempotencyCache = new Map();
    this.idempotencyTtlMs = 5 * 60_000;

    // ===== Anti-tampering per player =====
    this.rateLimitByPlayer = new Map(); // playerUid → { tsWindow: [], failureCount }

    // ===== Scheduled (delayed) effects =====
    this.scheduledEffects = [];

    // ===== Snapshots for reconciliation =====
    this.snapshots = []; // [{ seq, ts, state, eventLogTail, appliedEchoes }]
    this.lastSnapshotAt = 0;

    // ===== Hints per player (gradual hints system) =====
    // Map<playerUid, Map<ruleId, hintLevel>>
    this.playerHints = new Map();
    this.lastHintRequestAt = new Map();

    // ===== Adaptive difficulty =====
    this.teamPerformance = {
      totalInteractions: 0,
      successfulInteractions: 0,
      failedInteractions: 0,
      recentResults: [], // آخر 10 نتائج
      avgResponseMs: 0,
      lastAdjustmentAt: 0,
    };

    this.createdAt = Date.now();
    this.lastActivity = Date.now();
    this.appliedEchoes = new Set(); // rule IDs played
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
      language: ['en', 'ar', 'qps_mirrored', 'qps_expanded'].includes(language) ? language : 'en',
      timeline,
      isHost,
      isReady: false,
      x: 400, y: 300, dir: 0,
      inventory: [],
      playedEchoes: [],
      disconnected: false,
      disconnectTime: 0,
      isBot: false,
      joinedAt: Date.now(),
      // Anti-tampering
      rateWindow: [],
      failureCount: 0,
    };
    this.players.push(player);
    this.playerHints.set(uid, new Map());
    this.lastActivity = Date.now();
    return { success: true, timeline };
  }

  assignNextTimeline() {
    const taken = new Set(this.players.map(p => p.timeline).filter(Boolean));
    for (const tl of ['past', 'present', 'future']) if (!taken.has(tl)) return tl;
    return 'past';
  }

  assignTimeline(uid, timeline) {
    if (!['past', 'present', 'future'].includes(timeline)) {
      return { success: false, error: 'Invalid timeline', code: 'INVALID_TIMELINE' };
    }
    const player = this.getPlayer(uid);
    if (!player) return { success: false, error: 'Player not found', code: 'NO_PLAYER' };
    if (player.timeline === timeline) return { success: true, timeline };
    const conflict = this.players.find(p => p.uid !== uid && p.timeline === timeline);
    if (conflict) return { success: false, error: 'Timeline already taken', code: 'TIMELINE_TAKEN' };
    player.timeline = timeline;
    this.lastActivity = Date.now();
    return { success: true, timeline };
  }

  removePlayer(uid) {
    const idx = this.players.findIndex(p => p.uid === uid);
    if (idx < 0) return false;
    const removed = this.players.splice(idx, 1)[0];
    if (removed.isHost && this.players.length > 0) this.players[0].isHost = true;
    this.playerHints.delete(uid);
    this.lastHintRequestAt.delete(uid);
    return true;
  }

  getPlayer(uid) { return this.players.find(p => p.uid === uid); }
  isHost(uid) { const p = this.getPlayer(uid); return !!(p && p.isHost); }
  isFull() { return this.players.length >= this.maxPlayers; }
  isEmpty() { return this.players.length === 0; }

  setReady(uid, ready) {
    const p = this.getPlayer(uid);
    if (!p) return false;
    p.isReady = !!ready;
    this.lastActivity = Date.now();
    return true;
  }

  fillWithBots() {
    const taken = new Set(this.players.map(p => p.timeline).filter(Boolean));
    const available = ['past', 'present', 'future'].filter(t => !taken.has(t));
    const botNames = ['Aria', 'Kael', 'Zara'];
    for (let i = 0; i < available.length && this.players.length < this.maxPlayers; i++) {
      const botUid = 'bot_' + crypto.randomBytes(4).toString('hex');
      this.players.push({
        uid: botUid,
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
        rateWindow: [],
        failureCount: 0,
      });
      this.playerHints.set(botUid, new Map());
    }
    this.lastActivity = Date.now();
  }

  // ============= Reconnection =============
  /**
   * عند انقطاع اتصال لاعب ثم عودته بنفس socketId أو uid.
   * نستعيد حالته بدون فقدان playedEchoes أو inventory أو الموقع.
   */
  reconnectPlayer({ uid, newSocketId }) {
    const player = this.getPlayer(uid);
    if (!player) return { success: false, error: 'Player not found' };
    if (!player.disconnected && player.socketId !== newSocketId) {
      return { success: false, error: 'Player already connected elsewhere', code: 'ALREADY_CONNECTED' };
    }
    player.socketId = newSocketId;
    player.disconnected = false;
    player.disconnectTime = 0;
    this.lastActivity = Date.now();

    // أعد الحالة بدون إعادة تطبيق أي تأثيرات — اللاعب يعود لما رآه
    const view = this.playerView(uid);
    return {
      success: true,
      reconnected: true,
      view,
      snapshot: this.latestSnapshot(),
    };
  }

  // ============= Match control =============
  canStart() {
    return this.players.length >= 2 &&
      this.players.filter(p => !p.isBot).every(p => p.isReady) &&
      !this.hasStarted;
  }

  startMatch() {
    if (!this.canStart()) throw new Error('Cannot start match');
    this.hasStarted = true;
    this.startedAt = Date.now();
    this.recordEvent('match_started', {
      players: this.players.length,
      scenario: this.scenario.id,
      ts: Date.now(),
    });
    this.lastSnapshotAt = Date.now();
  }

  // ============= Anti-tampering =============
  _checkRateLimit(playerUid) {
    const p = this.getPlayer(playerUid);
    if (!p) return { ok: false, reason: 'NO_PLAYER' };
    const now = Date.now();
    // نافذة 1 ثانية
    p.rateWindow = p.rateWindow.filter(t => now - t < 1000);
    if (p.rateWindow.length >= MAX_INTERACTIONS_PER_SECOND) {
      return { ok: false, reason: 'RATE_LIMITED', code: 'RATE_LIMIT' };
    }
    return { ok: true };
  }

  _recordRate(playerUid) {
    const p = this.getPlayer(playerUid);
    if (!p) return;
    p.rateWindow.push(Date.now());
  }

  _checkIdempotency(playerUid, idempotencyKey) {
    if (!idempotencyKey) return { isReplay: false };
    const k = `${playerUid}::${idempotencyKey}`;
    const cached = this.idempotencyCache.get(k);
    if (!cached) return { isReplay: false };
    if (Date.now() - cached.ts > this.idempotencyTtlMs) {
      this.idempotencyCache.delete(k);
      return { isReplay: false };
    }
    return { isReplay: true, result: cached.result };
  }

  _recordIdempotency(playerUid, idempotencyKey, result) {
    if (!idempotencyKey) return;
    const k = `${playerUid}::${idempotencyKey}`;
    this.idempotencyCache.set(k, { result, ts: Date.now() });
    // تنظيف قديمي
    if (this.idempotencyCache.size > 5000) {
      const cutoff = Date.now() - this.idempotencyTtlMs;
      for (const [key, val] of this.idempotencyCache) {
        if (val.ts < cutoff) this.idempotencyCache.delete(key);
      }
    }
  }

  // ============= Interaction (the hot path) =============
  handleInteraction(playerUid, { entityId, action, idempotencyKey = null, ruleId = null, clientSeq = null }) {
    if (!this.hasStarted) return { success: false, error: 'Match not started', code: 'NOT_STARTED' };
    const player = this.getPlayer(playerUid);
    if (!player) return { success: false, error: 'Player not found', code: 'NO_PLAYER' };

    // 1) Idempotency replay
    const replay = this._checkIdempotency(playerUid, idempotencyKey);
    if (replay.isReplay) {
      return { ...replay.result, replayed: true };
    }

    // 2) Rate limit
    const rl = this._checkRateLimit(playerUid);
    if (!rl.ok) {
      return { success: false, error: 'Too many requests', code: rl.code || rl.reason };
    }
    this._recordRate(playerUid);

    // 3) Validate timeline + entity exists
    const tlState = this.state[player.timeline];
    if (!tlState) return { success: false, error: 'Invalid timeline state', code: 'INVALID_STATE' };
    if (!tlState[entityId]) {
      return { success: false, error: 'Entity not in your timeline', code: 'ENTITY_NOT_FOUND' };
    }

    // 4) Find rule (optionally by id for reconciliation)
    const echoRule = this.echoEngine.findRule({
      sourceTimeline: player.timeline,
      sourceEntity: entityId,
      triggerAction: action,
      ruleId,
    });
    if (!echoRule) {
      return { success: false, error: 'Action not allowed here', code: 'NO_RULE' };
    }

    // 5) Preconditions
    const ctx = this._buildCtx(player);
    const pre = this.echoEngine.checkPreconditions(echoRule, ctx);
    if (!pre.passed) {
      this._recordFailure(player);
      const failure = {
        success: false,
        error: pre.failures[0]?.reason || 'precondition_failed',
        code: 'PRECONDITION_FAILED',
        details: pre.failures,
      };
      this._recordIdempotency(playerUid, idempotencyKey, failure);
      return failure;
    }

    // 6) Conflict
    const conflict = this.echoEngine.checkConflict(echoRule, ctx);
    if (conflict) {
      const failure = {
        success: false,
        error: conflict.message,
        code: 'CONFLICT',
      };
      this._recordIdempotency(playerUid, idempotencyKey, failure);
      return failure;
    }

    // 7) Player permissions — لا يمكن للاعب تفعيل قاعدة ليست في خط الزمني الخاص به
    if (echoRule.source_timeline !== player.timeline) {
      return { success: false, error: 'You can only act on your timeline', code: 'WRONG_TIMELINE' };
    }

    // 8) Apply
    const applied = this.echoEngine.applyEffects(echoRule, ctx, playerUid);
    player.playedEchoes.push(echoRule.id);
    this.appliedEchoes.add(echoRule.id);

    // 9) Adaptive difficulty nudge
    this._recordSuccess(player);

    // 10) Record event
    this.recordEvent('echo_played', {
      seq: this.nextSeq(),
      ruleId: echoRule.id,
      sourceTimeline: player.timeline,
      sourceEntity: entityId,
      action,
      playerUid,
      clientSeq,
      ts: Date.now(),
    });

    // 11) Recompute catastrophe
    this.updateCatastrophe();

    // 12) Check outcome
    const outcome = this.checkOutcome();
    if (outcome) this.endMatch(outcome);

    this.lastActivity = Date.now();

    const successResult = {
      success: true,
      echo: echoRule.id,
      effects: applied.immediate,
      scheduled: applied.scheduled.length,
      seq: this.seqCounter,
    };
    this._recordIdempotency(playerUid, idempotencyKey, successResult);
    return successResult;
  }

  _buildCtx(player) {
    return {
      state: this.state,
      player,
      appliedEchoes: this.appliedEchoes,
      scheduledEffects: this.scheduledEffects,
      logger: this.logger,
      now: () => Date.now(),
      elapsedSeconds: () => Math.floor((Date.now() - (this.startedAt || Date.now())) / 1000),
      recordEvent: (type, data) => this.recordEvent(type, data),
      playerHints: this.playerHints,
    };
  }

  _recordFailure(player) {
    player.failureCount++;
    this.teamPerformance.failedInteractions++;
    this._pushRecentResult(false);
    this._maybeAdjustDifficulty();
  }

  _recordSuccess(player) {
    player.failureCount = Math.max(0, player.failureCount - 1);
    this.teamPerformance.successfulInteractions++;
    this._pushRecentResult(true);
    this._maybeAdjustDifficulty();
  }

  _pushRecentResult(success) {
    this.teamPerformance.recentResults.push(success);
    if (this.teamPerformance.recentResults.length > 10) {
      this.teamPerformance.recentResults.shift();
    }
    this.teamPerformance.totalInteractions++;
  }

  /**
   * صعوبة تكيفية: لا تعتمد على وقت اللعبة بل على أداء الفريق.
   * - فشل متتالٍ → تخفيف (multiplier < 1) يعني أهداف/شروط أبسط
   * - نجاح متتالٍ → تشديد معتدل (multiplier > 1) يعني أهداف أصعب
   * - لا شيء قاسي — التغيير ±15% فقط، ولا يطبق إلا كل 30 ثانية.
   */
  _maybeAdjustDifficulty() {
    if (!this.adaptiveDifficulty) return;
    const now = Date.now();
    if (now - this.teamPerformance.lastAdjustmentAt < 30_000) return;
    const recent = this.teamPerformance.recentResults;
    if (recent.length < 5) return;
    const successes = recent.filter(Boolean).length;
    const rate = successes / recent.length;
    let mult = this.state._system.difficulty_multiplier;
    if (rate < 0.4) mult = Math.max(0.7, mult - 0.08);
    else if (rate > 0.85) mult = Math.min(1.25, mult + 0.05);
    if (mult !== this.state._system.difficulty_multiplier) {
      this.state._system.difficulty_multiplier = mult;
      this.teamPerformance.lastAdjustmentAt = now;
      this.recordEvent('difficulty_adjusted', { multiplier: mult, successRate: rate });
    }
  }

  // ============= Catastrophe =============
  updateCatastrophe() {
    if (this.hasStarted && this.state._system.catastrophe_timer_ms > 0) {
      this.state._system.catastrophe_timer_ms = Math.max(0, this.state._system.catastrophe_timer_ms - 1000);
    }
    const progress = this.calculateProgress();
    this.state._system.stability = progress;

    const stages = this.scenario.catastrophe?.stages || [
      { name: 'stable', threshold_pct: 100 },
      { name: 'destabilizing', threshold_pct: 75 },
      { name: 'critical', threshold_pct: 35 },
      { name: 'imminent_collapse', threshold_pct: 10 },
    ];
    let cur = 'stable';
    for (const stage of stages) {
      if (progress <= stage.threshold_pct) cur = stage.name;
    }
    this.state._system.current_stage = cur;
    // cooperative_score يحدّث بناءً على إنجازات مشتركة
    this.state._system.cooperative_score = this._computeCooperativeScore();
  }

  calculateProgress() {
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
        const op = cond.operator || '>';
        const fn = COMPARATORS[op] || ((a, b) => a > b);
        return fn(this.state._system.catastrophe_timer_ms, cond.value);
      }
      return false;
    }
    const tlState = this.state[cond.timeline];
    if (!tlState) return false;
    const entity = tlState[cond.entity];
    if (!entity) return false;
    const val = entity[cond.property];
    const op = cond.operator || '==';
    const fn = COMPARATORS[op] || ((a, b) => a == b);
    return fn(val, cond.value);
  }

  _computeCooperativeScore() {
    // كل لاعب ساهم بقاعدة → نقطة. تعديل الصعوبة يؤثر.
    const base = this.appliedEchoes.size * 10;
    const mult = this.state._system.difficulty_multiplier || 1.0;
    return Math.round(base * mult);
  }

  checkOutcome() {
    if (this.state._system.catastrophe_timer_ms <= 0) {
      // يمكن استرداد الفشل إذا كان لدى الفريق تقدم كافٍ
      const recoveryChance = this._recoveryChance();
      if (recoveryChance > 0 && Math.random() < recoveryChance) {
        return null; // فرصة استرداد
      }
      return {
        id: 'temporal_erasure',
        outcome_key: 'outcome.temporal_erasure',
        grade: 'loss',
        causalLog: this.eventLog.slice(-100),
        recoveryAttemptsLeft: 0,
      };
    }
    for (const cond of this.scenario.win_conditions || []) {
      if ((cond.requirements || []).every(r => this.evaluateCondition(r))) {
        return {
          id: cond.id,
          outcome_key: cond.outcome_key,
          grade: cond.grade,
          causalLog: this.eventLog.slice(-100),
        };
      }
    }
    return null;
  }

  _recoveryChance() {
    // إذا كان cooperative_score عالي، فرصة لاسترداد الفشل
    const score = this.state._system.cooperative_score || 0;
    if (score > 200) return 0.5;
    if (score > 100) return 0.25;
    if (score > 50) return 0.1;
    return 0;
  }

  endMatch(outcome) {
    this.hasStarted = false;
    this.endedAt = Date.now();
    this.outcome = outcome;
    this.recordEvent('match_ended', outcome);
    this._takeSnapshot();
  }

  markDisconnected(uid, reason) {
    const p = this.getPlayer(uid);
    if (!p) return;
    p.disconnected = true;
    p.disconnectTime = Date.now();
    this.recordEvent('player_disconnected', { uid, reason });
  }

  // ============= Quick message & ping =============
  handleQuickMessage(playerUid, { intent, code, data }) {
    const player = this.getPlayer(playerUid);
    if (!player) return null;
    if (!intent || typeof intent !== 'string') return null;
    const msg = {
      id: crypto.randomUUID(),
      seq: this.nextSeq(),
      from: {
        uid: player.uid,
        name: player.displayName,
        timeline: player.timeline,
        language: player.language,
      },
      intent: intent.substring(0, 64),
      code: typeof code === 'string' ? code.substring(0, 64) : null,
      data: (data && typeof data === 'object') ? data : {},
      ts: Date.now(),
    };
    this.recordEvent('quick_message', msg);
    return msg;
  }

  handlePing(playerUid, { type, x, y, targetId }) {
    const player = this.getPlayer(playerUid);
    if (!player) return null;
    const ping = {
      id: crypto.randomUUID(),
      seq: this.nextSeq(),
      from: player.uid,
      fromName: player.displayName,
      fromTimeline: player.timeline,
      type: ['location', 'danger', 'help', 'object', 'echo'].includes(type) ? type : 'location',
      x: clamp(Number(x) || 0, 0, 1000),
      y: clamp(Number(y) || 0, 0, 1000),
      targetId: targetId || null,
      ts: Date.now(),
    };
    this.recordEvent('ping', ping);
    return ping;
  }

  // ============= Hints (gradual) =============
  /**
   * اطلب تلميحاً لقاعدة. المستوى يتدرج بناءً على:
   * - عدد المحاولات الفاشلة
   * - الوقت منذ آخر تلميح
   * - صعوبة الـ rule (hints مخزنة في السيناريو)
   */
  requestHint(playerUid, ruleId) {
    const player = this.getPlayer(playerUid);
    if (!player) return { success: false, error: 'No player' };
    if (!this.byId_check(ruleId)) return { success: false, error: 'Unknown rule' };

    const now = Date.now();
    const lastTs = this.lastHintRequestAt.get(`${playerUid}::${ruleId}`) || 0;
    const failureCount = player.failureCount;
    const cooldown = HINT_BASE_COOLDOWN_MS + (failureCount > 2 ? 0 : HINT_FAILURE_BACKOFF_MS);
    if (now - lastTs < cooldown) {
      return { success: false, error: 'cooldown', cooldownMsLeft: cooldown - (now - lastTs) };
    }
    this.lastHintRequestAt.set(`${playerUid}::${ruleId}`, now);

    let hintMap = this.playerHints.get(playerUid);
    if (!hintMap) {
      hintMap = new Map();
      this.playerHints.set(playerUid, hintMap);
    }
    const cur = hintMap.get(ruleId) || 0;
    const next = Math.min(3, cur + 1);
    hintMap.set(ruleId, next);

    const rule = this.echoEngine.byId.get(ruleId);
    const hints = rule?.hints || [];
    return {
      success: true,
      level: next,
      hint: hints[next - 1] || null,
      maxLevel: 3,
    };
  }

  byId_check(ruleId) {
    return this.echoEngine.byId.has(ruleId);
  }

  // ============= Snapshots & Reconciliation =============
  _takeSnapshot() {
    const snap = {
      seq: this.seqCounter,
      ts: Date.now(),
      stateHash: hashState(this.state),
      state: deepClone(this.state),
      appliedEchoes: Array.from(this.appliedEchoes),
      eventLogTail: this.eventLog.slice(-20),
    };
    this.snapshots.push(snap);
    if (this.snapshots.length > 24) this.snapshots.shift();
    this.lastSnapshotAt = Date.now();
    return snap;
  }

  latestSnapshot() {
    return this.snapshots[this.snapshots.length - 1] || null;
  }

  /**
   * إعادة الاتصال: استرجاع الحالة الكاملة + آخر seq معروف.
   * العميل يحدد lastSeqClient رأى قبل الانقطاع؛
   * نعيد الفرق بين lastSeqClient وآخر seq لتأكيده.
   */
  reconcile(playerUid, lastClientSeq) {
    const view = this.playerView(playerUid);
    const missed = this.eventLog.filter(e => (e.seq || 0) > lastClientSeq);
    return {
      view,
      missedEvents: missed,
      currentSeq: this.seqCounter,
      snapshots: this.snapshots.length,
      lastSnapshotTs: this.lastSnapshotAt,
    };
  }

  // ============= Tick =============
  tick(now) {
    if (!this.hasStarted) return;
    this.updateCatastrophe();
    this.echoEngine.applyDueScheduled(this._buildCtx(this.players[0]));

    // Bot AI
    for (const p of this.players) {
      if (p.isBot && Math.random() < 0.1) this.botThink(p);
    }

    // Periodic snapshot
    if (Date.now() - this.lastSnapshotAt > SNAPSHOT_INTERVAL_MS) {
      this._takeSnapshot();
    }

    const outcome = this.checkOutcome();
    if (outcome) this.endMatch(outcome);
  }

  botThink(bot) {
    const candidates = (this.scenario.echo_rules || []).filter(r =>
      r.source_timeline === bot.timeline &&
      !bot.playedEchoes.includes(r.id) &&
      !this.appliedEchoes.has(r.id)
    );
    if (candidates.length === 0) return;
    candidates.sort((a, b) => (a.conflict_priority || 0) - (b.conflict_priority || 0));
    const rule = candidates[0];
    const ctx = this._buildCtx(bot);
    const pre = this.echoEngine.checkPreconditions(rule, ctx);
    if (!pre.passed) return;
    this.handleInteraction(bot.uid, {
      entityId: rule.source_entity,
      action: rule.trigger_action,
      idempotencyKey: 'bot_' + bot.uid + '_' + rule.id + '_' + this.seqCounter,
    });
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
      // Procedural story manifest: every room has a unique, deterministic
      // narrative + missions + layout. Players can read this BEFORE joining
      // to see what kind of story awaits.
      storyManifest: this.storyManifest || null,
    };
  }

  /**
   * العرض المخصص للاعب: حالة خط زمني كاملة، ملخص للخطوط الأخرى،
   * اللقطات الحديثة، سجل الأحداث الأخير، صعوبة تكيفية.
   */
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
        playedEchoes: player.playedEchoes,
        failureCount: player.failureCount,
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
      currentSeq: this.seqCounter,
      durationSeconds: this.matchDurationSeconds,
      difficultyMultiplier: this.state._system.difficulty_multiplier,
    };
  }

  summarizeOtherTimelines(myTimeline) {
    const out = {};
    for (const tl of Object.keys(this.state)) {
      if (tl === '_system' || tl === myTimeline) continue;
      const tlState = this.state[tl];
      out[tl] = {
        entityCount: Object.keys(tlState).length,
        // واجهات عامة فقط — لا نكشف الحالة الكاملة
        publicHints: this.scenario.public_timeline_hints?.[tl] || [],
      };
    }
    return out;
  }

  nextSeq() {
    this.seqCounter++;
    return this.seqCounter;
  }

  recordEvent(type, data) {
    const seq = this.nextSeq();
    this.eventLog.push({ seq, type, data, ts: Date.now() });
    if (this.eventLog.length > 500) this.eventLog.shift();
    return seq;
  }

  shouldCleanup() {
    if (this.endedAt && Date.now() - this.endedAt > 5 * 60_000) return true;
    if (this.isEmpty()) return true;
    if (Date.now() - this.lastActivity > 30 * 60_000) return true;
    return false;
  }
}

function deepClone(x) { return JSON.parse(JSON.stringify(x)); }
function clamp(v, mn, mx) { return Math.max(mn, Math.min(mx, v)); }
function hashState(state) {
  // خفيف — يكفي لتأكيد التكامل
  const c = require('crypto');
  return c.createHash('sha256').update(JSON.stringify(state)).digest('hex').substring(0, 16);
}

module.exports = Room;

/**
 * EchoEngine — Deterministic Authoritative Causal Engine
 * ------------------------------------------------------
 * كل قاعدة echo هي عقدة في رسم بياني سببي. كل تفاعل يحصل على
 * seq فريد، idempotency key، و deterministic outcome.
 *
 * المبادئ:
 * 1. السيرفر وحده يقرر النتيجة — لا دخل للعميل في التأثير.
 * 2. كل تفاعل يحمل idempotency key — لا تكرار حتى لو أُرسل مرتين.
 * 3. كل قاعدة لها شرط preconditions صريح — لا تخمين.
 * 4. التأثيرات لها delays حقيقية لكن deterministic (لا عشوائية).
 * 5. الـ causal graph يبني قصة قابلة للقراءة في الـ recap.
 */

'use strict';

const crypto = require('crypto');

const COMPARATORS = {
  '==':  (a, b) => a === b,
  '!=':  (a, b) => a !== b,
  '>':   (a, b) => Number(a) >  Number(b),
  '<':   (a, b) => Number(a) <  Number(b),
  '>=':  (a, b) => Number(a) >= Number(b),
  '<=':  (a, b) => Number(a) <= Number(b),
  'in':  (a, b) => Array.isArray(b) && b.includes(a),
  'contains': (a, b) => Array.isArray(a) && a.includes(b),
};

const ACTION_KINDS = new Set(['set_property', 'add_value', 'toggle', 'remove', 'append', 'mark']);

class EchoEngine {
  constructor({ rules = [], logger = console, scenario = null } = {}) {
    this.rules = Array.isArray(rules) ? rules : [];
    this.logger = logger;
    this.scenario = scenario;
    this.index = new Map();      // (timeline::entity::action) → [rule]
    this.byId = new Map();       // rule.id → rule
    this.dependencyGraph = new Map(); // ruleId → Set(ruleIds this rule depends on)
    this.reverseGraph = new Map();    // ruleId → Set(ruleIds that depend on this)
    this._rebuild();
  }

  _rebuild() {
    this.index.clear();
    this.byId.clear();
    this.dependencyGraph.clear();
    this.reverseGraph.clear();

    for (const rule of this.rules) {
      if (!rule || !rule.id) continue;
      this.byId.set(rule.id, rule);
      const key = `${rule.source_timeline}::${rule.source_entity}::${rule.trigger_action}`;
      if (!this.index.has(key)) this.index.set(key, []);
      this.index.get(key).push(rule);

      const deps = new Set();
      for (const pre of (rule.preconditions || [])) {
        // إذا كان الـ precondition يشير لنتيجة قاعدة أخرى، اربطها
        if (pre.derived_from_rule) deps.add(pre.derived_from_rule);
      }
      this.dependencyGraph.set(rule.id, deps);
      for (const dep of deps) {
        if (!this.reverseGraph.has(dep)) this.reverseGraph.set(dep, new Set());
        this.reverseGraph.get(dep).add(rule.id);
      }
    }
  }

  /**
   * ابحث عن قاعدة مطابقة. يدعم pre-binding لتحديد rule.id مسبقاً
   * (يُستخدم عند الـ reconciliation).
   */
  findRule({ sourceTimeline, sourceEntity, triggerAction, ruleId = null }) {
    if (ruleId) return this.byId.get(ruleId) || null;
    const key = `${sourceTimeline}::${sourceEntity}::${triggerAction}`;
    const rules = this.index.get(key);
    if (!rules || rules.length === 0) return null;
    if (rules.length === 1) return rules[0];
    // الأكثر أولوية يفوز
    return rules.slice().sort((a, b) =>
      (b.conflict_priority || 0) - (a.conflict_priority || 0)
    )[0];
  }

  /**
   * تحقق صارم من الـ preconditions — يدعم النظام، الـ timeline،
   * والـ inventory للاعب.
   */
  checkPreconditions(rule, ctx) {
    const failures = [];
    for (const pre of (rule.preconditions || [])) {
      const value = this._resolveValue(pre, ctx);
      const op = pre.operator || '==';
      const target = pre.value;
      const fn = COMPARATORS[op];
      if (!fn) {
        failures.push({ reason: 'unknown_operator', operator: op });
        continue;
      }
      if (!fn(value, target)) {
        failures.push({
          reason: 'precondition_failed',
          path: `${pre.timeline}.${pre.entity}.${pre.property}`,
          expected: `${op} ${JSON.stringify(target)}`,
          actual: JSON.stringify(value),
        });
      }
    }
    return { passed: failures.length === 0, failures };
  }

  _resolveValue(pre, ctx) {
    if (pre.timeline === 'system') {
      const sys = ctx.state._system || {};
      if (pre.entity === 'catastrophe') {
        if (pre.property === 'timer_remaining_ms') return sys.catastrophe_timer_ms;
        if (pre.property === 'stability') return sys.stability;
        if (pre.property === 'current_stage') return sys.current_stage;
      }
      if (pre.entity === 'match') {
        if (pre.property === 'elapsed_seconds') return ctx.elapsedSeconds();
      }
      if (pre.entity === 'player' && ctx.player) {
        if (pre.property === 'has_item') return (ctx.player.inventory || []).includes(pre.value);
        if (pre.property === 'played_echo') return (ctx.player.playedEchoes || []).includes(pre.value);
      }
      return undefined;
    }
    const tlState = ctx.state[pre.timeline];
    if (!tlState) return undefined;
    const entity = tlState[pre.entity];
    if (!entity) return undefined;
    return entity[pre.property];
  }

  /**
   * تحقق التضارب: قاعدة جديدة تكتب قيمة مختلفة لنفس (timeline.entity.property)
   * بعد قاعدة قديمة لها أولوية أقل.
   */
  checkConflict(rule, ctx) {
    const appliedEchoes = (ctx && ctx.appliedEchoes) || new Set();
    for (const oldId of appliedEchoes) {
      const old = this.byId.get(oldId);
      if (!old || old.id === rule.id) continue;
      const cmp = this._compareEffects(old, rule);
      if (cmp.conflict && (old.conflict_priority || 0) >= (rule.conflict_priority || 0)) {
        return {
          reason: 'conflicting_echo',
          conflictingRuleId: old.id,
          message: `Echo ${rule.id} conflicts with ${old.id}`,
        };
      }
    }
    return null;
  }

  _compareEffects(a, b) {
    let conflict = false;
    for (const ea of (a.effects || [])) {
      for (const eb of (b.effects || [])) {
        if (
          ea.target_timeline === eb.target_timeline &&
          ea.entity === eb.entity &&
          ea.property === eb.property
        ) {
          const va = JSON.stringify(ea.value);
          const vb = JSON.stringify(eb.value);
          if (va !== vb) conflict = true;
        }
      }
    }
    return { conflict };
  }

  /**
   * طبق التأثيرات على ctx.state بشكل deterministic.
   * الـ effects المؤجلة توضع في pendingEffects ليُطبقها الـ tick.
   */
  applyEffects(rule, ctx, sourcePlayerUid) {
    const immediate = [];
    const scheduled = [];
    const nowFn = (ctx && ctx.now) ? ctx.now : (() => Date.now());
    const recordEvent = (ctx && ctx.recordEvent) ? ctx.recordEvent : (() => {});

    // تأكد من وجود scheduledEffects على الـ ctx
    if (ctx && !ctx.scheduledEffects) ctx.scheduledEffects = [];

    for (const effect of (rule.effects || [])) {
      const delay = Math.max(0, effect.propagation_delay_ms || 0);
      if (delay > 0) {
        const sched = {
          effect,
          applyAtMs: nowFn() + delay,
          originatingRuleId: rule.id,
        };
        scheduled.push(sched);
        if (ctx) ctx.scheduledEffects.push(sched);
      } else {
        this._applyImmediate(effect, ctx, rule.id);
        immediate.push(effect);
      }
    }

    if (immediate.length > 0) {
      recordEvent('effects_applied', {
        ruleId: rule.id,
        sourcePlayerUid,
        effects: immediate,
        ts: nowFn(),
      });
    }
    if (scheduled.length > 0) {
      recordEvent('effects_scheduled', {
        ruleId: rule.id,
        scheduled,
        ts: nowFn(),
      });
    }
    return { immediate, scheduled };
  }

  _applyImmediate(effect, ctx, ruleId) {
    const tlState = ctx.state[effect.target_timeline];
    if (!tlState) {
      ctx.logger.warn({ effect, ruleId }, 'applyEffect: timeline missing');
      return false;
    }
    const entity = tlState[effect.entity];
    if (!entity) {
      ctx.logger.warn({ effect, ruleId }, 'applyEffect: entity missing');
      return false;
    }
    const action = effect.action || 'set_property';
    if (!ACTION_KINDS.has(action)) {
      ctx.logger.warn({ effect, ruleId }, 'applyEffect: unknown action');
      return false;
    }

    const before = JSON.parse(JSON.stringify(entity));
    switch (action) {
      case 'set_property':
        entity[effect.property] = effect.value;
        break;
      case 'add_value':
        entity[effect.property] = Number(entity[effect.property] || 0) + Number(effect.value || 0);
        break;
      case 'toggle':
        entity[effect.property] = !entity[effect.property];
        break;
      case 'remove':
        delete entity[effect.property];
        break;
      case 'append':
        if (!Array.isArray(entity[effect.property])) entity[effect.property] = [];
        entity[effect.property].push(effect.value);
        break;
      case 'mark':
        entity[effect.property] = true;
        break;
    }

    const nowFn = (ctx && ctx.now) ? ctx.now : (() => Date.now());
    const recordEvent = (ctx && ctx.recordEvent) ? ctx.recordEvent : (() => {});
    recordEvent('effect_applied', {
      ruleId,
      effect,
      before,
      after: JSON.parse(JSON.stringify(entity)),
      ts: nowFn(),
    });
    return true;
  }

  /**
   * طبّق كل التأثيرات المؤجلة التي حان وقتها.
   */
  applyDueScheduled(ctx) {
    const now = (ctx && ctx.now) ? ctx.now() : Date.now();
    const still = [];
    const applied = [];
    const list = (ctx && ctx.scheduledEffects) || [];
    for (const sched of list) {
      if (sched.applyAtMs <= now) {
        this._applyImmediate(sched.effect, ctx, sched.originatingRuleId);
        applied.push(sched);
      } else {
        still.push(sched);
      }
    }
    if (ctx) ctx.scheduledEffects = still;
    return applied;
  }

  /**
   * حدد الـ hints المتاحة للاعب (للتلميحات التدريجية).
   * الـ hints لها مستوى 1..3 — كلما زاد المستوى كلما كان أوضح.
   * المستوى 1: شعور غامض.
   * المستوى 2: تلميح لمكان ما.
   * المستوى 3: توجيه مباشر.
   */
  hintsFor(rule, ctx, playerUid) {
    const hintLevel = ctx.playerHints?.get(playerUid)?.get(rule.id) || 0;
    if (hintLevel >= 3) return [];
    const baseHints = rule.hints || [];
    if (hintLevel === 0) {
      return baseHints.slice(0, 0); // لا شيء
    }
    return baseHints.slice(0, Math.min(hintLevel, baseHints.length));
  }
}

/**
 * حساب الـ dependency closure لقاعدة ما (ما الذي يجب إنجازه قبلها).
 */
EchoEngine.requiredFor = function (engine, ruleId) {
  const visited = new Set();
  const stack = [ruleId];
  while (stack.length) {
    const cur = stack.pop();
    if (visited.has(cur)) continue;
    visited.add(cur);
    const deps = engine.dependencyGraph.get(cur) || new Set();
    for (const d of deps) stack.push(d);
  }
  return visited;
};

EchoEngine.providesFor = function (engine, ruleId) {
  const visited = new Set();
  const stack = [ruleId];
  while (stack.length) {
    const cur = stack.pop();
    if (visited.has(cur)) continue;
    visited.add(cur);
    const revs = engine.reverseGraph.get(cur) || new Set();
    for (const r of revs) stack.push(r);
  }
  return visited;
};

module.exports = EchoEngine;
module.exports.COMPARATORS = COMPARATORS;

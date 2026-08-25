/**
 * EchoEngine — applies causal rules across timelines
 */
'use strict';

class EchoEngine {
  constructor({ rules, logger }) {
    this.rules = rules || [];
    this.logger = logger;
    // Index by source_timeline for fast lookup
    this.index = new Map();
    for (const r of this.rules) {
      const key = `${r.source_timeline}::${r.source_entity}::${r.trigger_action}`;
      if (!this.index.has(key)) this.index.set(key, []);
      this.index.get(key).push(r);
    }
  }

  findRule({ sourceTimeline, sourceEntity, triggerAction }) {
    const key = `${sourceTimeline}::${sourceEntity}::${triggerAction}`;
    const rules = this.index.get(key);
    if (!rules || rules.length === 0) return null;
    if (rules.length === 1) return rules[0];
    // If multiple rules, pick by highest priority
    return rules.sort((a, b) => (b.conflict_priority || 0) - (a.conflict_priority || 0))[0];
  }

  checkPreconditions(rule, room) {
    for (const pre of (rule.preconditions || [])) {
      if (pre.timeline === 'system') continue;
      const tlState = room.state[pre.timeline];
      if (!tlState) return { passed: false, reason: 'Timeline missing' };
      const entity = tlState[pre.entity];
      if (!entity) return { passed: false, reason: 'Entity missing' };
      const val = entity[pre.property];
      const ok = this.compare(val, pre.operator, pre.value);
      if (!ok) return { passed: false, reason: 'Precondition not met' };
    }
    return { passed: true };
  }

  compare(val, op, target) {
    switch (op) {
      case '==': return val == target;
      case '!=': return val != target;
      case '>': return val > target;
      case '<': return val < target;
      case '>=': return val >= target;
      case '<=': return val <= target;
      case 'in': return Array.isArray(target) && target.includes(val);
      default: return false;
    }
  }

  checkConflict(rule, room) {
    // Check if another echo has already locked this entity in a conflicting state
    for (const playedId of room.players.flatMap(p => p.playedEchoes)) {
      const other = this.rules.find(r => r.id === playedId);
      if (!other) continue;
      for (const eff of (other.effects || [])) {
        for (const newEff of (rule.effects || [])) {
          if (eff.target_timeline === newEff.target_timeline &&
              eff.entity === newEff.entity &&
              eff.property === newEff.property &&
              JSON.stringify(eff.value) !== JSON.stringify(newEff.value)) {
            // Conflict — higher priority wins
            if ((rule.conflict_priority || 0) < (other.conflict_priority || 0)) {
              return { reason: 'Conflicting echo with higher priority' };
            }
          }
        }
      }
    }
    return null;
  }

  applyEffects(rule, room, sourcePlayerUid) {
    const applied = [];
    for (const effect of (rule.effects || [])) {
      const delay = effect.propagation_delay_ms || 0;
      if (delay > 0) {
        setTimeout(() => {
          this.applyEffect(effect, room, rule.id);
        }, delay);
      } else {
        this.applyEffect(effect, room, rule.id);
      }
      applied.push(effect);
    }
    return { effects: applied };
  }

  applyEffect(effect, room, ruleId) {
    const tlState = room.state[effect.target_timeline];
    if (!tlState) return;
    const entity = tlState[effect.entity];
    if (!entity) return;
    switch (effect.action) {
      case 'set_property':
        entity[effect.property] = effect.value;
        break;
      case 'add_value':
        entity[effect.property] = (entity[effect.property] || 0) + (effect.value || 0);
        break;
      case 'toggle':
        entity[effect.property] = !entity[effect.property];
        break;
      case 'remove':
        delete entity[effect.property];
        break;
    }
    room.recordEvent('effect_applied', {
      ruleId, effect,
      ts: Date.now(),
    });
  }
}

module.exports = EchoEngine;
'use strict';

/**
 * RolloutManager — gradual rollout with automatic rollback
 * ==========================================================
 * - Phased rollout: 1% → 5% → 25% → 50% → 100%
 * - Each phase requires health gates to pass
 * - Auto-rollback if error rate spikes
 */

const HEALTH_THRESHOLDS = {
  error_rate: { warn: 0.01, critical: 0.05 },     // % of failed requests
  p99_latency_ms: { warn: 250, critical: 500 },  // ms
  crash_rate: { warn: 0.005, critical: 0.02 },     // % of sessions crashed
  match_completion: { warn: 0.7, critical: 0.5 }, // % completion
};

const ROLLOUT_PHASES = [
  { name: 'canary', percent: 1, hold_minutes: 30 },
  { name: 'early', percent: 5, hold_minutes: 60 },
  { name: 'growing', percent: 25, hold_minutes: 120 },
  { name: 'majority', percent: 50, hold_minutes: 240 },
  { name: 'general', percent: 100, hold_minutes: 0 },
];

class RolloutManager {
  constructor({ logger, featureFlags, telemetryCollector, currentPercent = 0 } = {}) {
    this.logger = logger || console;
    this.flags = featureFlags;
    this.telemetry = telemetryCollector;
    this.currentPercent = currentPercent;
    this.history = [];
    this.startedAt = null;
    this.paused = false;
  }

  /**
   * Start rollout
   */
  start() {
    this.startedAt = Date.now();
    this.logger.info('rollout.start', { initial_percent: this.currentPercent });
  }

  /**
   * Advance to next phase if health gates pass
   * Returns the new percent or null if held back
   */
  advance(metrics) {
    if (this.paused) {
      this.logger.warn('rollout.paused', { reason: 'manually paused' });
      return null;
    }
    const health = this.evaluateHealth(metrics);
    if (health.status === 'critical') {
      this.autoRollback('critical_health', health);
      return null;
    }
    const next = this._nextPhase();
    if (!next) return null;
    const phase = ROLLOUT_PHASES[next];
    if (this.flags) {
      for (const flagName of Object.keys(this.flags.snapshot ? this.flags.snapshot() : {})) {
        this.flags.setRollout(flagName, phase.percent);
      }
    }
    this.currentPercent = phase.percent;
    this.history.push({ phase: phase.name, percent: phase.percent, ts: Date.now(), health });
    this.logger.info('rollout.advance', { phase: phase.name, percent: phase.percent, health });
    return phase.percent;
  }

  /**
   * Evaluate health from recent telemetry
   */
  evaluateHealth(metrics) {
    const issues = [];
    if (metrics.error_rate > HEALTH_THRESHOLDS.error_rate.critical) issues.push('error_rate_critical');
    else if (metrics.error_rate > HEALTH_THRESHOLDS.error_rate.warn) issues.push('error_rate_warn');

    if (metrics.p99_latency_ms > HEALTH_THRESHOLDS.p99_latency_ms.critical) issues.push('latency_critical');
    else if (metrics.p99_latency_ms > HEALTH_THRESHOLDS.p99_latency_ms.warn) issues.push('latency_warn');

    if (metrics.crash_rate > HEALTH_THRESHOLDS.crash_rate.critical) issues.push('crash_critical');
    else if (metrics.crash_rate > HEALTH_THRESHOLDS.crash_rate.warn) issues.push('crash_warn');

    if (metrics.match_completion < HEALTH_THRESHOLDS.match_completion.critical) issues.push('completion_critical');
    else if (metrics.match_completion < HEALTH_THRESHOLDS.match_completion.warn) issues.push('completion_warn');

    let status = 'healthy';
    if (issues.some(i => i.endsWith('_critical'))) status = 'critical';
    else if (issues.length > 0) status = 'warn';

    return { status, issues };
  }

  /**
   * Auto-rollback to previous safe phase
   */
  autoRollback(reason, health) {
    this.paused = true;
    const safe = this.history.filter(h => h.health.status === 'healthy').pop();
    const target = safe ? safe.percent : 0;
    this.currentPercent = target;
    if (this.flags) {
      for (const flagName of Object.keys(this.flags.snapshot ? this.flags.snapshot() : {})) {
        this.flags.setRollout(flagName, target);
      }
    }
    this.logger.error('rollout.auto_rollback', { reason, health, target_percent: target });
  }

  /**
   * Manual rollback to a target percent
   */
  rollback(targetPercent = 0) {
    this.currentPercent = targetPercent;
    if (this.flags) {
      for (const flagName of Object.keys(this.flags.snapshot ? this.flags.snapshot() : {})) {
        this.flags.setRollout(flagName, targetPercent);
      }
    }
    this.logger.warn('rollout.manual_rollback', { target_percent: targetPercent });
  }

  /**
   * Pause rollout (keeps current state, no advance)
   */
  pause() {
    this.paused = true;
    this.logger.warn('rollout.paused');
  }

  /**
   * Resume rollout
   */
  resume() {
    this.paused = false;
    this.logger.info('rollout.resumed');
  }

  _nextPhase() {
    for (let i = 0; i < ROLLOUT_PHASES.length; i++) {
      if (ROLLOUT_PHASES[i].percent > this.currentPercent) return i;
    }
    return null;
  }

  status() {
    return {
      current_percent: this.currentPercent,
      paused: this.paused,
      history: this.history.slice(-10),
      thresholds: HEALTH_THRESHOLDS,
    };
  }
}

module.exports = { RolloutManager, ROLLOUT_PHASES, HEALTH_THRESHOLDS };
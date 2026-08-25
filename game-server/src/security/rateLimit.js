'use strict';

/**
 * RateLimiter — Sliding-window per-actor and per-IP limits
 * =========================================================
 * - In-memory token bucket with sliding window
 * - Per-UID, per-IP, global limits
 * - Burst allowance
 * - Exports telemetry for adaptive tuning
 */

class RateLimiter {
  constructor() {
    // buckets: key → { tokens, lastRefill, ts }
    this.buckets = new Map();
    // config: name → { capacity, refillPerSec }
    this.configs = new Map();
    // metrics
    this.hits = 0;
    this.rejects = 0;
    // sweep every 60s
    this.sweepInterval = setInterval(() => this._sweep(), 60_000);
    if (this.sweepInterval.unref) this.sweepInterval.unref();
  }

  define(name, capacity, refillPerSec) {
    this.configs.set(name, { capacity, refillPerSec });
  }

  /**
   * Check if actor can perform one action of given type
   * Returns { ok, remaining, retryAfterMs }
   */
  check(scope, key, configName) {
    const cfg = this.configs.get(configName);
    if (!cfg) {
      // Unknown config = allow (fail-open for prod), log only
      return { ok: true, remaining: -1, retryAfterMs: 0 };
    }
    const compositeKey = `${scope}:${key}:${configName}`;
    const now = Date.now();
    let b = this.buckets.get(compositeKey);
    if (!b) {
      b = { tokens: cfg.capacity, lastRefill: now, events: [] };
      this.buckets.set(compositeKey, b);
    }
    // Refill
    const elapsed = (now - b.lastRefill) / 1000;
    b.tokens = Math.min(cfg.capacity, b.tokens + elapsed * cfg.refillPerSec);
    b.lastRefill = now;
    // Track recent events for sliding window
    b.events.push(now);
    while (b.events.length > 0 && now - b.events[0] > 60_000) b.events.shift();
    // Check
    this.hits++;
    if (b.tokens >= 1) {
      b.tokens -= 1;
      return { ok: true, remaining: Math.floor(b.tokens), retryAfterMs: 0 };
    }
    this.rejects++;
    const needed = 1 - b.tokens;
    const retryMs = Math.ceil((needed / cfg.refillPerSec) * 1000);
    return { ok: false, remaining: 0, retryAfterMs: retryMs };
  }

  _sweep() {
    const now = Date.now();
    for (const [k, b] of this.buckets) {
      // Drop buckets unused for 5 min
      if (now - b.lastRefill > 300_000) this.buckets.delete(k);
    }
  }

  getMetrics() {
    return {
      hits: this.hits,
      rejects: this.rejects,
      reject_rate: this.hits > 0 ? this.rejects / this.hits : 0,
      active_buckets: this.buckets.size,
    };
  }

  shutdown() {
    if (this.sweepInterval) clearInterval(this.sweepInterval);
  }
}

// === Singleton ===
const limiter = new RateLimiter();

// Predefined policies (industry-standard for multiplayer)
limiter.define('event_per_uid',   10, 10);    // 10 burst, +10/sec
limiter.define('interact_per_uid', 5, 3);     // 5 burst, +3/sec
limiter.define('message_per_uid', 10, 2);    // 10 burst, +2/sec
limiter.define('reconnect_per_uid', 3, 0.5);  // 3 burst, +1 per 2s
limiter.define('event_per_ip',    30, 30);    // 30 burst, +30/sec
limiter.define('connect_per_ip', 5, 0.2);    // 5 burst, +1 per 5s
limiter.define('global',          50000, 50000); // server-wide cap

function check(scope, key, configName) {
  return limiter.check(scope, key, configName);
}

function getMetrics() {
  return limiter.getMetrics();
}

module.exports = {
  RateLimiter,
  check,
  getMetrics,
  limiter,
};
'use strict';

/**
 * HealthChecks — liveness and readiness probes
 * ==============================================
 * - /healthz: process alive (always 200 if reachable)
 * - /readyz: only 200 if all dependencies OK
 * - Separate endpoints, never cached
 */

class HealthChecks {
  constructor({ logger, db, adminBridge, roomManager }) {
    this.logger = logger;
    this.db = db;
    this.adminBridge = adminBridge;
    this.roomManager = roomManager;
    this.startTime = Date.now();
    this.startedAt = this.startTime;
    this.lastReadyCheck = 0;
    this.ready = false;
  }

  markReady() {
    if (!this.ready) {
      this.logger.info('health.ready', { since_start_ms: Date.now() - this.startedAt });
    }
    this.ready = true;
  }

  markNotReady(reason) {
    if (this.ready) {
      this.logger.warn('health.not_ready', { reason });
    }
    this.ready = false;
  }

  /**
   * Liveness — just confirms process is alive
   */
  async liveness() {
    return {
      status: 'ok',
      ok: true,
      uptime_ms: Date.now() - this.startedAt,
      pid: process.pid,
    };
  }

  /**
   * Readiness — confirms dependencies are reachable
   * Returns 200 if ready, 503 if not
   */
  async readiness() {
    const checks = [];
    let ok = true;

    // DB check (optional)
    if (this.db && typeof this.db.ping === 'function') {
      try {
        const dbOk = await Promise.race([
          this.db.ping(),
          newTimeout(false, 2000),
        ]);
        checks.push({ name: 'database', ok: !!dbOk });
        if (!dbOk) ok = false;
      } catch (e) {
        checks.push({ name: 'database', ok: false, error: e.message });
        ok = false;
      }
    }

    // Admin bridge cache freshness
    if (this.adminBridge) {
      // AdminBridge exposes `lastFetch`; keep the legacy name as a fallback
      // for compatible bridge implementations used by deployments/tests.
      const lastFetch = this.adminBridge.lastFetch ?? this.adminBridge.lastFetchTime ?? 0;
      const ageSec = (Date.now() - lastFetch) / 1000;
      const cacheOk = ageSec < 600;
      checks.push({ name: 'admin_cache', ok: cacheOk, age_sec: ageSec });
      if (!cacheOk) ok = false;
    }

    // Room capacity
    if (this.roomManager) {
      const roomCount = this.roomManager.roomCount();
      const cap = this.roomManager.maxRooms || 200;
      const capOk = roomCount < cap;
      checks.push({ name: 'room_capacity', ok: capOk, used: roomCount, cap });
      if (!capOk) ok = false;
    }

    return {
      status: ok ? 'ok' : 'not_ready',
      ok,
      ready: this.ready && ok,
      checks,
      uptime_ms: Date.now() - this.startedAt,
    };
  }

  /**
   * Express handler for /healthz (liveness)
   */
  livenessHandler() {
    return async (req, res) => {
      try {
        const result = await this.liveness();
        res.set('Cache-Control', 'no-store');
        res.json(result);
      } catch (e) {
        res.status(503).json({ ok: false, error: e.message });
      }
    };
  }

  /**
   * Express handler for /readyz (readiness)
   */
  readinessHandler() {
    return async (req, res) => {
      try {
        const result = await this.readiness();
        res.set('Cache-Control', 'no-store');
        if (!result.ok) {
          res.status(503).json(result);
        } else {
          res.json(result);
        }
      } catch (e) {
        res.status(503).json({ ok: false, error: e.message });
      }
    };
  }
}

function newTimeout(value, ms) {
  return new Promise(resolve => setTimeout(() => resolve(value), ms));
}

module.exports = { HealthChecks };

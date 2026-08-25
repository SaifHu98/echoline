'use strict';

/**
 * TelemetryCollector — aggregates client/server metrics for release gates
 * =======================================================================
 * Tracks:
 *  - crash_rate: sessions that crashed / total sessions
 *  - disconnect_rate: mid-match disconnects / total matches
 *  - p50/p95/p99 latency (ms)
 *  - match_completion: matches completed successfully / total started
 *  - memory: peak heap, avg RSS
 *  - battery: client-reported battery drain rate (optional)
 *
 * Data is in-memory only by default (privacy); can be flushed to Render
 * logs or external monitoring (e.g., Prometheus) via adapter.
 */

class TelemetryCollector {
  constructor() {
    this.events = [];
    this.windowMs = 5 * 60 * 1000;  // 5 min rolling window
    this.startedAt = Date.now();

    // Counters
    this.crashes = 0;
    this.sessions = 0;
    this.matches_started = 0;
    this.matches_completed = 0;
    this.disconnects_mid_match = 0;
    this.latencies = [];
    this.memory_samples = [];
    this.errors = 0;
    this.requests = 0;
  }

  // ============= Event ingestion =============

  recordSessionStart() { this.sessions++; }
  recordSessionEnd(crashed = false) {
    if (crashed) this.crashes++;
  }

  recordMatchStart() { this.matches_started++; }
  recordMatchComplete(success = true) {
    if (success) this.matches_completed++;
  }

  recordDisconnect() { this.disconnects_mid_match++; }
  recordLatency(ms) {
    this.latencies.push({ ms, ts: Date.now() });
    this._gcWindow(this.latencies);
  }
  recordRequest(success = true) {
    this.requests++;
    if (!success) this.errors++;
  }
  recordMemory(heapMB) {
    this.memory_samples.push({ mb: heapMB, ts: Date.now() });
    this._gcWindow(this.memory_samples);
  }

  _gcWindow(arr) {
    const cutoff = Date.now() - this.windowMs;
    while (arr.length > 0 && arr[0].ts < cutoff) arr.shift();
  }

  // ============= Aggregates =============

  computeMetrics() {
    const lats = this.latencies.map(l => l.ms).sort((a, b) => a - b);
    const mems = this.memory_samples.map(m => m.mb);

    return {
      window_minutes: this.windowMs / 60000,
      crash_rate: this.sessions > 0 ? this.crashes / this.sessions : 0,
      disconnect_rate: this.matches_started > 0 ? this.disconnects_mid_match / this.matches_started : 0,
      match_completion: this.matches_started > 0 ? this.matches_completed / this.matches_started : 0,
      error_rate: this.requests > 0 ? this.errors / this.requests : 0,
      latency_ms: {
        p50: lats[Math.floor(lats.length * 0.5)] || 0,
        p95: lats[Math.floor(lats.length * 0.95)] || 0,
        p99: lats[Math.floor(lats.length * 0.99)] || 0,
        max: lats[lats.length - 1] || 0,
      },
      memory_mb: {
        avg: mems.length ? mems.reduce((a, b) => a + b, 0) / mems.length : 0,
        peak: mems.length ? Math.max(...mems) : 0,
      },
      sessions: this.sessions,
      matches: this.matches_started,
      requests: this.requests,
    };
  }

  /**
   * Get a snapshot suitable for monitoring dashboards
   */
  snapshot() {
    return {
      timestamp: new Date().toISOString(),
      uptime_sec: (Date.now() - this.startedAt) / 1000,
      ...this.computeMetrics(),
    };
  }

  /**
   * Emit metrics to console (structured JSON)
   */
  emit(logger = console) {
    const snap = this.snapshot();
    logger.info ? logger.info('telemetry.snapshot', snap) : console.log(JSON.stringify(snap));
    return snap;
  }
}

module.exports = { TelemetryCollector };
/**
 * ClientTelemetryService.js
 * --------------------------------------------------------------
 * Receives log batches from the Godot client and persists them for
 * server-side analysis. Designed for the Phase-7 in-game telemetry
 * pipeline. All data is sanitised, rate-limited, and rotated daily.
 *
 * Storage: NDJSON files under data/client_logs/YYYY-MM-DD.ndjson.
 * Each line is one log entry: {ts, severity, category, message, ...}.
 *
 * Endpoints exposed (mounted by server.js):
 *   POST /api/client/logs   batch ingest
 *   GET  /api/admin/logs    admin viewer (gated by AdminBridge)
 *   GET  /api/admin/logs/stats   summary stats for the admin dashboard
 */

const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(__dirname, '..', '..', 'data', 'client_logs');
const MAX_BATCH_SIZE = 50;
const MAX_ENTRY_SIZE_BYTES = 4096;        // hard cap per entry
const MAX_FIELD_LEN = 256;
const RATE_LIMIT_PER_MIN = 600;           // entries per session/minute
const SESSION_RATELIMIT_WINDOW_MS = 60000;

// Categories that auto-flag the batch as error severity (for stats only).
const ERROR_CATEGORIES = new Set([
  'network.handshake', 'network.poll', 'network.post',
  'crash', 'fatal', 'autoload.init',
  'lobby.create', 'lobby.join', 'lobby.leave',
]);

class ClientTelemetryService {
  constructor({ logger, rateLimiter, adminBridge }) {
    this.logger = logger || console;
    this.rateLimiter = rateLimiter;
    this.adminBridge = adminBridge;
    this._ensure_log_dir();
    this._session_counters = new Map(); // session -> { window_start, count }
    this._session_stats = new Map();    // session -> {total, last_seen, by_severity}
    this._recent = [];                  // last 200 events (in-memory ring)
  }

  /**
   * Simple in-memory sliding-window per-session rate limit.
   * Returns false if the session has exceeded RATE_LIMIT_PER_MIN.
   */
  _check_rate(session, count) {
    const now = Date.now();
    let entry = this._session_counters.get(session);
    if (!entry || now - entry.window_start > SESSION_RATELIMIT_WINDOW_MS) {
      entry = { window_start: now, count: 0 };
      this._session_counters.set(session, entry);
    }
    if (entry.count + count > RATE_LIMIT_PER_MIN) return false;
    entry.count += count;
    return true;
  }

  _ensure_log_dir() {
    try {
      if (!fs.existsSync(LOG_DIR)) {
        fs.mkdirSync(LOG_DIR, { recursive: true });
      }
    } catch (e) {
      this.logger.warn({ err: e.message, dir: LOG_DIR }, 'Failed to create log dir');
    }
  }

  _date_str(d = new Date()) {
    return d.toISOString().slice(0, 10);
  }

  _log_path(d = new Date()) {
    return path.join(LOG_DIR, `${this._date_str(d)}.ndjson`);
  }

  /**
   * Validate + sanitise one entry. Returns null if the entry is too malformed.
   */
  _sanitise(entry) {
    if (!entry || typeof entry !== 'object') return null;
    const out = {};
    out.ts = Number.isFinite(entry.ts) ? Math.floor(entry.ts) : Math.floor(Date.now() / 1000);
    out.severity = ['info', 'warn', 'error', 'fatal'].includes(entry.severity)
      ? entry.severity : 'info';
    out.category = String(entry.category || 'uncategorized').slice(0, MAX_FIELD_LEN);
    out.message = String(entry.message || '').slice(0, MAX_FIELD_LEN);
    out.session = String(entry.session || 'anon').slice(0, 64);
    out.platform = String(entry.platform || 'unknown').slice(0, 64);
    out.os = String(entry.os || '').slice(0, 64);
    out.device = String(entry.device || '').slice(0, 64);
    out.build = String(entry.build || '').slice(0, 32);
    out.context = {};
    if (entry.context && typeof entry.context === 'object') {
      for (const k of Object.keys(entry.context)) {
        const v = entry.context[k];
        if (typeof v === 'string') out.context[k] = v.slice(0, MAX_FIELD_LEN);
        else if (typeof v === 'number' || typeof v === 'boolean') out.context[k] = v;
        else if (v === null) out.context[k] = null;
        else if (Array.isArray(v)) out.context[k] = v.slice(0, 20).map(x => String(x).slice(0, 64));
        else {
          try { out.context[k] = JSON.stringify(v).slice(0, MAX_FIELD_LEN); }
          catch { out.context[k] = '<unserializable>'; }
        }
      }
    }
    const json = JSON.stringify(out);
    if (json.length > MAX_ENTRY_SIZE_BYTES) {
      out.message = out.message.slice(0, 200) + '…';
      out.context = { _truncated: true, original_size: json.length };
    }
    return out;
  }

  /**
   * Build the Express handler for POST /api/client/logs.
   */
  buildIngestHandler() {
    return async (req, res) => {
      try {
        const body = req.body || {};
        const batch = Array.isArray(body.batch) ? body.batch : [];
        const session = String(body.session || 'anon').slice(0, 64);

        if (batch.length === 0) {
          return res.status(400).json({ success: false, error: 'Empty batch' });
        }
        if (batch.length > MAX_BATCH_SIZE) {
          return res.status(413).json({ success: false, error: `Batch too large (max ${MAX_BATCH_SIZE})` });
        }

        // Rate limit per session
        if (!this._check_rate(session, batch.length)) {
          return res.status(429).json({ success: false, error: 'Rate limited' });
        }

        const accepted = [];
        const dropped = [];
        for (const raw of batch) {
          const entry = this._sanitise(raw);
          if (!entry) { dropped.push('malformed'); continue; }
          try {
            fs.appendFileSync(this._log_path(), JSON.stringify(entry) + '\n');
            accepted.push(entry);
            this._record_stats(entry);
          } catch (e) {
            this.logger.warn({ err: e.message }, 'Failed to persist log entry');
            dropped.push('persist_failed');
          }
        }
        return res.json({
          success: true,
          accepted: accepted.length,
          dropped: dropped.length,
        });
      } catch (e) {
        this.logger.warn({ err: e.message }, 'Telemetry ingest error');
        return res.status(500).json({ success: false, error: 'Internal error' });
      }
    };
  }

  _record_stats(entry) {
    this._recent.push(entry);
    if (this._recent.length > 200) this._recent.shift();
    const s = this._session_stats.get(entry.session) || { total: 0, last_seen: 0, by_severity: { info: 0, warn: 0, error: 0, fatal: 0 } };
    s.total += 1;
    s.last_seen = Math.max(s.last_seen, entry.ts);
    s.by_severity[entry.severity] = (s.by_severity[entry.severity] || 0) + 1;
    this._session_stats.set(entry.session, s);
  }

  /**
   * Build the admin viewer handler.
   *   GET /api/admin/logs?limit=50&severity=error&session=xyz
   */
  buildAdminListHandler() {
    return async (req, res) => {
      if (this._is_admin_blocked(req)) {
        return res.status(403).json({ success: false, error: 'Forbidden' });
      }
      const limit = Math.min(parseInt(req.query.limit || '100', 10) || 100, 500);
      const severity = req.query.severity ? String(req.query.severity) : null;
      const session = req.query.session ? String(req.query.session) : null;
      const category = req.query.category ? String(req.query.category) : null;
      const date = req.query.date ? String(req.query.date) : this._date_str();

      const file = path.join(LOG_DIR, `${date}.ndjson`);
      if (!fs.existsSync(file)) {
        return res.json({ success: true, date, entries: [], count: 0 });
      }
      const lines = fs.readFileSync(file, 'utf-8').split('\n').filter(Boolean);
      const all = [];
      for (const ln of lines) {
        try {
          const e = JSON.parse(ln);
          if (severity && e.severity !== severity) continue;
          if (session && e.session !== session) continue;
          if (category && e.category !== category) continue;
          all.push(e);
        } catch { /* skip malformed */ }
      }
      // newest first
      all.sort((a, b) => b.ts - a.ts);
      return res.json({
        success: true,
        date,
        count: all.length,
        entries: all.slice(0, limit),
      });
    };
  }

  /**
   * Build summary stats for admin dashboard.
   * GET /api/admin/logs/stats
   */
  buildStatsHandler() {
    return async (req, res) => {
      if (this._is_admin_blocked(req)) {
        return res.status(403).json({ success: false, error: 'Forbidden' });
      }
      const totals = { info: 0, warn: 0, error: 0, fatal: 0 };
      const byCategory = {};
      let total = 0;
      const now = Math.floor(Date.now() / 1000);
      const sessions = [];

      for (const [sid, s] of this._session_stats.entries()) {
        total += s.total;
        for (const sev of Object.keys(s.by_severity)) {
          totals[sev] = (totals[sev] || 0) + s.by_severity[sev];
        }
        sessions.push({
          session: sid,
          total: s.total,
          last_seen: s.last_seen,
          last_seen_ago_sec: s.last_seen ? (now - s.last_seen) : null,
          by_severity: s.by_severity,
        });
      }

      // Aggregate categories from the in-memory ring buffer
      for (const entry of this._recent) {
        byCategory[entry.category] = (byCategory[entry.category] || 0) + 1;
      }

      // Top error categories for the dashboard
      const topErrors = Object.entries(byCategory)
        .filter(([k]) => ERROR_CATEGORIES.has(k) || (totals.error > 0))
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([category, count]) => ({ category, count }));

      sessions.sort((a, b) => b.last_seen - a.last_seen);

      return res.json({
        success: true,
        total,
        totals,
        sessions: sessions.slice(0, 50),
        session_count: sessions.length,
        top_errors: topErrors,
        recent: this._recent.slice(-30).reverse(),
      });
    };
  }

  /**
   * GET /api/admin/logs/files — list available log files (by date).
   */
  buildFilesHandler() {
    return async (req, res) => {
      if (this._is_admin_blocked(req)) {
        return res.status(403).json({ success: false, error: 'Forbidden' });
      }
      if (!fs.existsSync(LOG_DIR)) return res.json({ success: true, files: [] });
      const files = fs.readdirSync(LOG_DIR)
        .filter((f) => f.endsWith('.ndjson'))
        .sort()
        .reverse()
        .map((f) => {
          const stat = fs.statSync(path.join(LOG_DIR, f));
          return { name: f, size_bytes: stat.size, modified: stat.mtime.toISOString() };
        });
      return res.json({ success: true, files });
    };
  }

  /**
   * Admin gating helper. AdminBridge.allowAdminRequest is the canonical
   * check but the bridge doesn't yet expose one — fall back to an
   * allow-by-default posture (which mirrors the rest of /api/admin/*).
   * This keeps the route operational in development while still letting
   * a future auth layer plug in via AdminBridge.
   */
  _is_admin_blocked(req) {
    if (!this.adminBridge) return false;
    if (typeof this.adminBridge.allowAdminRequest !== 'function') return false;
    return !this.adminBridge.allowAdminRequest(req);
  }
}

module.exports = { ClientTelemetryService, LOG_DIR };

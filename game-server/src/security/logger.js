'use strict';

/**
 * Logger — Structured logging with PII redaction
 * ==============================================
 * - JSON Lines output (machine-parseable)
 * - Redacts: passwords, tokens, IPs (hashes them), raw request bodies
 * - Severity levels: debug, info, warn, error, audit
 * - Rotating salt for IP hashing
 */

const crypto = require('crypto');

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40, audit: 50 };
const REDACT_KEYS = new Set([
  'password', 'token', 'authorization', 'cookie', 'set-cookie',
  'secret', 'api_key', 'private_key', 'session_id', 'csrf_token',
  'email', 'phone', 'address',
]);

const REDACT_PATTERNS = [
  // Bearer auth
  /Bearer\s+[A-Za-z0-9_\-\.]+/g,
  // JWT-like tokens
  /eyJ[A-Za-z0-9_\-]+\.eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+/g,
  // Google Play receipts
  /GPA\.[0-9]+\-[0-9]+\-[0-9]+/g,
  // Credit card-like
  /\b[0-9]{4}[\s\-]?[0-9]{4}[\s\-]?[0-9]{4}[\s\-]?[0-9]{4}\b/g,
];

class Logger {
  constructor(opts = {}) {
    this.level = opts.level || process.env.LOG_LEVEL || 'info';
    this.minLevel = LEVELS[this.level] || LEVELS.info;
    this.salt = opts.salt || process.env.LOG_SALT || 'rotate-me-' + crypto.randomBytes(8).toString('hex');
    this.stream = opts.stream || process.stdout;
    this.context = {};
  }

  setContext(ctx) {
    this.context = { ...this.context, ...ctx };
  }

  _shouldLog(level) {
    return (LEVELS[level] || 0) >= this.minLevel;
  }

  _hashIp(ip) {
    if (!ip) return null;
    return crypto.createHmac('sha256', this.salt).update(ip).digest('hex').slice(0, 12);
  }

  _redact(obj, depth = 0) {
    if (depth > 6) return '[deep]';
    if (obj === null || obj === undefined) return obj;
    if (typeof obj === 'string') {
      // Strip bearer / JWT / receipts
      let s = obj;
      for (const p of REDACT_PATTERNS) {
        s = s.replace(p, '[REDACTED]');
      }
      // If looks like a raw token (long random base64), mask
      if (s.length > 60 && /^[A-Za-z0-9_\-\.]+$/.test(s)) {
        s = '[REDACTED-TOKEN]';
      }
      return s;
    }
    if (typeof obj === 'number' || typeof obj === 'boolean') return obj;
    if (Array.isArray(obj)) return obj.map(v => this._redact(v, depth + 1));
    if (typeof obj === 'object') {
      const out = {};
      for (const k of Object.keys(obj)) {
        if (REDACT_KEYS.has(k.toLowerCase())) {
          out[k] = '[REDACTED]';
        } else if (k.toLowerCase().includes('ip') || k === 'remote_addr') {
          out[k] = this._hashIp(obj[k]);
        } else if (k === 'headers' || k === 'body' || k === 'cookies') {
          out[k] = '[REDACTED]';
        } else {
          out[k] = this._redact(obj[k], depth + 1);
        }
      }
      return out;
    }
    return obj;
  }

  _emit(level, event, data) {
    if (!this._shouldLog(level)) return;
    const entry = {
      ts: new Date().toISOString(),
      level,
      event,
      ...this.context,
      ...this._redact(data || {}),
    };
    try {
      this.stream.write(JSON.stringify(entry) + '\n');
    } catch (e) {
      // Never let logging crash the server
      if (level === 'error') process.stderr.write('[LOGGER_FAIL] ' + e.message + '\n');
    }
  }

  debug(event, data) { this._emit('debug', event, data); }
  info(event, data)  { this._emit('info',  event, data); }
  warn(event, data)  { this._emit('warn',  event, data); }
  error(event, data) { this._emit('error', event, data); }
  audit(event, data) { this._emit('audit', event, data); }

  // Helpers for common events
  connection(socketId, ip, eventType, extra = {}) {
    this.info('socket.' + eventType, { socket_id: socketId, ip, ...extra });
  }
  matchEvent(roomId, eventType, playerUid, extra = {}) {
    this.info('match.' + eventType, {
      room_id: roomId,
      player_uid: playerUid,
      ...extra,
    });
  }
  security(eventType, ip, extra = {}) {
    this.audit('security.' + eventType, { ip, ...extra });
  }
  rateLimited(scope, key, configName) {
    this.security('rate_limit', null, { scope, key, config: configName });
  }
}

// Singleton
const logger = new Logger({ level: process.env.LOG_LEVEL || 'info' });

module.exports = { Logger, logger, LEVELS };
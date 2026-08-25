/**
 * Protocol Input Validator & Rate Limiter for ECHO//LINE (أصداء)
 * Defends against packet spam, malformed JSON, and unauthorized mutations.
 */

const { MessageTypes } = require('./messages');

class RateLimiter {
  constructor(maxTokens = 20, refillRatePerSec = 5) {
    this.maxTokens = maxTokens;
    this.refillRate = refillRatePerSec;
    this.clients = new Map();
  }

  check(clientId) {
    const now = Date.now();
    let bucket = this.clients.get(clientId);
    if (!bucket) {
      bucket = { tokens: this.maxTokens, lastRefill: now };
      this.clients.set(clientId, bucket);
    }

    const elapsed = (now - bucket.lastRefill) / 1000;
    bucket.tokens = Math.min(this.maxTokens, bucket.tokens + elapsed * this.refillRate);
    bucket.lastRefill = now;

    if (bucket.tokens >= 1) {
      bucket.tokens -= 1;
      return true;
    }
    return false;
  }

  cleanup(clientId) {
    this.clients.delete(clientId);
  }
}

function sanitizeString(str, maxLen = 64) {
  if (typeof str !== 'string') return '';
  // Strip dangerous control chars while preserving valid international Unicode
  return str.replace(/[\x00-\x1F\x7F]/g, '').trim().slice(0, maxLen);
}

function validateIncomingMessage(raw) {
  try {
    const str = typeof raw === 'string' ? raw : raw.toString('utf-8');
    const msg = JSON.parse(str);
    if (!msg || typeof msg !== 'object') return { valid: false, error: 'Invalid object' };
    if (!MessageTypes[msg.type]) return { valid: false, error: `Unknown opcode: ${msg.type}` };
    return { valid: true, message: msg };
  } catch (err) {
    return { valid: false, error: 'Malformed JSON payload' };
  }
}

module.exports = {
  RateLimiter,
  sanitizeString,
  validateIncomingMessage
};

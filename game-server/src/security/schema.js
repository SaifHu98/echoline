'use strict';

/**
 * Schema — JSON Schema validation for every event
 * ================================================
 * - Strict type checks
 * - Size limits (string ≤ 256, array ≤ 50, payload ≤ 64KB)
 * - Range checks (numbers, coordinates)
 * - Whitelisted fields per event
 * - Unknown fields dropped silently
 */

const MAX_PAYLOAD_BYTES = 64 * 1024;  // 64KB
const MAX_STRING = 256;
const MAX_ARRAY = 50;
const MAX_OBJECT_DEPTH = 5;

// === Helpers ===

function isString(v, maxLen = MAX_STRING) {
  return typeof v === 'string' && v.length <= maxLen;
}
function isInt(v, min = -Infinity, max = Infinity) {
  return typeof v === 'number' && Number.isInteger(v) && v >= min && v <= max;
}
function isNum(v, min = -Infinity, max = Infinity) {
  return typeof v === 'number' && Number.isFinite(v) && v >= min && v <= max;
}
function isBool(v) { return typeof v === 'boolean'; }
function isIn(v, allowed) { return Array.isArray(allowed) && allowed.includes(v); }
function isShortId(v, maxLen = 128) {
  return isString(v, maxLen) && /^[a-zA-Z0-9_-]+$/.test(v);
}
function isUuidLike(v) {
  return isString(v, 64) && /^[a-zA-Z0-9-]+$/.test(v);
}

function validateObject(obj, schema, depth = 0) {
  if (depth > MAX_OBJECT_DEPTH) return false;
  if (typeof obj !== 'object' || obj === null || Array.isArray(obj)) return false;
  for (const key of Object.keys(obj)) {
    if (!(key in schema)) {
      // Unknown field — drop silently (do not fail)
      delete obj[key];
      continue;
    }
    const rule = schema[key];
    const value = obj[key];
    if (!validateValue(value, rule, depth + 1)) return false;
  }
  return true;
}

function validateValue(value, rule, depth) {
  if (rule.type === 'string') {
    if (!isString(value, rule.max || MAX_STRING)) return false;
    if (rule.pattern && !rule.pattern.test(value)) return false;
    if (rule.allowed && !isIn(value, rule.allowed)) return false;
    return true;
  }
  if (rule.type === 'int') {
    if (!isInt(value, rule.min, rule.max)) return false;
    return true;
  }
  if (rule.type === 'number') {
    if (!isNum(value, rule.min, rule.max)) return false;
    return true;
  }
  if (rule.type === 'bool') {
    return isBool(value);
  }
  if (rule.type === 'enum') {
    return isIn(value, rule.values);
  }
  if (rule.type === 'id') {
    return isShortId(value, rule.max || 64);
  }
  if (rule.type === 'array') {
    if (!Array.isArray(value)) return false;
    if (value.length > (rule.max || MAX_ARRAY)) return false;
    for (const item of value) {
      if (!validateValue(item, rule.items, depth + 1)) return false;
    }
    return true;
  }
  if (rule.type === 'object') {
    return validateObject(value, rule.schema, depth + 1);
  }
  return false;
}

// === Event Schemas ===

const SCHEMAS = {
  'lobby:create': {
    playerUid: { type: 'id' },
    displayName: { type: 'string', max: 32, pattern: /^[\p{L}\p{N}\s._-]+$/u },
    language: { type: 'enum', values: ['en', 'ar', 'qps_mirrored', 'qps_expanded'] },
    scenarioId: { type: 'id' },
  },
  'lobby:join': {
    playerUid: { type: 'id' },
    displayName: { type: 'string', max: 32 },
    language: { type: 'enum', values: ['en', 'ar', 'qps_mirrored', 'qps_expanded'] },
    roomCode: { type: 'string', max: 8, pattern: /^[A-Z0-9]+$/ },
  },
  'lobby:leave': {},
  'lobby:select_timeline': {
    timeline: { type: 'enum', values: ['past', 'present', 'future'] },
  },
  'lobby:set_ready': {
    ready: { type: 'bool' },
  },
  'lobby:start': {},
  'lobby:fill_with_bots': {},
  'match:interact': {
    entityId: { type: 'id' },
    action: { type: 'string', max: 64 },
    idempotencyKey: { type: 'id', max: 64 },
    ruleId: { type: 'id', max: 64 },
    clientSeq: { type: 'int', min: 0, max: 1e9 },
  },
  'match:quick_message': {
    intent: { type: 'id', max: 64 },
    code: { type: 'id', max: 64 },
    data: { type: 'object', schema: {} },  // allow any small object
  },
  'match:ping': {
    type: { type: 'enum', values: ['location', 'danger', 'help', 'object', 'echo'] },
    x: { type: 'number', min: 0, max: 10000 },
    y: { type: 'number', min: 0, max: 10000 },
    targetId: { type: 'id' },
  },
  'match:move': {
    x: { type: 'number', min: 0, max: 10000 },
    y: { type: 'number', min: 0, max: 10000 },
    dir: { type: 'number', min: 0, max: 360 },
  },
  'match:state_request': {},
  'match:reconnect': {
    playerUid: { type: 'id' },
    lastClientSeq: { type: 'int', min: 0, max: 1e9 },
  },
  'match:hint': {
    ruleId: { type: 'id' },
  },
};

/**
 * Validate payload for event
 * - Drops unknown fields silently
 * - Returns sanitized object or null if invalid
 */
function sanitize(eventName, payload) {
  if (!payload || typeof payload !== 'object') return null;
  const schema = SCHEMAS[eventName];
  if (!schema) return null;
  // Deep clone
  const cloned = JSON.parse(JSON.stringify(payload));
  // Check payload size
  const serialized = JSON.stringify(cloned);
  if (serialized.length > MAX_PAYLOAD_BYTES) return null;
  // Validate
  if (!validateObject(cloned, schema, 0)) return null;
  return cloned;
}

/**
 * Throw with structured error
 */
class ValidationError extends Error {
  constructor(message, field) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
  }
}

module.exports = {
  sanitize,
  validateObject,
  validateValue,
  SCHEMAS,
  ValidationError,
  MAX_PAYLOAD_BYTES,
  MAX_STRING,
  MAX_ARRAY,
};

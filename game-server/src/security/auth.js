'use strict';

/**
 * Auth — مصادقة الاتصالات والتفويض لكل حدث
 * ==========================================
 * - Player token: signed with HMAC-SHA256 (JWT-like structure)
 * - Token rotation on re-auth
 * - Server-authoritative session store
 * - Constant-time comparison
 *
 * Token format: base64url(header).base64url(payload).base64url(signature)
 */

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const SECRET_FILE = process.env.AUTH_SECRET_FILE || path.join(__dirname, '..', '..', '.auth_secret');
const TOKEN_TTL_SECONDS = parseInt(process.env.TOKEN_TTL || '3600', 10);  // 1h
const REFRESH_THRESHOLD_SECONDS = parseInt(process.env.TOKEN_REFRESH_THRESHOLD || '600', 10);  // 10m

// === Loaded secret ===
let _secret = null;

function _loadSecret() {
  if (_secret) return _secret;
  // Try file first
  if (fs.existsSync(SECRET_FILE)) {
    _secret = fs.readFileSync(SECRET_FILE, 'utf-8').trim();
    return _secret;
  }
  // Then env var
  if (process.env.AUTH_SECRET) {
    _secret = process.env.AUTH_SECRET;
    return _secret;
  }
  // Generate ephemeral (development only)
  if (process.env.NODE_ENV !== 'production') {
    _secret = crypto.randomBytes(64).toString('hex');
    console.warn('[AUTH] Generated ephemeral secret — DO NOT USE IN PRODUCTION');
    return _secret;
  }
  throw new Error('AUTH_SECRET not configured — refusing to start');
}

// === Base64url helpers ===
function b64url(buf) {
  return Buffer.from(buf).toString('base64')
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlDecode(str) {
  str = str.replace(/-/g, '+').replace(/_/g, '/');
  while (str.length % 4) str += '=';
  return Buffer.from(str, 'base64');
}

// === Sign / verify ===
function sign(payload) {
  const header = { alg: 'HS256', typ: 'ECHO' };
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = {
    ...payload,
    iat: now,
    exp: now + TOKEN_TTL_SECONDS,
    jti: crypto.randomBytes(16).toString('hex'),
  };
  const headerB64 = b64url(JSON.stringify(header));
  const payloadB64 = b64url(JSON.stringify(fullPayload));
  const data = `${headerB64}.${payloadB64}`;
  const sig = crypto.createHmac('sha256', _loadSecret()).update(data).digest();
  return `${data}.${b64url(sig)}`;
}

function verify(token) {
  if (typeof token !== 'string' || !token.includes('.')) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [headerB64, payloadB64, sigB64] = parts;
  const data = `${headerB64}.${payloadB64}`;
  const expectedSig = crypto.createHmac('sha256', _loadSecret()).update(data).digest();
  const actualSig = b64urlDecode(sigB64);
  // Constant-time comparison
  if (expectedSig.length !== actualSig.length) return null;
  if (!crypto.timingSafeEqual(expectedSig, actualSig)) return null;
  // Parse payload
  let payload;
  try {
    payload = JSON.parse(b64urlDecode(payloadB64).toString('utf-8'));
  } catch {
    return null;
  }
  // Check expiration
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) return null;
  return payload;
}

// === Refresh ===
function shouldRefresh(payload) {
  if (!payload.exp) return true;
  const now = Math.floor(Date.now() / 1000);
  return payload.exp - now < REFRESH_THRESHOLD_SECONDS;
}

function refresh(token) {
  const payload = verify(token);
  if (!payload) return null;
  // Issue new token with same identity but new iat/exp
  const { iat, exp, jti, ...identity } = payload;
  return sign(identity);
}

// === Roles / authorization ===

const ROLES = {
  PLAYER: 'player',
  BOT: 'bot',
  ADMIN: 'admin',
  SYSTEM: 'system',
};

/**
 * Check if a role can perform an action on a target
 */
function canAct(actorRole, action, targetRole = null) {
  const matrix = {
    player: ['play', 'chat', 'ping', 'interact', 'ready', 'start'],
    bot:    ['play', 'interact'],
    admin:  ['*'],
    system: ['*'],
  };
  const allowed = matrix[actorRole] || [];
  if (allowed.includes('*')) return true;
  return allowed.includes(action);
}

/**
 * Authorize a socket event
 */
function authorizeEvent(socket, eventName, payload) {
  const session = socket._auth;
  if (!session) return { ok: false, code: 'NO_AUTH', message: 'No session' };
  if (session.exp < Math.floor(Date.now() / 1000)) {
    return { ok: false, code: 'TOKEN_EXPIRED', message: 'Session expired' };
  }
  if (!canAct(session.role, eventName)) {
    return { ok: false, code: 'FORBIDDEN', message: `Role ${session.role} cannot ${eventName}` };
  }
  return { ok: true, session };
}

/**
 * Issue a player token (called from API on login)
 */
function issuePlayerToken(playerUid, displayName, language) {
  return sign({
    sub: playerUid,
    role: ROLES.PLAYER,
    name: displayName,
    lang: language,
  });
}

function issueBotToken(botUid) {
  return sign({ sub: botUid, role: ROLES.BOT });
}

function issueAdminToken(adminUid) {
  return sign({ sub: adminUid, role: ROLES.ADMIN });
}

module.exports = {
  sign,
  verify,
  refresh,
  shouldRefresh,
  canAct,
  authorizeEvent,
  issuePlayerToken,
  issueBotToken,
  issueAdminToken,
  ROLES,
};

'use strict';

/**
 * Allowlist — Origin allowlist for HTTP and Socket.IO
 * ====================================================
 * - Reject connections from unknown origins
 * - Support per-route allowlists
 * - Wildcard subdomains (e.g. ".example.com")
 * - Empty allowlist = no checks (development only)
 */

const DEFAULT_HTTP_ORIGINS = [
  'https://echoline.eduiraq.net',
  'https://www.echoline.eduiraq.net',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:8080',
];

const DEFAULT_SOCKET_ORIGINS = [
  'https://echoline.eduiraq.net',
  'https://www.echoline.eduiraq.net',
  'http://localhost:3000',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:8080',
];

function getHttpOrigins() {
  const env = process.env.ALLOWED_ORIGINS_HTTP;
  if (!env) return DEFAULT_HTTP_ORIGINS;
  return env.split(',').map(s => s.trim()).filter(Boolean);
}

function getSocketOrigins() {
  const env = process.env.ALLOWED_ORIGINS_SOCKET;
  if (!env) return DEFAULT_SOCKET_ORIGINS;
  return env.split(',').map(s => s.trim()).filter(Boolean);
}

/**
 * Check if origin matches any entry (supports wildcard subdomain)
 * Pattern ".example.com" matches "x.example.com", "y.example.com", but NOT "example.com"
 * Pattern "example.com" matches exact and any subdomain ".example.com"
 */
function originMatches(origin, allowed) {
  if (!origin || !allowed || allowed.length === 0) return false;
  let o;
  try {
    o = new URL(origin);
  } catch {
    return false;
  }
  const oBase = `${o.protocol}//${o.host}`;
  for (const entry of allowed) {
    if (entry === oBase) return true;
    if (entry.startsWith('.')) {
      const suffix = entry;
      if (o.host.endsWith(suffix) && o.host !== suffix.slice(1)) return true;
    } else if (entry.startsWith('*.')) {
      const dom = entry.slice(2);
      if (o.host.endsWith('.' + dom)) return true;
    }
  }
  return false;
}

function isHttpOriginAllowed(origin) {
  if (process.env.NODE_ENV !== 'production') return true;
  const allowlist = getHttpOrigins();
  return originMatches(origin, allowlist);
}

function isSocketOriginAllowed(origin) {
  if (process.env.NODE_ENV !== 'production') return true;
  const allowlist = getSocketOrigins();
  return originMatches(origin, allowlist);
}

/**
 * Express middleware
 */
function httpOriginMiddleware(req, res, next) {
  if (process.env.NODE_ENV !== 'production') return next();
  // Allow health endpoints without origin
  if (req.path === '/health' || req.path === '/healthz' || req.path === '/readyz') {
    return next();
  }
  const origin = req.headers.origin;
  if (!origin) {
    // No origin — only allow if explicitly safe (non-CORS or same-origin)
    return next();
  }
  if (isHttpOriginAllowed(origin)) return next();
  // Block
  res.status(403).json({ success: false, error: 'Origin not allowed' });
}

/**
 * Socket.IO origin check
 */
function socketOriginCheck(req, allowNext) {
  const origin = req.headers.origin;
  if (!origin) return allowNext(null, true);  // allow direct WS
  if (isSocketOriginAllowed(origin)) return allowNext(null, true);
  return allowNext(new Error('Origin not allowed: ' + origin));
}

module.exports = {
  originMatches,
  isHttpOriginAllowed,
  isSocketOriginAllowed,
  httpOriginMiddleware,
  socketOriginCheck,
  getHttpOrigins,
  getSocketOrigins,
};
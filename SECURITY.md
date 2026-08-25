# ECHO//LINE — Security Policy & Threat Model
**Project**: Cooperative Cross-Timeline Multiplayer Social Puzzle
**Stack**: Godot 4.7 (Android) · Node.js 18 LTS · PHP 8.3 (Hostinger shared) · MySQL 8.0
**Date**: 2026-08
**Classification**: Internal — do not distribute

---

## 1. Assets at Risk

| Asset | Sensitivity | Storage | Impact if Compromised |
|---|---|---|---|
| Admin credentials | Critical | MySQL (`admins.password_hash`) | Full control of game economy, configs, players |
| Player purchase receipts | High | MySQL (`receipt_verifications`) | Free items, refund abuse |
| Player progress & inventory | Medium | Game Server in-memory + MySQL backup | Cheating, account loss |
| API keys (Google Play, payment) | Critical | Server env + Admin config | Revenue loss, impersonation |
| Session cookies | High | Browser | Account takeover |
| Static CSRF token | Medium | PHP session | Cross-site action forgery |
| Configs (shop, events) | Low | MySQL + Admin UI | Game balance disruption |

---

## 2. Threat Model (STRIDE)

### S — Spoofing
- **T1.1**: Fake admin login → mitigated by bcrypt + sessions + CSRF + rate limiting.
- **T1.2**: Fake player UID → mitigated by HMAC-signed `playerUid` in handshake.
- **T1.3**: Game Server connection from unauthorized origin → mitigated by Origin allowlist.
- **T1.4**: Receipt forgery → mitigated by Google Play Developer API server-side check.

### T — Tampering
- **T2.1**: Intercepting and modifying game events → mitigated by TLS + server-authoritative state + idempotency keys.
- **T2.2**: SQL injection → mitigated by PDO prepared statements + input whitelisting.
- **T2.3**: Path traversal in admin → mitigated by file allowlist + basename validation.

### R — Repudiation
- **T3.1**: Player denies purchase → mitigated by tamper-resistant audit log + Google receipt signature.
- **T3.2**: Admin denies making changes → mitigated by Audit log + session-id binding.
- **T3.3**: Player denies cheating → mitigated by server-authoritative state + causal log.

### I — Information Disclosure
- **T4.1**: Log leakage of PII → mitigated by redaction layer (no tokens, no passwords, no IP raw).
- **T4.2**: Player data exposure between timelines → mitigated by `playerView()` filtering.
- **T4.3**: API disclosure of other rooms → mitigated by Room ownership scoping.

### D — Denial of Service
- **T5.1**: Spam rooms → mitigated by room cap (200) + per-IP rate limit.
- **T5.2**: Replay storm → mitigated by idempotency cache (5-min TTL).
- **T5.3**: API brute force → mitigated by per-IP + per-action rate limit.
- **T5.4**: DB connection exhaustion → mitigated by `max_user_connections` limit + Pool exhaustion alerts.

### E — Elevation of Privilege
- **T6.1**: Player → admin escalation → mitigated by RBAC + admin actions require `role=admin`.
- **T6.2**: API endpoint bypass → mitigated by HMAC signature on all privileged APIs.
- **T6.3**: Game Server → DB write access → mitigated by DB user scoped to specific tables only.

---

## 3. Authentication & Authorization

### 3.1 Players
- **Game Server**: Handshake via signed JWT or session ticket from API.
- **playerUid**: 16-byte random hex, generated server-side on first login.
- **Auth on every event**: Re-verified session token; expired → forced re-auth.
- **Rate limits** per UID: 3 interactions/sec, 10 quick messages/5sec.

### 3.2 Admin Panel
- **password_hash** with bcrypt (cost 12) — never plain text.
- **password_verify** on login; constant-time compare.
- **Session rotation** on every login (regenerate `session_id`).
- **RBAC roles**: `superadmin`, `editor`, `viewer` — server-side enforced.
- **CSRF token** rotated on login, checked on every state-changing request.
- **Login rate limit**: 5 attempts per 15 min per IP, lockout 1h.
- **2FA**: Required for `superadmin` role (TOTP stub for v1, hardware key in v2).

### 3.3 API (Game Server → Admin)
- **HMAC-SHA256** signature on every request.
- **timestamp** window ±5 min (replay protection).
- **nonce** single-use within 10 min (replay protection).
- **API key** stored in `process.env.ADMIN_API_KEY`, never in DB.

---

## 4. Input Validation & Sanitization

### 4.1 Game Server
- All events validated via JSON Schema (size limits, type checks).
- Max payload: 64 KB per event.
- Max string length: 256 chars; max array length: 50 items.
- Numeric ranges enforced (e.g., `x, y ∈ [0, 1000]`).
- Allowed fields whitelist per event type.
- Unknown fields silently dropped (forward compatibility).

### 4.2 Admin Panel
- All input via `Security::input()` with type coercion.
- Path operations via `basename()` + allowlist (no `..`, no `/`).
- File uploads validated by MIME + extension + size limit.
- HTML output via `Security::escape()` (htmlspecialchars).
- All API output: JSON only (no string concatenation into HTML).

### 4.3 Database
- All queries via PDO prepared statements (`PDO::ATTR_EMULATE_PREPARES => false`).
- No string concatenation into SQL.
- Identifier whitelisting (table/column names never from input).

---

## 5. Rate Limiting

### 5.1 Game Server
- **Per-UID**: 3 events/sec; 20 quick messages/5sec; 60 reconnects/min.
- **Per-IP**: 30 events/sec; 10 connections/min.
- **Global**: 50,000 events/sec across all rooms (anti-amplification).
- **Burst allowance**: 5 events in 200ms before limiter.

### 5.2 Admin Panel
- **Login**: 5 attempts/15min per IP.
- **Per-action**: 60 requests/min per admin.
- **Bulk operations**: 1 per hour per admin (export, archive reset).

---

## 6. Logging

### 6.1 Structured Format
- JSON lines: `{"ts":"2026-08-...","level":"info","event":"match.start","room_id":"r_abc","player_uid":"p_xyz"}`
- No PII in logs (player UIDs are opaque IDs, not emails/names).
- No tokens, no passwords, no full request bodies.
- IP addresses hashed with rotating salt.
- Logs shipped to append-only sink (Render logs / CloudWatch).

### 6.2 Audit Log (Admin)
- Separate append-only table: `admin_audit_log` (action, target, before, after, admin_uid, ts).
- Includes CSRF token id, session id, IP hash, user agent hash.
- Never deleted; rotation only after 7 years.

### 6.3 Retention
- Operational logs: 30 days.
- Audit logs: 7 years (compliance).
- Backups: 90 days.

---

## 7. Server-Authoritative Anti-Cheat

### 7.1 State Authority
- All state mutations happen on the server.
- Client sends **intent** (action, target); server validates and applies.
- Idempotency keys prevent replay attacks.
- Server-authoritative causal log captures every state change.

### 7.2 Validations
- Every interaction has preconditions — server checks before applying.
- Win conditions evaluated only on server.
- Anti-tamper: client cannot claim rewards; rewards come from server state.
- Quick messages are server-curated, no free text input.
- Voice chat disabled by default (age gate).

### 7.3 Receipt Verification
- All IAP receipts verified server-side via Google Play Developer API.
- Receipts stored with hash + orderId + purchaseToken.
- Duplicate receipts rejected by UNIQUE constraint.
- Refunds → server-side removal of granted contents (compensating transaction).

---

## 8. Network & Transport

- TLS 1.3 only (Render handles cert renewal).
- HSTS enabled.
- CORS: Origin allowlist (no `*` for authenticated endpoints).
- WebSocket origin check (must match allowlist).
- HTTP/2 enabled on Render.

### 8.1 Origin Allowlist
- Game Client: `https://echoline.eduiraq.net`
- Admin Panel: `https://echoline.eduiraq.net/admin`
- Game Server: client IPs not allowlisted (server is stateless w.r.t. clients).

---

## 9. Database Hardening

- MySQL user `echoline_app` with `SELECT, INSERT, UPDATE, DELETE` only.
- No `DROP`, `ALTER`, `GRANT` for app user.
- All credentials in env vars; never in code.
- `sql_mode=STRICT_ALL_TABLES,NO_ZERO_DATE,NO_ENGINE_SUBSTITUTION`.
- Backups: daily (Render managed), 30-day retention, off-site copy weekly.
- Restore tested monthly (dry run in staging).
- Unique constraints on receipts, idempotency keys, sessions.
- Indexes on: `player_uid`, `room_id`, `ts`, `idempotency_key`, `(scenario_id, player_uid)`.

---

## 10. Session & Cookie Security (Admin)

```php
session_set_cookie_params([
    'lifetime' => 3600,
    'path'     => '/admin/',
    'secure'   => APP_ENV === 'production',
    'httponly' => true,
    'samesite' => 'Lax',
    'domain'   => 'echoline.eduiraq.net',
]);
```

- 1-hour idle timeout.
- 8-hour absolute timeout.
- Session rotation on login, on privilege change.
- IP hash binding (warn on change but allow).
- `SameSite=Lax` to prevent CSRF via cross-site.

---

## 11. CSRF Protection

- Token in session and per-form.
- 64 bytes (512 bits) entropy.
- `hash_equals` for constant-time compare.
- Token invalidated on logout.
- Per-action token (not one-fits-all) for sensitive ops.

---

## 12. Install.php Lockout

- After first successful install: `install.lock` file created.
- `install.php` checks for lock; refuses to run if present.
- Lock file in non-public path; signed with HMAC of DB password hash.
- Manual uninstall + re-install requires admin CLI access.

---

## 13. Graceful Shutdown (Game Server)

```js
process.on('SIGTERM', () => {
  server.close(() => process.exit(0));  // stop accepting connections
  setTimeout(() => process.exit(1), 10_000);  // force after 10s
});
```

- Stop accepting new connections.
- Drain active rooms gracefully (send `server:closing` event).
- Save room state to DB if persistence enabled.
- Force-kill after 10s if still alive.

---

## 14. Health & Readiness

- `GET /healthz` — liveness, returns 200 OK if process alive.
- `GET /readyz` — readiness, returns 200 only if:
  - DB connection OK
  - Admin Bridge reachable (cached config)
  - Scenarios loaded
  - < 200 active rooms
- Separate from public API.
- Kubernetes-style probes compatible.

---

## 15. Incident Response Plan

### Severity Levels
| Sev | Description | Response SLA |
|---|---|---|
| **P0** | Active exploit, data loss, total outage | 30 min |
| **P1** | Significant degradation, partial breach | 2h |
| **P2** | Limited impact, fix needed | 24h |
| **P3** | Cosmetic, hardening | 1 week |

### Roles
- **Incident Commander**: Coordinates response.
- **Tech Lead**: Owns technical fix.
- **Comms Lead**: Internal/external messaging.
- **Scribe**: Logs every action.

### Playbooks

#### PB-01: Credential Compromise
1. Rotate admin passwords immediately.
2. Invalidate all sessions (`DELETE FROM sessions`).
3. Review audit log for unauthorized actions.
4. Notify affected admins.
5. Force password reset on next login.

#### PB-02: SQL Injection Attempt
1. Identify vulnerable query from log.
2. Apply prepared statement patch.
3. Review affected rows.
4. Add WAF rule.
5. Test with sqlmap.

#### PB-03: Game Server DoS
1. Engage Render DDoS protection.
2. Increase rate-limit thresholds temporarily.
3. Identify attack pattern from logs.
4. Apply IP-level blocks.
5. Communicate to players.

#### PB-04: Payment Fraud
1. Freeze affected account.
2. Reverse fraudulent grants (compensating transaction).
3. Report to Google Play.
4. Update receipt verification rules.

#### PB-05: Data Breach
1. Identify scope and affected data.
2. Notify users per GDPR (within 72h).
3. File regulatory reports.
4. Reset all credentials.
5. Post-mortem within 1 week.

---

## 16. Backup & Recovery

- Daily DB backup (Render automated), 30-day retention.
- Off-site copy weekly (S3 + encryption).
- Monthly restore drill in staging.
- Code backups: GitHub (`SaifHu98/echoline`, `main` branch).
- Configs: versioned in `web/admin/data/` (DB-seeded).

---

## 17. Compliance

- **GDPR**: data minimization, right to deletion (90-day grace), export.
- **COPPA**: under-13 cannot play without parental consent (out of scope for v1, planned).
- **Apple App Store**: IAP receipts verified server-side, no PII in analytics.
- **Google Play**: target API 34+, data safety form accurate.

---

## 18. Secrets Management

- All secrets in environment variables.
- `.env` files gitignored.
- Production secrets in Render dashboard / Hostinger control panel.
- Rotation policy: every 90 days for keys, immediately on compromise.
- No secrets in logs, code, or DB.

---

## 19. Dependency Security

- `npm audit` on every PR.
- `composer audit` on every PR.
- Auto-update minor/patch versions.
- Pin major versions.
- Subscribe to GitHub security advisories.

---

## 20. Testing Requirements

- Schema validation unit tests for every event.
- Rate limit tests under burst load.
- CSRF token rotation tests.
- HMAC signature verification tests.
- Receipt replay tests.
- DB transaction rollback tests on failure.
- SQL injection tests with sqlmap (staging only).

---

## 21. Acceptance Checklist (every PR)

- [ ] No secrets in code or logs
- [ ] All input validated via schema or whitelist
- [ ] All DB queries via prepared statements
- [ ] Admin actions generate audit log entries
- [ ] Rate limits in place for new endpoints
- [ ] Tests cover happy path + adversarial path
- [ ] No new dark patterns (per `dark_patterns_guard`)
- [ ] No PII in logs
- [ ] Origin allowlist updated if new endpoint
- [ ] Backwards-compatible (graceful for old clients)

---

## 22. Files Delivered

| File | Purpose |
|---|---|
| `game-server/src/security/auth.js` | JWT/HMAC token validation |
| `game-server/src/security/schema.js` | JSON schema validators |
| `game-server/src/security/rateLimit.js` | Per-UID/IP rate limiter |
| `game-server/src/security/allowlist.js` | Origin allowlist |
| `game-server/src/security/logger.js` | Structured redacted logger |
| `game-server/src/security/gracefulShutdown.js` | SIGTERM handler |
| `game-server/src/security/healthChecks.js` | /healthz, /readyz |
| `game-server/tests/security/*.test.js` | Security unit tests |
| `web/admin/includes/Security.php` (updated) | +HMAC, +install lock |
| `web/admin/includes/Auth.php` (updated) | +RBAC, +session rotation |
| `web/admin/includes/RateLimiter.php` (new) | +Redis-less |
| `web/admin/api/signed_request.php` (new) | HMAC verifier |
| `web/admin/api/receipt_verifier.php` (new) | Google Play verification |
| `web/admin/install.lock` (new) | Auto-generated on install |
| `web/admin/database/migrations/03_security.sql` (new) | Indexes, unique constraints |
| `web/admin/scripts/backup.sh` (new) | Daily DB backup |
| `web/admin/scripts/restore_drill.sh` (new) | Monthly restore test |
| `SECURITY.md` | This document |

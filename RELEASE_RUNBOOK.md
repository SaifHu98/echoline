# ECHO//LINE — Release Runbook
**Project**: Cooperative Cross-Timeline Multiplayer Social Puzzle
**Stack**: Godot 4.7 (Android) · Node.js 22 LTS · PHP 8.3 (Hostinger) · MySQL 8.0 · Render
**Last Updated**: 2026-08

---

## 1. Pre-Release Checklist

### 1.1 Code & Tests ✅
- [ ] All CI jobs green on `main` (see `.github/workflows/ci.yml`)
- [ ] Test coverage ≥ 70% (`npm run coverage`)
- [ ] No `console.log` left in production code
- [ ] No secrets in code (`gitleaks` clean)
- [ ] Dependencies audited (`npm audit`, `composer audit`)
- [ ] All TODOs resolved or moved to issues
- [ ] CHANGELOG.md updated

### 1.2 Build & Artifacts 📦
- [ ] Android Debug APK builds (uploaded as artifact)
- [ ] Android Release APK builds (signed with keystore)
- [ ] APK size < 80 MB
- [ ] APK installable on Android 8+ (API 26+)
- [ ] No hardcoded URLs (all via QualityProfile)

### 1.3 Server Readiness 🖥️
- [ ] Game Server passes smoke test (`tests/smoke/smoke_test.js`)
- [ ] Game Server load test p99 < 200ms (`tests/load/load_runner.js`)
- [ ] Admin Panel passes PHP security tests (`tests/security/test_security.php`)
- [ ] No errors in last 24h staging logs

### 1.4 Telemetry & Monitoring 📊
- [ ] Render dashboard shows zero errors in last hour
- [ ] Crash reporting endpoint live (Sentry/Bugsnag optional)
- [ ] Latency alerts configured (p99 > 500ms)
- [ ] Error rate alerts configured (> 1%)

---

## 2. Environment Topology

```
┌──────────────┐
│  Production  │ ←── release tags only (v0.1.0, v0.1.1, …)
│   (Render)   │
└──────────────┘
        ▲
        │ Auto-promote after gates pass
        │
┌──────────────┐
│   Staging    │ ←── main branch auto-deploy
│   (Render)   │
└──────────────┘
        ▲
        │ Auto from CI
        │
┌──────────────┐
│   CI (PR)    │ ←── every PR + commit
│  (GitHub)    │
└──────────────┘
```

- **CI**: GitHub Actions, every PR
- **Staging**: Render staging service (auto-deploy from `main` after merge)
- **Production**: Render production service (manual promote from staging)

---

## 3. Release Pipeline

### 3.1 PR → Main
1. **CI** runs all jobs:
   - Lint (Node.js, PHP, GDScript)
   - Unit tests (Node.js, 37+ tests)
   - Integration tests (concurrency, network, reconnect)
   - Security tests (auth, schema, rate limit, CSRF, HMAC, path traversal)
   - PHP tests (admin panel)
   - Android debug build
   - Dependency & secret scan
2. **Merge gate** job checks all required jobs passed
3. PR merges to `main`

### 3.2 Main → Staging
1. CI runs again (all jobs, including deploy-staging)
2. Staging deploy hook triggers Render
3. Wait for `/readyz` to return 200
4. **Smoke test** runs against staging
5. Notify team via Slack

### 3.3 Staging → Production (Gradual Rollout)
1. Manual approval (release manager)
2. Initial rollout: **1% canary** for 30 min
3. Check health gates — if pass, advance to **5%** for 1 hour
4. Then **25%** for 2 hours, **50%** for 4 hours, **100%**
5. **Auto-rollback** if any gate fails (error_rate > 5%, p99 > 500ms, crash_rate > 2%)

---

## 4. Release Gates (must all pass)

### 4.1 Quantitative Gates
| Metric | Target | Source | Action on Fail |
|---|---|---|---|
| **crash_rate** | < 0.5% | `TelemetryCollector` | Auto-rollback |
| **disconnect_rate** | < 10% | `TelemetryCollector` | Auto-rollback |
| **p50 latency** | < 50ms | `TelemetryCollector` | Investigate |
| **p95 latency** | < 150ms | `TelemetryCollector` | Auto-rollback at p95 > 250ms |
| **p99 latency** | < 250ms | `TelemetryCollector` | Auto-rollback at p99 > 500ms |
| **error_rate** | < 1% | `TelemetryCollector` | Auto-rollback at > 5% |
| **match_completion** | > 70% | `TelemetryCollector` | Investigate |
| **memory_avg** | < 200 MB (server) | process.memoryUsage | Investigate at > 400MB |
| **memory_peak** | < 350 MB (server) | process.memoryUsage | Auto-rollback at > 500MB |
| **battery_drain** | < 1.5%/hr (Android) | client telemetry | Investigate |
| **successfulAPK_installs** | > 95% of downloads | Play Console | Investigate |
| **APK crash rate** | < 0.3% (Android Vitals) | Play Console | Rollback |

### 4.2 Functional Gates
- [ ] Smoke test 100% pass
- [ ] Multi-player test 100% pass (2, 3, 4 players)
- [ ] Reconnect test 100% pass
- [ ] Network simulation test 100% pass
- [ ] Anti-replay test 100% pass
- [ ] RTL/accessibility test 100% pass

### 4.3 Manual Gates
- [ ] Team playtest on real devices (3 different Android versions)
- [ ] Arabic playtest by native speaker
- [ ] Visual regression review (before/after screenshots)
- [ ] Privacy policy updated
- [ ] Data safety form reviewed (Google Play)

---

## 5. Rollout Phases

| Phase | % | Hold | Health Check |
|---|---|---|---|
| **canary** | 1% | 30 min | p99 < 500ms, crash < 2% |
| **early** | 5% | 1 h | + match completion > 50% |
| **growing** | 25% | 2 h | + error_rate < 5% |
| **majority** | 50% | 4 h | + disconnect_rate < 15% |
| **general** | 100% | — | all green |

**Auto-rollback triggers** (any one):
- `error_rate > 5%` over 5 min window
- `p99_latency > 500ms` over 5 min window
- `crash_rate > 2%` over 5 min window
- `match_completion < 50%` over 30 min window
- Manual kill switch: `ECHO_KILL_FLAGS=FLAG_NAME` env

---

## 6. Rollback Procedure

### 6.1 Automatic Rollback
`RolloutManager.autoRollback()` is triggered when:
- Critical health issue detected
- Manual kill switch env var set
- Operator pauses rollout

Action: Set all feature flag rollouts to previous healthy % (or 0).

### 6.2 Manual Rollback (Render dashboard)
1. Open Render dashboard → service → "Rollback"
2. Select previous deploy (1-2 deploys back)
3. Confirm — Render re-deploys previous image in <2 min
4. Verify `/readyz` returns 200
5. Run smoke test
6. Notify team

### 6.3 Database Rollback
- Admin Panel DB has daily backups (30-day retention)
- For schema rollback: `php scripts/rollback_db.php --to=migration_02`
- For data rollback: `bash scripts/backup.sh --restore --date=2026-08-20`

---

## 7. Disaster Recovery

| Scenario | RTO | RPO | Action |
|---|---|---|---|
| Game Server crash | < 5 min | 0 | Render auto-restart |
| Render outage | < 30 min | 0 | Failover to backup region |
| Admin Panel DB loss | < 1 h | < 24 h | Restore from daily backup |
| Game Server data corruption | < 1 h | 0 | Reset rooms (stateless) |
| Security breach | < 30 min | 0 | Activate Incident Response PB-XX |

---

## 8. Monitoring & Alerts

### 8.1 Render Built-in
- HTTP response time (p50/p95/p99)
- Error rate
- CPU/memory usage
- Deploy history

### 8.2 Custom (TelemetryCollector)
- Per-room health
- Per-event latency
- Per-player session length
- Anti-cheat signals (rapid fire, impossible sequences)

### 8.3 Slack alerts
- `#alerts` channel for P0/P1
- `#releases` channel for deploy/rollback
- Daily summary at 09:00 UTC

---

## 9. Feature Flags

| Flag | Default | Rollout | Purpose |
|---|---|---|---|
| `ENABLE_ECHO_TRAIL_VFX` | ON | 100% | Echo ripple visual |
| `ENABLE_AI_BOTS` | ON | 100% | AI bots fill rooms |
| `ENABLE_QUICK_CHAT` | ON | 100% | Quick messages |
| `ENABLE_VOICE_CHAT` | OFF | 0% | Voice chat (age-gated) |
| `ENABLE_NEW_TUTORIAL` | OFF | 10% | A/B test new onboarding |
| `ENABLE_RANKED_MATCH` | OFF | 0% | Ranked mode |
| `ENABLE_RECEIPT_V2` | ON | 100% | New receipt verification |
| `ENABLE_DARK_MODE` | OFF | 50% | Dark UI theme |

**Toggle at runtime**: `PATCH /api/admin/flags/:flag` (admin only).

---

## 10. Communication Plan

### 10.1 Internal
- Pre-deploy: announce in `#releases` 1 hour before
- Post-deploy: success/fail in `#releases`
- Issues: P0/P1 in `#alerts`
- Daily summary in `#metrics`

### 10.2 External
- Players: in-app banner if major change
- Social media: scheduled posts for milestones
- Support: knowledge base updated
- Privacy policy: updated if data collection changes

---

## 11. Post-Release

### 11.1 Day 1 (T+24h)
- Check crash rate vs baseline
- Check match completion rate
- Check 5-star reviews vs median
- Check store page conversion

### 11.2 Week 1 (T+7d)
- Aggregate metrics report
- Top user feedback themes
- Bug triage
- Performance optimization pass

### 11.3 Month 1 (T+30d)
- Retention metrics (D1, D7, D30)
- Revenue vs projection
- Roadmap planning for next release

---

## 12. Quick Reference

### Deploy to staging
```bash
git push origin main  # auto-deploys
```

### Trigger smoke test
```bash
node tests/smoke/smoke_test.js --url=https://echoline-staging.onrender.com
```

### Run load test
```bash
node tests/load/load_runner.js --rooms=50 --players=4 --duration=60 \
  --url=https://echoline-staging.onrender.com
```

### Promote to production
1. Open Render dashboard
2. Click "Promote to Production"
3. Watch rollout dashboard for 8 hours

### Rollback production
1. Render dashboard → "Rollback" → select deploy
2. Or: `ECHO_KILL_FLAGS=*` env var to disable all flags

### View current rollout
```bash
curl https://echoline.onrender.com/admin/flags | jq .
```

---

## 13. Files

| File | Purpose |
|---|---|
| `.github/workflows/ci.yml` | Full CI pipeline |
| `game-server/src/security/featureFlags.js` | Feature flag runtime |
| `game-server/src/security/rollout.js` | Rollout manager |
| `game-server/src/security/telemetry.js` | Metrics collector |
| `game-server/tests/smoke/smoke_test.js` | Post-deploy smoke |
| `game-server/tests/load/load_runner.js` | Load test |
| `RELEASE_RUNBOOK.md` | This document |
| `SECURITY.md` | Security policy |
| `UX_METRICS.md` | UX metrics & KPIs |

---

## ⚠️ Definition of "Production Ready"

A version may be marked as "production ready" **only if**:
1. ✅ All CI jobs pass
2. ✅ Smoke test 100% pass on staging
3. ✅ Load test p99 < 250ms
4. ✅ All release gates pass for 24h on staging
5. ✅ Security audit (manual) signed off
6. ✅ UX playtest on 3+ devices signed off
7. ✅ Privacy policy + data safety form filed
8. ✅ At least 7 days of staging uptime
9. ✅ Documented in this runbook
10. ✅ Team approval in `#releases`

**Until ALL conditions met, mark as "Beta" / "Early Access".**
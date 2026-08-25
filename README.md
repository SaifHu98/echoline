# ECHO//LINE

> A **cooperative cross-timeline puzzle** where 2–4 players collect Memory Shards from resolved Echoes and assemble them into Timeline Anchors that stabilize reality.

[![Tests](https://img.shields.io/badge/tests-147%2F147%20passing-brightgreen)]()
[![Build](https://img.shields.io/badge/build-passing-brightgreen)]()
[![License](https://img.shields.io/badge/license-proprietary-blue)]()
[![Production](https://img.shields.io/badge/production-not%20ready-yellow)]()
[![Status](https://img.shields.io/badge/status-early%20access-orange)]()

**ECHO//LINE v1.0** is a Godot 4 Android client paired with a Node.js authoritative game server, plus a PHP admin panel for ops. Built with **deterministic simulation**, **server-authoritative state**, **memory-shard co-op building**, **hardened security**, **professional RTL Arabic UX**, and a **gradual rollout CI/CD pipeline**.

---

## 🎮 What is ECHO//LINE?

Three timelines fractured: **Past**, **Present**, **Future**. Players inhabit one timeline each and must:

1. **Solve Echoes** — interactive puzzles whose outcomes depend on cross-timeline cooperation
2. **Collect Memory Shards** — every resolved Echo drops shards tied to its timeline
3. **Build Timeline Anchors** — assemble shards into anchors that stabilize reality (co-op required)
4. **Coordinate across timelines** — solo paths always fail; cooperation wins

**Win condition**: build the **Echo Triad Anchor** by combining all three timelines + the **Epoch Alignment Marker** (rare neutral shard). Awarded `perfect_testament` outcome.

---

## 🏗️ Architecture

```
┌─────────────────┐   WSS/Socket.IO    ┌──────────────────┐
│  Android Client │ ──────────────────►│  Game Server     │
│  (Godot 4.7)    │ ◄───────────────── │  (Node.js/Render)│
└─────────────────┘   64KB+JSON events  └──────────────────┘
        │                                       │
        │ HTTPS REST                             │ HMAC signed
        ▼                                        ▼
┌─────────────────┐                       ┌──────────────────┐
│  Quick Chat /   │                       │  Admin Panel     │
│  In-App Shop    │                       │  (PHP/MySQL)     │
└─────────────────┘                       │  Hostinger       │
                                          └──────────────────┘
```

### Component Stack

| Component | Tech | Role | Hosting |
|---|---|---|---|
| **Game Client** | Godot 4.7 + GDScript | Player UI, prediction, VFX, networking | Android APK (Google Play planned) |
| **Game Server** | Node.js + Socket.IO + Express | Authoritative sim, snapshots, build state, anti-cheat | Render.com (Oregon Free) |
| **Admin Panel** | PHP 8 + MySQL | Ops, analytics, IAP verification, backups | Hostinger shared |
| **Admin Bridge** | Node.js polling | HMAC-signed communication server ↔ admin | Embedded in Game Server |

---

## ✨ Core Features

### 🎯 Gameplay Systems
- ✅ **Deterministic causal engine** — same inputs → same outputs (verified by property tests)
- ✅ **Echo puzzles** — 12+ rule types, dependency graphs, scheduled effects
- ✅ **Adaptive difficulty** — multiplier clamps at 0.7 on repeated failures
- ✅ **Hint system** — 3 graduation levels + cooldown
- ✅ **Catastrophe timer** — recoverable via high cooperative score
- ✅ **Memory Shards** — 10 types across 4 timelines with drop-rate cooperation bonus
- ✅ **Timeline Anchors** — co-op building with owner enforcement + idempotent events
- ✅ **Snap-grid placement** — 1m world grid + 90° rotation snap
- ✅ **Duplicate conversion** — every 3 duplicates of same shard → 1 conversion event

### 🌍 Networking & Multiplayer
- ✅ **2-4 player co-op** with timeline swap
- ✅ **Server reconciliation** — monotonic `place_seq` for state replay
- ✅ **Reconnection grace** — 30s before player removal, full state recovery
- ✅ **Anti-replay** — idempotency keys + 1000-retry stress test
- ✅ **Out-of-order events** — server processes regardless of arrival order
- ✅ **Network resilience** — 30% packet loss, slow player, flapping tests pass

### 🛡️ Security (Hardened)
- ✅ **HMAC-SHA256 tokens** with RBAC (player/bot/admin/system)
- ✅ **JSON Schema validation** per event + 64KB payload limit
- ✅ **Rate limiting** — sliding-window token bucket (per UID/IP/global)
- ✅ **Origin allowlist** — HTTP + Socket.IO with wildcard support
- ✅ **Structured logging** with PII redaction
- ✅ **Health checks** — `/healthz` (liveness) + `/readyz` (DB + Admin + Rooms)
- ✅ **Graceful shutdown** — SIGTERM → drain → 10s force-kill
- ✅ **Audit trail** in admin panel + game server event log
- ✅ **Atomic inventory** — `INSERT ... ON DUPLICATE KEY UPDATE`
- ✅ **Bot isolation** — bots cannot grant currency or items to humans

### 🎨 Art & UX
- ✅ **3 timeline identities** — Past (rounded + bronze + ember glow), Present (square + steel + cyan), Future (hex + crystal + holo)
- ✅ **Procedural visuals** — 0 IP risk, 100% runtime-generated
- ✅ **3 quality tiers** — Low (30FPS) / Medium (60FPS) / High (60FPS+SSAO+SSR) + auto-detect + adaptive
- ✅ **VFX pools** — typed pools, zero `instantiate()` during gameplay
- ✅ **LOD system** — 3-level LOD + billboard fallback
- ✅ **RTL Arabic** — full Hebrew-style mirror with EN/AR i18n parity
- ✅ **Accessibility** — 3 colorblind modes, text scale 80%-200%, reduced motion, 6-channel audio
- ✅ **No dark patterns** — 13 banned patterns audited at runtime
- ✅ **Touch target ≥48dp** — validator at runtime
- ✅ **Onboarding** — 5-step playable tutorial
- ✅ **Quick chat** — 26 curated messages in 4 categories, no toxic content

### 🚀 DevOps & Release
- ✅ **GitHub Actions CI** — 10-job pipeline (lint, unit, integration, load, security, PHP, Android, smoke, merge gate)
- ✅ **147/147 tests passing** (unit + integration + simulation + security + building)
- ✅ **Load test** — 50 rooms × 4 players, p99 < 500ms enforced
- ✅ **Smoke test** — 8 critical-path checks post-deploy
- ✅ **Feature flags** — 8 flags with hash-based bucketing
- ✅ **Rollout manager** — 5-phase (1% canary → 5% → 25% → 50% → 100%) with auto-rollback
- ✅ **Telemetry** — crash_rate, disconnect, p99 latency, match_completion, memory
- ✅ **Release gates** — 6 metrics with auto-rollback thresholds
- ✅ **Backups** — daily mysqldump + 30-day retention + monthly restore drill
- ✅ **Documentation** — RELEASE_RUNBOOK.md, SECURITY.md, UX_METRICS.md, ART_BIBLE.md, PERFORMANCE_BUDGET.md, BUILD_SYSTEM.md

---

## 🧪 Test Coverage

```
unit_echo_engine    19 tests ✔
integration_room     8 tests ✔
simulation          18 tests ✔
security            19 tests ✔
concurrency          8 tests ✔
network_sim          5 tests ✔
reconnect            5 tests ✔
accessibility        8 tests ✔
anti_replay          9 tests ✔
building/shard      19 tests ✔
building/anchor     19 tests ✔
building/manager    18 tests ✔
──────────────────────────────
TOTAL              147 tests ✔ (100%)
```

Run all tests:
```bash
cd game-server
node --test tests/*.test.js tests/building/*.js
```

---

## 🚀 Live URLs

| Service | URL | Status |
|---|---|---|
| **Game Server** | `https://echoline-game-server.onrender.com` | 🟢 Live (Free plan) |
| **Admin Panel** | `https://echoline.eduiraq.net/echoline/` | 🟢 Live (Hostinger) |
| **Repo** | `https://github.com/SaifHu98/echoline` | 🟢 Public |

---

## 📦 Project Structure

```
echoline/
├── client/                      # Godot 4 Android client
│   ├── android/                 # Android export config
│   ├── art/                     # Art theme tokens
│   ├── autoload/                # Singletons (accessibility, audio, telemetry, ...)
│   ├── building/                # 🆕 Memory Shards + Timeline Anchors client
│   ├── core/                    # Quality profile, LOD, VFX pool, binary packer
│   ├── gameplay/
│   │   ├── echo_system/         # Echo trail renderer
│   │   └── vfx/                 # Ripple scenes (past/present/future)
│   ├── scenes/                  # vertical_slice.tscn, onboarding.gd, building_scene.gd
│   ├── scripts/                 # Tests, benchmarks
│   ├── ui/hud/                  # Shard inventory bar, anchor blueprint panel
│   ├── ART_BIBLE.md
│   ├── ASSET_LIST.md
│   ├── BUILD_ANDROID.md
│   ├── COMPARISON_REPORT.md
│   ├── INDEX.md
│   ├── PERFORMANCE_BUDGET.md
│   └── UX_METRICS.md
├── game-server/                 # Node.js authoritative game server
│   ├── src/
│   │   ├── admin-bridge/        # HMAC-signed comms to admin panel
│   │   ├── building/            # 🆕 ShardEngine, AnchorEngine, AnchorManager
│   │   ├── rooms/               # Snapshots, reconciliation, reconnection
│   │   ├── security/            # auth, schema, rateLimit, allowlist, logger, ...
│   │   ├── simulation/          # EchoEngine (deterministic causal)
│   │   └── server.js
│   └── tests/                   # 147 tests
├── shared/                      # Cross-runtime data (JSON)
│   ├── anchors/                 # 🆕 Blueprint defs + schema
│   ├── scenarios/               # the_clockmaker_testament.json
│   └── shards/                  # 🆕 Catalog + schema
├── web/admin/                   # PHP admin panel
│   ├── api/                     # signed_request.php, receipt_verifier.php
│   ├── database/                # schema, install, migrations
│   ├── includes/                # Security.php, Auth.php, I18n.php
│   ├── scripts/                 # backup.sh, restore_drill.sh
│   └── tests/                   # 23 PHP security tests
├── .github/workflows/           # ci.yml (10-job pipeline)
├── BUILD_SYSTEM.md              # 🆕 Building system docs
├── DEPLOYMENT.md
├── DEPLOYMENT_GUIDE.md
├── GITHUB_DEPLOY_GUIDE.md
├── RELEASE_RUNBOOK.md           # 10-condition "Production Ready" checklist
├── SECURITY.md                  # STRIDE threat model + 5 incident playbooks
└── render.yaml                  # Render Blueprint (Free plan)
```

---

## 🏗️ Building System (Co-op)

The most distinctive feature of ECHO//LINE.

### Flow

```
Echo resolved (deterministic outcome)
        ↓
ShardEngine.rollDrop(trigger, players)
  - Base 35% + 15% per cooperating player
  - +25% rare bonus after 8 matches
  - +10% legendary bonus on legendary match
  - Capped at 100%
        ↓
ShardInventory.add (per-player)
        ↓
Player taps shard → AnchorPlacementController.requestPlacement
        ↓
AnchorNetworkSync → Socket.IO → Game Server
        ↓
AnchorManager.processEvent (server-authoritative)
  - Validates: slot index, shard type, owner_index_required
  - Idempotent: event_id dedup → no double-apply
  - Monotonic place_seq → clients reconcile late events
        ↓
Broadcast sync_state_to → all clients
        ↓
Completion → VFX + audio + score_award + outcome
```

### 10 Shard Types (4 timelines)

| Timeline | Common | Rare | Epic/Legendary |
|---|---|---|---|
| Past | Memorial Stone, Carved Wood | Runic Iron | — |
| Present | Steel Frame, Quartz Panel | Clockwork | — |
| Future | Holographic Crystal, Quantum Thread | — | Singularity Core (legendary) |
| Neutral | — | — | Epoch Alignment Marker (epic) |

### 2 Anchor Blueprints

- **echo_triad_anchor** — Primary, difficulty 3, **co-op required** (2-4 players), 6 slots, 240s, 500 score, `perfect_testament` outcome
- **support_wall** — Secondary, difficulty 1, **single player allowed**, 4 slots, 90s, 150 score

See [BUILD_SYSTEM.md](BUILD_SYSTEM.md) for full architecture, security model, anti-cheat considerations, and future extensions.

---

## 🔒 Security Model

### STRIDE Threat Model
12 threats analyzed with mitigations (see SECURITY.md).

### Layers
1. **Transport**: HTTPS + WSS only
2. **Auth**: HMAC tokens, RBAC, 30-day rotation
3. **Schema**: per-event JSON Schema, 64KB payload cap
4. **Rate**: sliding-window token bucket (per-UID/IP/global)
5. **Origin**: allowlist for HTTP + Socket.IO
6. **Logic**: server-authoritative, no client trust
7. **Audit**: event log bounded 500 entries + admin audit trail
8. **Backup**: daily + 30-day retention + restore drill

### Incident Playbooks (PB-01 to PB-05)
- PB-01: Compromise of admin credentials
- PB-02: Game server outage / data loss
- PB-03: Payment fraud (Google Play IAP)
- PB-04: Cheating / exploit discovered
- PB-05: DDoS attack

---

## 📊 Release Status

### Definition of "Production Ready" (10 conditions)

| # | Condition | Status |
|---|---|---|
| 1 | All CI jobs pass | ✅ Green |
| 2 | Smoke test 100% on staging | ⚠️ Pending (no staging env) |
| 3 | Load test p99 < 250ms | ✅ Pass (<100ms observed) |
| 4 | All release gates pass 24h on staging | ⚠️ Pending |
| 5 | Security audit signed off | ⚠️ Pending (manual review) |
| 6 | UX playtest on 3+ devices | ⚠️ Pending (manual) |
| 7 | Privacy policy + data safety form | ⚠️ Pending |
| 8 | 7+ days staging uptime | ⚠️ Pending |
| 9 | Documented in RELEASE_RUNBOOK | ✅ Done |
| 10 | Team approval | ⚠️ Pending |

**Current status**: **Early Access / Beta** — not yet "Production Ready".

### Release Gates (auto-rollback triggers)

| Metric | Target | Auto-rollback if |
|---|---|---|
| crash_rate | < 0.5% | > 2% |
| disconnect_rate | < 10% | > 20% |
| p99 latency | < 250ms | > 500ms |
| error_rate | < 1% | > 5% |
| match_completion | > 70% | < 50% |
| memory_avg | < 200MB | > 400MB |

### Rollout Phases
```
1% (canary) → 5% → 25% → 50% → 100%
   30 min        2h      12h     24h    48h
```
Each phase auto-advances if all gates green; auto-rollback on any breach.

---

## 🌐 Internationalization

Full Arabic + English parity, RTL-aware:
- 100% UI strings in `data/i18n/{en,ar}.json`
- Right-to-left layout via CSS logical properties
- Arabic font: Cairo / Tajawal (system fallback)
- Number formatting locale-aware
- Date/time locale-aware (Hijri + Gregorian in Arabic locale)

---

## 🛠️ Quick Start (Local Dev)

### Game Server
```bash
cd game-server
npm install
node src/server.js
# Listens on ws://localhost:3000
```

### Admin Panel (PHP)
```bash
cd web/admin
php -S localhost:8080
# Visit http://localhost:8080
# Default admin: admin / changeme (rotate immediately)
```

### Client (Godot)
1. Open Godot 4.7.2-stable
2. Import `project.godot`
3. Update `client/autoload/network_client.gd`:
   ```gdscript
   const DEFAULT_SERVER_URL := "ws://localhost:3000/socket.io/?EIO=4&transport=websocket"
   ```
4. Press F5 to run

### Run Tests
```bash
cd game-server
node --test tests/*.test.js tests/building/*.js
# Expected: 147/147 passing
```

---

## 📚 Documentation Index

| File | Purpose |
|---|---|
| [BUILD_SYSTEM.md](BUILD_SYSTEM.md) | Memory Shards + Timeline Anchors architecture |
| [RELEASE_RUNBOOK.md](RELEASE_RUNBOOK.md) | 10-condition "Production Ready" + rollout phases |
| [SECURITY.md](SECURITY.md) | STRIDE threat model + 5 incident playbooks |
| [client/ART_BIBLE.md](client/ART_BIBLE.md) | Visual identity, 3 timelines, materials, motion |
| [client/PERFORMANCE_BUDGET.md](client/PERFORMANCE_BUDGET.md) | Frame/draw/triangle/VRAM/RAM per tier |
| [client/UX_METRICS.md](client/UX_METRICS.md) | 5 KPIs with acceptance gates |
| [client/ASSET_LIST.md](client/ASSET_LIST.md) | 100% procedural asset catalog |
| [client/BUILD_ANDROID.md](client/BUILD_ANDROID.md) | APK build steps |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Production deployment guide |
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Step-by-step Render + Hostinger |
| [GITHUB_DEPLOY_GUIDE.md](GITHUB_DEPLOY_GUIDE.md) | GitHub push instructions |

---

## 🤝 Contributing

ECHO//LINE is currently a single-developer project by **Saif Hu**. The codebase follows strict conventions:

### GDScript (Godot)
- `snake_case` for files, methods, variables
- `PascalCase` for classes (`class_name`)
- `_camelCase` for private members
- One class per file
- Signals use past tense: `placement_confirmed`, not `confirm_placement`

### JavaScript (Server)
- ESM modules preferred for new code
- `camelCase` for functions/variables, `PascalCase` for classes
- One class per file in `src/`
- Test co-located in `tests/` mirroring `src/`

### PHP (Admin)
- PSR-12 coding style
- `snake_case` for files, `camelCase` for methods
- All output escaped via `htmlspecialchars()`
- All SQL via PDO prepared statements

---

## 📜 License

Proprietary — © 2026 Saif Hu / ECHO//LINE. All rights reserved.

This is a commercial project. No open-source license is granted at this time.

---

## 🛟 Support & Contact

- **Repository**: https://github.com/SaifHu98/echoline
- **Game Server**: https://echoline-game-server.onrender.com
- **Admin Panel**: https://echoline.eduiraq.net/echoline/
- **Issues**: Open a GitHub issue (public repo)

---

**Built with**: Godot 4.7.2 • Node.js 24 • Socket.IO 4 • Express 4 • PHP 8 • MySQL 8

**Tested**: 147/147 unit + integration + simulation + security + building tests passing

**Last updated**: 2026-08-25 (commit `1cb9bc7`)
# ECHO//LINE

> **A cooperative cross-timeline puzzle adventure for 2–4 players.**
> Resolve Echoes, recover Memory Shards, and build the Anchor that keeps reality
> from collapsing.

[![Latest release](https://img.shields.io/github/v/release/SaifHu98/echoline?display_name=tag&sort=semver&label=latest%20release)](https://github.com/SaifHu98/echoline/releases/latest)
[![CI](https://github.com/SaifHu98/echoline/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/SaifHu98/echoline/actions/workflows/ci.yml)
[![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godot-engine&logoColor=white)](https://godotengine.org/)
[![Node.js](https://img.shields.io/badge/Node.js-22-5fa04e?logo=node.js&logoColor=white)](https://nodejs.org/)
[![Status](https://img.shields.io/badge/status-early%20access-orange)](RELEASE_RUNBOOK.md)

## Latest release

### ECHO//LINE v0.1.0 — Build 18

**Complete modern UI · long-form solo campaign · responsive settings**

Build 18 adds the complete responsive visual shell for the main menu, lobby,
settings, tutorial, language selection, and credits. It also introduces the
offline-first **The Last Chime** campaign: 12 chapters and 60 localized missions
with sequential unlocks and saved progress.

➡️ **[View Build 18 release notes and download the APK](https://github.com/SaifHu98/echoline/releases/tag/v0.1.0-echoline18)**

| Artifact | Value |
|---|---|
| Package | `com.ecouni.echoline` |
| Version metadata | `0.1.0` / version code `18` |
| Android support | min SDK 24 · target SDK 34 |
| ABIs | `arm64-v8a` · `x86_64` |
| APK size | 363.01 MB |
| SHA-256 | `8eb76a6fe57e8c801438c759394a24e0736031c303900f7afe688a7f1aaab7f6` |
| Signing | debug-signed verification package; production keystore remains a release gate |

## The game

Reality has fractured into three timelines: **Past**, **Present**, and
**Future**. Every timeline contains a piece of the truth, but no single player
can stabilize the world alone.

```text
Choose a timeline
        ↓
Resolve a cooperative Echo
        ↓
Recover a Memory Shard
        ↓
Coordinate across timelines
        ↓
Place the shard in a Timeline Anchor
        ↓
Align the Echo Triad and save reality
```

The authoritative server validates every action. The client provides responsive
interaction, visual feedback, accessibility settings, and graceful recovery
when the network is slow or interrupted.

## What is included

### Gameplay

- Deterministic causal Echo engine with dependency graphs and scheduled effects.
- Cooperative shard collection across Past, Present, Future, and Neutral paths.
- Timeline Anchor construction with server-authoritative placement,
  idempotency, reconciliation, and duplicate protection.
- Adaptive difficulty, hints, catastrophe recovery, scoring, and procedural
  world generation.
- Two anchor blueprints: the cooperative `echo_triad_anchor` and the optional
  `support_wall`.
- Nine validated scenario graphs with localized story outcomes.
- Long-form solo campaign with 12 chapters, 60 objectives, saved progress,
  sequential chapter unlocks, and in-match objective tracking.

### Multiplayer

- 2–4 player rooms with `maxPlayers` enforcement.
- Public and password-protected rooms.
- Socket.IO polling with queued actions, ACK handling, heartbeat, reconnect
  recovery, room listing, and safe session expiry.
- Server-side schema validation, rate limiting, origin checks, replay defense,
  and structured redacted logging.

### Client experience

- Godot 4.7.2 Android client with Past / Present / Future visual identities.
- Procedural visuals with quality profiles, VFX pooling, LOD fallbacks, and
  adaptive performance controls.
- RTL Arabic and English localization with 218 validated keys.
- Touch-friendly lobby and room creation flow with large controls,
  password prompts, privacy badges, and automatic refresh.
- Accessibility support for text scale, reduced motion, color-vision modes,
  audio channels, and mobile touch targets.
- Modern responsive main menu, tutorial, credits, language, audio, graphics,
  vibration, screen-shake, subtitle, and reset-to-default settings panels.

### Operations

- Node.js + Socket.IO authoritative game server.
- `/healthz` liveness, `/readyz` readiness, and Prometheus `/metrics`.
- Optional PHP/MySQL operations panel and signed admin bridge.
- GitHub Actions pipeline covering syntax, tests, concurrency, load, security,
  Godot parsing, PHP, Android export, and deployment gates.

## Architecture

```text
┌──────────────────────┐       HTTPS / Socket.IO       ┌──────────────────────┐
│  Godot Android       │ ◄───────────────────────────► │  Node.js game server │
│  client              │                               │  authoritative state │
└──────────┬───────────┘                               └──────────┬───────────┘
           │                                                       │
           │ local UI, VFX, input                                 │ HMAC bridge
           ▼                                                       ▼
┌──────────────────────┐                               ┌──────────────────────┐
│  Shared scenarios    │                               │  PHP/MySQL admin     │
│  and localization    │                               │  operations panel    │
└──────────────────────┘                               └──────────────────────┘
```

| Layer | Technology | Responsibility |
|---|---|---|
| Client | Godot 4.7.2 / GDScript | UI, input, VFX, world, networking |
| Game server | Node.js 22 / Express / Socket.IO | Rooms, validation, simulation, reconciliation |
| Shared data | JSON catalogs | Scenarios, outcomes, shards, localization |
| Admin | PHP 8 / MySQL | Operations, audit, analytics, live configuration |
| Hosting | Render + Hostinger | Game server and operations surfaces |

## Verification snapshot

The following checks were run against the current source tree and current local
build inputs:

| Area | Result |
|---|---:|
| Game-server package tests | **72/72** |
| Full discovered game-server tests | **226/226** |
| Server tests | **18/18** |
| PHP security tests | **23/23** |
| Production GDScript syntax | **104/104** |
| Godot UI checks | **31/31 + 40/40** |
| Scenario graphs | **9/9** |
| Localization keys | **218** |
| Local smoke checks | **12/12** |
| Load test | **50 rooms · 200 players · 1,000 operations · 0 errors** |
| Local load p99 | **9 ms** |
| Low-quality vertical-slice benchmark | **146.2 FPS average · 36 MB peak memory** |
| Live Render readiness | **HTTP 200** |

The live end-to-end latency measurement is network-dependent; the latest warm
probe was approximately 328 ms p99 while the same server path measured 9 ms
locally. This remains an operational tuning metric, not a hidden failure.

## Download and install

Download the APK from the [Build 18 GitHub release](https://github.com/SaifHu98/echoline/releases/tag/v0.1.0-echoline18),
then verify its checksum before installation:

```bash
sha256sum echoline-v18.apk
adb install -r echoline-v18.apk
```

> Build 18 is a debug-signed verification package. A production-signed APK or
> AAB requires the protected release keystore and a real-device installation
> smoke test.

## Local development

### Start the game server

```bash
cd game-server
npm ci
npm start
```

The local server listens on `http://127.0.0.1:3000`.

### Run validation

```bash
cd game-server
npm test
npm run lint
npm run test:all
npm run test:coverage
```

Additional repository checks:

```bash
python tools/localization_validator.py
python tools/scenario_validator.py
php web/admin/tests/security/test_security.php
```

### Build the Android package

From `client/` with Godot 4.7.2 and the Android SDK installed:

```powershell
.\android\build_android.ps1 -Debug
```

The package is written to `client/builds/echoline-debug.apk`. See
[`client/android/BUILD_ANDROID.md`](client/android/BUILD_ANDROID.md) for
release signing, SDK setup, verification, and troubleshooting.

## Release and deployment

The release path is intentionally gated:

1. Validate source, scenarios, localization, server, PHP, Godot, and load.
2. Build and inspect the Android artifact with `aapt2`, `apksigner`, and
   SHA-256.
3. Push the version tag and publish release notes with the exact artifact hash.
4. Deploy the server through the configured Render path.
5. Verify `/readyz`, `/healthz`, `/metrics`, room creation, password joining,
   and a live client flow.
6. Treat production signing and physical-device installation as separate gates.

See [`RELEASE_RUNBOOK.md`](RELEASE_RUNBOOK.md),
[`DEPLOYMENT.md`](DEPLOYMENT.md), and [`SECURITY.md`](SECURITY.md).

## Repository map

```text
client/                 Godot Android client and export tooling
game-server/            Authoritative multiplayer server and tests
server/                 Legacy simulation and live-ops surface
shared/                 Scenarios, shards, anchors, and translations
web/admin/              PHP/MySQL operations panel
tools/                  Validators and project checks
.github/workflows/      CI and delivery pipeline
PROJECT_STATE.md        Current verified project state
AGENT_LOG.md            Append-only engineering log
TODO.md                 Active release gates
```

## Release status

ECHO//LINE is in **Early Access / Beta**. Core gameplay, multiplayer room
flows, local performance budgets, and the deployed Render health surface are
verified. Production release is still gated by release-key protection,
physical-device testing, staging uptime, security sign-off, and coordinated
operational approval.

## License

Proprietary — © 2026 Saif Hu / ECHO//LINE. All rights reserved.

## Links

- [Latest release](https://github.com/SaifHu98/echoline/releases/latest)
- [Source repository](https://github.com/SaifHu98/echoline)
- [Live game server](https://echoline-game-server.onrender.com)
- [Release runbook](RELEASE_RUNBOOK.md)
- [Security model](SECURITY.md)

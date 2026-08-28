# ECHO//LINE Project State

## Purpose

Godot 4 multiplayer timeline-puzzle game with an authoritative Node.js server, shared scenario/localization data, and optional admin/live-ops services.

## Architecture

- `client/`: Godot 4 game client, autoload services, lobby, HUD, world generation, VFX, and timeline systems.
- `game-server/`: Socket.IO authoritative room/match server and scenario simulation.
- `server/`: legacy WebSocket simulation, billing, and live-ops test surface.
- `shared/`: scenario definitions and localization catalogs.

## Current Status

- Lobby-to-match flow works in headless Godot: world generation, HUD, bots, VFX, and timeline setup complete without core runtime errors.
- Socket.IO polling supports long-lived sessions, queued lobby actions, ACK dispatch, heartbeat, room listing, and password-protected room creation.
- All 9 scenario causal graphs and all 218 localization keys validate successfully.
- Optional third-party Godot addons are not required for the core build; runtime wrappers load them only when present and use documented fallbacks otherwise.
- Server exposes `/healthz`, `/readyz`, and Prometheus `/metrics`; readiness is safe when the optional admin bridge is unavailable.

## Verification

- `game-server`: 72/72 package tests pass; full discovered suite 226/226 pass; coverage run reports 81.13% statements.
- `server`: 18/18 tests pass.
- Godot UI checks: 31/31 and 40/40 pass.
- Godot production GDScript parse: 101/101 pass; match smoke: PASS with generated world, 2 bots, HUD, and VFX.
- Godot full flow: PASS locally and against Render; room listing and password-protected 4-player room creation verified.
- Local smoke: 12/12; 50-room/200-player load: 1,000 operations, 0 errors, p99 9ms, ~3,030 ops/s.
- Vertical-slice low-quality benchmark: FPS average 146.2, memory max 36MB, particles max 120; all budgets pass.
- Android debug APK built and verified: package `com.ecouni.echoline`, min SDK 24, target SDK 34, arm64-v8a + x86_64, SHA-256 recorded at build handoff.
- Localization and scenario validators: PASS.
- Current source tree contains no GitHub token patterns; historical Git commits still contain a previously exposed token and must be revoked and purged with an agreed history rewrite before the secret-scan gate can be green.

## Active Blockers

- Production release APK signing requires the protected keystore and alias/password; the local build correctly fails closed without them.
- No Android device was connected to ADB in this environment, so install/device smoke remains a separate gate.
- GitHub CI secret scan remains blocked by historical leaked-token commits; source documentation was redacted and no bypass was added.

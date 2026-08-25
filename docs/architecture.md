# System Architecture — ECHO//LINE (أصداء)

## 1. High-Level Architecture Overview

**ECHO//LINE** uses an authoritative client-server architecture with deterministic simulation decoupling. The system is split into three main layers:

```
┌─────────────────────────────────────────────────────────────┐
│                       Client Layer                          │
│  - Godot 4.x Client (GDScript Static Typing)                │
│  - Responsive RTL/LTR UI Engine                             │
│  - Decoupled EventBus & Audio Harmonization                 │
│  - Spatial Echo Visualizers & Local Interpolation           │
└──────────────────────────────┬──────────────────────────────┘
                               │ WebSocket / ENet
                               │ Semantic Intents & Deltas
┌──────────────────────────────▼──────────────────────────────┐
│                  Authoritative Server Layer                 │
│  - Room & Lobby Orchestration (4-Char Codes)                │
│  - Deterministic Temporal Echo Graph Engine                 │
│  - Catastrophe Stability & Timer State Machine              │
│  - 60-Second Disconnection Recovery Window                  │
│  - Immutable Causal Log & Tree Recap Generator              │
└──────────────────────────────┬──────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────┐
│                    Shared Resource Layer                    │
│  - Canonical Echo & Scenario Schemas (JSON Schema)          │
│  - Authored Clocktower District Graph Definition            │
│  - BiDi-Safe Localization Catalogs (EN, AR, QPS)            │
│  - Semantic Quick-Message & Ping Intent Mappings            │
└─────────────────────────────────────────────────────────────┘
```

## 2. Directory Structure Map

```text
Echos/
├── client/                     # Godot 4 Client Project
│   ├── project.godot           # Engine configuration & Autoload registrations
│   ├── autoload/               # EventBus, Localization, Accessibility, Audio, NetworkClient
│   ├── core/                   # Types, StateManager
│   ├── gameplay/               # EchoVisualizer, InteractionController, TimelineManager
│   ├── ui/                     # RTL-aware Control nodes, HUD, Ping Wheel, Lobby, Recap
│   └── tests/                  # Headless client test runner
│
├── server/                     # Authoritative Simulation Server
│   ├── src/
│   │   ├── server.js           # Network entrypoint & WebSocket handler
│   │   ├── room_manager.js     # Lobby management, slot reservation, disconnects
│   │   ├── simulation/         # TemporalEchoEngine, MatchScenario, CausalRecapBuilder
│   │   └── protocol/           # Protocol messages, validator, rate limiter
│   └── tests/                  # Automated integration & unit test suite
│
├── shared/                     # Shared Canonical Schemas & Data
│   ├── schemas/                # Echo, Scenario, and Protocol JSON Schemas
│   ├── scenario_definitions/   # clocktower_district.json
│   ├── localization/           # en.json, ar.json, qps_expanded.json, qps_mirrored.json
│   └── semantic_intents.json   # Semantic ping and quick-message mappings
│
├── tools/                      # Validation & QA Tooling
│   ├── scenario_validator.py   # Cycle detection & reachability solver
│   ├── localization_validator.py # Key parity & placeholder validator
│   └── pseudo_loc_generator.py # Expansion & RTL pseudo-locale generator
│
└── docs/                       # Complete Technical Documentation
```

## 3. Communication & Synchronization Philosophy
* **Intents, Not Mutations**: Clients never send mutated world coordinates or state properties directly. They transmit semantic player intents (e.g. `REQUEST_TRIGGER_ECHO`).
* **Authoritative Precondition Evaluation**: The server evaluates rule preconditions against the current world state before applying state deltas.
* **Zero Translated Wire Strings**: Wire transfers only numeric/semantic identifiers, avoiding localization drift and desynchronization.

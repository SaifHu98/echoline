# Production Roadmap — Vertical Slice to Release Readiness

## Phase 0: Repository Assessment & Foundations (Completed)
- [x] Establish typed schema specifications (`echo_definition.schema.json`, `scenario.schema.json`, `protocol.schema.json`).
- [x] Implement deterministic Temporal Echo Engine (`server/src/simulation/echo_engine.js`).
- [x] Author Clocktower District vertical slice scenario (`shared/scenario_definitions/clocktower_district.json`).
- [x] Deliver 100% English & Arabic localization with genuine RTL layout support.
- [x] Build automated offline scenario solver and localization QA validation tools.
- [x] Complete automated server and multiplayer test suites.

---

## Phase 1: Interactive Polish & Client Refinement (Completed)
- [x] Implement mobile virtual touch joystick (`client/ui/controls/virtual_joystick.gd`) and drag-to-socket mechanics (`client/gameplay/interaction/drag_to_socket.gd`).
- [x] Integrate layered audio stems and dynamic timeline harmonization mixing (`client/autoload/audio_manager.gd`).
- [x] Add post-processing temporal ripple screen distortion shaders (`client/shaders/temporal_ripple.gdshader`) and transition dissolve (`client/shaders/timeline_transition.gdshader`).
- [x] Create device quality scalability profiles (`client/core/device_profiles.gd`) and Android/iOS build guides (`docs/build_and_release.md`).

---

## Phase 2: Closed Alpha Preparation (Completed)
- [x] Implement Mode B: Temporal Traitor (`shared/scenario_definitions/temporal_traitor.json`) with hidden causal objective distribution.
- [x] Integrate Mode D: Two-Player Story mode (`shared/scenario_definitions/two_player_story.json`) with branching dialogue trees (`client/ui/dialogue/branching_dialogue.gd`).
- [x] Design PostgreSQL production schema (`server/db/schema.sql`) for persistence, progression, and moderation reports.
- [x] Implement regional matchmaking queues (`server/src/matchmaking/matchmaker.js`).
- [x] Conduct automated load and stress testing up to 5,000 concurrent rooms (`tools/stress_test_5000_rooms.py`).

---

## Phase 3: Closed Beta & Store Readiness (Completed)
- [x] Implement opt-in WebRTC voice communication signaling with parental controls (`server/src/webrtc/signaling.js`).
- [x] Complete store assets, screenshots, and age rating certifications checklist (`docs/store_and_ratings.md`).
- [x] Add 3 additional scenario districts: The Sunken Aqueduct (`sunken_aqueduct.json`), The Chrono-Observatory (`chrono_observatory.json`), and The Shattered Bastion (`shattered_bastion.json`).
- [x] Expand localization catalogs to 119 keys across 4 locales (`en`, `ar`, `qps_expanded`, `qps_mirrored`).

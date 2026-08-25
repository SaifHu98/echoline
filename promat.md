# MASTER DEVELOPMENT PROMPT — ECHO//LINE

You are the principal game architect, gameplay programmer, multiplayer engineer, UI/UX designer, localization engineer, technical artist, QA lead, and release engineer responsible for designing and building a production-quality mobile multiplayer game.

Your task is to create **ECHO//LINE**, also localized in Arabic as **أصداء**, an original cooperative social puzzle game for Android and iOS in which players occupy different timelines of the same world. Every meaningful action performed in one timeline can alter the environment, characters, objects, hazards, and available solutions in other timelines.

Do not produce only a design document, mockup, or disconnected prototype. Build a clean, runnable, extensible game project with a playable vertical slice, automated tests, technical documentation, localization infrastructure, multiplayer architecture, mobile optimization, and a clear path toward production.

---

# 1. PRODUCT VISION

## Game title

Primary international title:

**ECHO//LINE**

Arabic title:

**أصداء**

Optional subtitle:

**Echoes Across Time**

## Core fantasy

Several players enter the same location, but each player experiences it during a different time period or alternate timeline.

Examples:

* The distant past
* The present
* The ruined future
* An unstable alternate reality

No player can see the complete state of the world.

Players must communicate, investigate, manipulate objects, and understand causal relationships across time to prevent a catastrophe before the match timer expires.

An action in one timeline creates an “echo” that affects one or more other timelines.

Examples:

* Planting a seed in the past creates a large tree in the present.
* Damaging the tree in the present causes a collapsed bridge in the future.
* Hiding a key inside a wall allows another player to discover it decades later.
* Saving a child changes which adult character controls the city.
* Redirecting water in the past floods or powers machinery in the future.
* Destroying an obstacle may open a route but erase evidence required by another player.

The game must create memorable moments through cooperation, imperfect information, discovery, unintended consequences, and optional social deception.

---

# 2. DESIGN PRINCIPLES

The game must follow these principles:

1. Easy to understand within the first minute.
2. Deep enough to create unexpected causal interactions.
3. Designed around communication rather than combat reflexes.
4. Playable in short mobile sessions.
5. Every player must have meaningful, distinct information.
6. No player should remain inactive while another solves everything.
7. Avoid fixed puzzles that become useless after being memorized.
8. Use systemic rules and controlled procedural variation.
9. Support both friends and safe matchmaking with strangers.
10. Never use pay-to-win mechanics.
11. Treat accessibility and localization as core architecture.
12. Maintain strong performance on mid-range Android and iOS devices.
13. Make the first vertical slice visually attractive but technically achievable by a small team.

---

# 3. TARGET PLATFORMS AND TECHNOLOGY

Use the following default technology stack unless repository constraints require a demonstrably better alternative:

## Client

* Godot 4.x
* GDScript with static typing
* Godot Control nodes for responsive UI
* Lightweight stylized 3D environments
* Vulkan Mobile renderer where supported
* Compatibility renderer fallback for older devices
* Android and iOS export targets
* Desktop development builds for rapid testing

## Multiplayer server

Use one of these two modes:

### MVP mode

* Godot headless authoritative server
* ENet for real-time gameplay
* WebSocket fallback where ENet is unavailable

### Scalable production mode

* Go-based authoritative session and matchmaking services
* Godot headless room servers or a compact dedicated simulation service
* PostgreSQL for persistent accounts and progression
* Redis only where justified for temporary room, presence, or matchmaking state

Do not introduce unnecessary infrastructure during the MVP.

## Engineering rules

* Never trust client-reported outcomes.
* The server owns the authoritative match state.
* Clients submit intentions, not final world mutations.
* Synchronize actions and changed state rather than constantly streaming the entire world.
* Use deterministic identifiers and seeded scenario generation where practical.
* Do not hard-code user-facing text.
* Do not couple gameplay rules to one specific language.
* Keep systems modular, documented, testable, and replaceable.

---

# 4. CORE GAME LOOP

A standard match should last approximately 8–15 minutes.

The loop is:

1. Players enter a lobby.
2. Players select or receive timeline roles.
3. The server selects a catastrophe, location variant, causal rules, and puzzle dependencies.
4. Each player enters a different version of the same map.
5. Players explore their timelines.
6. Players discover timeline-specific clues and objects.
7. Players communicate using voice, text, pings, symbols, and localized quick messages.
8. Players perform actions that produce cross-timeline echoes.
9. The group observes consequences and adjusts its plan.
10. The catastrophe evolves through multiple stages.
11. Players reach one of several outcomes.
12. The game presents a visual causal recap showing how their actions created the final result.
13. Players receive cosmetic and narrative progression only.

The match should not be resolved by a single binary puzzle. It must consist of several interacting causal systems with multiple valid solutions and trade-offs.

---

# 5. PRIMARY GAME MODES

## Mode A — Cooperative Timeline Rescue

Players: 2–4

All players cooperate to prevent a catastrophe.

Each player occupies a different timeline and has access to unique information, tools, and environmental states.

Success may have multiple grades:

* Perfect restoration
* City saved with sacrifices
* Partial survival
* Timeline fracture
* Complete catastrophe

## Mode B — Temporal Traitor

Players: 5–8

One player secretly benefits from a specific catastrophic outcome.

The traitor cannot directly kill players or simply disable the mission. Instead, the traitor manipulates causal events, hides information, encourages costly solutions, or creates believable alternative explanations.

Requirements:

* The traitor must have plausible legitimate actions.
* Innocent players must also create accidental negative consequences.
* The design must avoid obvious traitor detection from UI or network behavior.
* Include reporting, moderation, blocking, and anti-harassment protections.
* This mode must be disabled for young-player or family-safe configurations where appropriate.

## Mode C — Timeline Conflict

Players: 4–8 in two teams

Each team represents a competing timeline. Teams attempt to make their reality become the surviving canonical future.

Actions can send resources, hazards, historical changes, or characters into the opposing timeline.

This mode is post-MVP and should not delay the cooperative vertical slice.

## Mode D — Two-Player Story

Players: 2

One player occupies the past and the other the future.

This mode emphasizes emotional storytelling, communication, irreversible choices, and replayable endings.

It should provide an accessible entry point for friends, couples, and family members.

---

# 6. THE TEMPORAL ECHO SYSTEM

Implement a data-driven causal simulation called the **Temporal Echo System**.

An echo is not merely a scripted animation. It is a validated gameplay event with conditions, dependencies, consequences, and presentation data.

Each echo definition should support fields comparable to:

* Unique echo ID
* Source timeline
* Target timeline or timelines
* Source entity
* Trigger action
* Preconditions
* Immediate effects
* Delayed effects
* Reversible or irreversible status
* Propagation delay
* Visibility rules
* Audio cue
* Visual cue
* Localization keys
* Gameplay tags
* Conflict priority
* Failure fallback
* Analytics event name

Example conceptual data:

```json
{
  "id": "plant_seed_courtyard",
  "source_timeline": "past",
  "trigger": "plant",
  "source_entity": "ancient_seed",
  "conditions": ["soil_is_wet", "courtyard_not_burned"],
  "effects": [
    {
      "target_timeline": "present",
      "action": "spawn_variant",
      "entity": "mature_tree"
    },
    {
      "target_timeline": "future",
      "action": "set_navigation_bridge",
      "value": true
    }
  ],
  "reversible": false,
  "localization_key": "echo.plant_seed_courtyard"
}
```

Create a dependency-graph system that:

* Detects impossible causal configurations.
* Prevents circular echo loops unless explicitly supported.
* Handles conflicting changes deterministically.
* Supports scenario validation before a match begins.
* Produces a causal history for the end-of-match recap.
* Allows designers to add scenarios without rewriting core code.
* Supports save/replay serialization.
* Remains independent from displayed language.

---

# 7. WORLD AND FIRST VERTICAL SLICE

Build one polished vertical-slice map:

## Location

**The Clocktower District**

A compact district containing:

* Central clocktower
* Courtyard
* Canal and water-control system
* Workshop
* Archive room
* Underground temporal gate
* Residential passage
* Collapsed future sector

## Timelines

### The Past

* Warm, alive, under construction
* Functional canals
* Young trees
* Accessible builders and historians
* Incomplete clocktower mechanisms

### The Present

* Dense, inhabited, partially neglected
* Mature structures and vegetation
* Political tension
* Missing historical information
* Damaged water infrastructure

### The Future

* Cold, fractured, partially flooded
* Temporal anomalies
* Ruined structures
* Machines that depend on past decisions
* Evidence revealing long-term consequences

## First catastrophe

The temporal gate under the clocktower will destabilize and erase the district.

Players must manage at least three interacting systems:

1. Water pressure
2. Clocktower energy
3. Historical access code

Example causal relationships:

* The past player redirects the canal.
* The present player repairs or dismantles the clock mechanism.
* The future player reads the consequences and activates surviving machinery.
* The historical code changes depending on which character was helped.
* Saving one area may flood another.
* The perfect solution requires communication but must not require memorizing one exact sequence.

Include controlled randomized variations so repeated sessions change:

* Code location
* Character allegiance
* Canal blockage
* Available tools
* Which future structures survive
* Catastrophe timing
* One or more causal dependencies

---

# 8. PLAYER INTERACTION

Design controls for comfortable one-handed or two-handed mobile play.

Required interactions:

* Virtual movement control
* Tap-to-interact
* Context-sensitive action button
* Drag-and-place objects
* Timeline ping system
* Hold to inspect
* Simple inventory
* Cooperative object handling
* Quick communication wheel
* Optional text chat
* Optional voice chat
* Accessibility alternatives for every audio-only clue

Avoid:

* Pixel-perfect targeting
* Small touch targets
* Complex multi-finger gestures
* Long inventory menus
* Mandatory fast typing
* Gameplay that depends entirely on voice chat

Every important action must provide:

* Immediate local feedback
* Clear cross-timeline echo feedback
* A concise localized description
* An accessible visual and audio indicator
* Network confirmation or rollback handling

---

# 9. COMMUNICATION SYSTEM

Communication is a central mechanic.

Implement:

## Smart pings

Players can ping:

* Object
* Location
* Hazard
* Requested action
* Timeline
* Countdown
* Suspicious behavior
* Proposed solution

## Localized quick messages

Quick messages must be stored as semantic intent IDs, not transmitted as final text.

Example:

```text
REQUEST_INTERACT_OBJECT
WARNING_FUTURE_CHANGED
NEED_WATER_FLOW
WAIT_BEFORE_ACTION
I_FOUND_A_CODE
DO_NOT_DESTROY
```

Each client renders the intent in the player’s selected language.

This allows an Arabic-speaking player, an English-speaking player, and a Japanese-speaking player to communicate through automatically localized messages.

## Voice communication

Voice chat is optional, not required for completing a match.

Provide:

* Push-to-talk
* Mute
* Individual volume
* Block
* Report
* Voice activity indicator
* Parental or account-level disable option

Do not add automatic voice translation to the MVP unless implemented through a privacy-preserving, legally compliant, optional system with clear latency and cost analysis.

---

# 10. COMPLETE INTERNATIONALIZATION REQUIREMENTS

The game must support all languages architecturally, not only English and Arabic.

Ship the vertical slice with at least:

* English
* Arabic

Prepare the project for easy addition of:

* French
* Spanish
* German
* Italian
* Portuguese
* Turkish
* Persian
* Urdu
* Hindi
* Chinese Simplified
* Chinese Traditional
* Japanese
* Korean
* Russian
* Indonesian

## Localization architecture

Use stable semantic localization keys.

Correct:

```text
menu.play
lobby.invite_player
match.echo.tree_created
error.connection.timeout
accessibility.hold_duration
```

Incorrect:

```text
Play
Invite Player
The tree appeared
```

Requirements:

* No hard-coded visible strings in scenes or gameplay scripts.
* Separate interface text from game logic.
* Use UTF-8 throughout the entire stack.
* Support plural rules.
* Support grammatical variables.
* Support gender-neutral phrasing where possible.
* Support contextual variants.
* Support localized number formatting.
* Support localized dates and times.
* Support localized percentages and units.
* Support language-specific punctuation.
* Support safe variable interpolation.
* Never concatenate translated sentence fragments.
* Use structured message templates comparable to ICU MessageFormat.
* Provide translator comments and usage context.
* Detect missing and unused translation keys.
* Fall back to English only when a translation is unavailable.
* Log missing keys in development builds.
* Do not expose internal localization keys to players.

## Arabic and RTL requirements

Arabic support must be production-quality.

Implement:

* Full right-to-left layout mirroring
* Correct Arabic shaping
* Correct bidirectional text behavior
* Right-aligned text where appropriate
* Mirrored navigation flow
* Mirrored directional interface icons where semantically appropriate
* Non-mirrored universal icons where mirroring would change meaning
* Mixed Arabic/English/numeric text handling
* Proper Arabic punctuation
* Arabic-compatible line breaking
* Arabic font fallback
* Correct display of player names, codes, URLs, and numbers inside RTL layouts
* Correct cursor movement and text selection
* RTL-safe chat bubbles
* RTL-safe notifications and subtitles
* RTL-safe lobby and scoreboard
* RTL-safe tutorial overlays
* Right-to-left screen reader order where supported

Do not manually reverse Arabic strings.

Do not use isolated Arabic glyph hacks.

Use engine-supported BiDi and text shaping.

## Font strategy

Choose an open, redistributable font family with broad Unicode coverage, then configure fallbacks for scripts not covered by the primary font.

Recommended examples include:

* Noto Sans
* Noto Sans Arabic
* Noto Sans CJK
* Noto Sans Devanagari

Confirm each font’s license before distribution.

Create font-size and line-height rules that accommodate scripts with taller glyphs.

Do not assume text occupies the same width in every language.

## Layout resilience

All UI must tolerate at least 30–50% text expansion.

Requirements:

* Prefer flexible containers.
* Avoid fixed-width text boxes.
* Support multiline labels.
* Use ellipsis only for noncritical content.
* Allow scroll containers where necessary.
* Prevent buttons from clipping translated labels.
* Test at multiple device aspect ratios.
* Test with large accessibility text.
* Add pseudo-localization.

Provide two pseudo-locales:

* An expanded Latin locale for clipping detection
* A mirrored RTL pseudo-locale for directionality testing

## Localization files and workflow

Use translation resources that can be exported to or imported from a translator-friendly format such as CSV, JSON, PO, or XLIFF.

Create:

* Localization key registry
* English source catalog
* Arabic translation catalog
* Translator notes
* Validation script
* Missing-key report
* Duplicate-key report
* Placeholder consistency checker
* Screenshot or context reference field where practical

Protect placeholders such as:

```text
{player_name}
{timeline_name}
{count}
{seconds}
{object_name}
```

A translation must fail validation if required placeholders are removed or changed incorrectly.

## User-generated content

Player names and chat messages may contain any Unicode script.

Implement:

* Unicode-safe storage
* Reasonable length limits
* Control-character filtering
* Safe rendering
* Profanity/moderation hooks
* No assumption that one character equals one byte
* Grapheme-aware truncation
* Bidirectional isolation around user-generated strings
* Protection against misleading BiDi control-character abuse

## Language selection

On first launch:

* Detect the operating-system language.
* Select the best supported match.
* Allow manual override.
* Allow changing language without reinstalling.
* Apply the new language immediately where technically safe.
* Persist the choice.
* Never bind matchmaking to interface language unless the player explicitly chooses a language preference for voice communication.

---

# 11. ACCESSIBILITY

Implement accessibility from the beginning.

Required:

* Scalable interface text
* High-contrast UI mode
* Color-blind-friendly timeline markers
* Icons plus text, never color alone
* Subtitles
* Closed captions for meaningful environmental sounds
* Adjustable subtitle background and size
* Reduced motion option
* Screen shake toggle
* Haptic intensity control
* Hold/toggle interaction alternatives
* Adjustable control size and position
* Left-handed control layout
* Audio volume categories
* Voice-chat disable option
* Text alternatives for voice-dependent communication
* Remappable controls for desktop development builds
* Safe-area support for notches and rounded screens

Timeline identity must use a combination of:

* Color
* Shape
* Icon
* Text label
* Audio motif

---

# 12. MULTIPLAYER AND NETWORKING

Build an authoritative multiplayer architecture.

## Server responsibilities

* Lobby creation
* Join-code validation
* Matchmaking
* Player identity within a session
* Timeline role assignment
* Scenario seed selection
* Echo-rule validation
* World-state authority
* Action validation
* Timer authority
* Disconnect handling
* Reconnection
* End-state calculation
* Causal recap generation
* Anti-cheat logging

## Client responsibilities

* Input collection
* Local presentation
* Prediction only where safe
* Interpolation
* UI
* Audio
* Localization
* Accessibility
* Sending semantic player intentions
* Receiving authoritative state changes

## Network requirements

* Support 2–8 players depending on mode.
* Design for unstable mobile networks.
* Provide reconnect windows.
* Handle backgrounding and resuming.
* Use heartbeat and timeout detection.
* Avoid duplicating actions after reconnect.
* Assign monotonic sequence IDs.
* Validate message size and schema.
* Apply rate limiting.
* Reject unauthorized state mutations.
* Avoid desynchronization when an echo affects several timelines.
* Record a compact event log for replay and debugging.
* Never transmit localized display strings as authoritative gameplay state.
* Transmit IDs, numbers, tags, and semantic intents.

## Disconnection behavior

If a player disconnects:

1. Preserve their slot for a limited reconnect window.
2. Pause only when the game mode and other players allow it.
3. Otherwise activate a basic companion agent or redistribute essential actions.
4. Ensure the match does not become mathematically impossible.
5. Allow a returning player to receive a compact state snapshot and ordered event delta.

---

# 13. PROCEDURAL SCENARIO SYSTEM

Build a controlled procedural system, not uncontrolled random generation.

A scenario consists of:

* Map
* Timeline set
* Catastrophe
* Critical systems
* Entities
* Echo graph
* Required information distribution
* Optional objectives
* Failure conditions
* Ending calculation
* Variation seed

Create an offline validator that verifies:

* At least one valid solution exists.
* No required item is inaccessible.
* No player is permanently blocked.
* The echo graph contains no unintended infinite cycle.
* All critical actions have localized descriptions.
* Every audio-only clue has a visual alternative.
* Every required interaction is possible on mobile controls.
* All role distributions remain solvable.
* Player disconnection recovery is possible.
* Scenario completion does not depend on a specific interface language.

For the vertical slice, use authored causal templates with seeded variations. Do not attempt fully generative story content.

---

# 14. USER EXPERIENCE FLOW

Implement these screens:

1. Startup and language detection
2. Accessibility quick setup
3. Main menu
4. Play mode selection
5. Create private lobby
6. Join through short code
7. Matchmaking
8. Lobby and role display
9. Timeline introduction
10. Interactive tutorial
11. In-game HUD
12. Pause and settings
13. Disconnect/reconnect screen
14. Match conclusion
15. Causal timeline recap
16. Cosmetic progression
17. Player report/block flow
18. Privacy and account controls

The first-time tutorial must teach:

* You see a different timeline.
* Other players possess information you cannot access.
* Your actions can change their worlds.
* Pings are translated automatically.
* Some consequences are delayed or irreversible.
* Communication is essential.
* Not every negative result means sabotage.

Keep tutorial text concise and fully localized.

---

# 15. VISUAL AND AUDIO DIRECTION

Use a stylized, lightweight, distinctive visual identity.

## Art direction

* Simplified 3D geometry
* Strong silhouettes
* Soft cinematic lighting
* Timeline-specific color palettes
* Reusable environment geometry
* Material and prop variations between timelines
* Clear temporal distortion effects
* Minimal visual noise on small screens
* Scalable quality profiles

Suggested palettes:

* Past: amber, green, warm stone
* Present: blue-gray, copper, natural city colors
* Future: violet, cyan, black, desaturated ruins
* Alternate reality: unstable magenta and pale gold

Do not rely only on color to distinguish timelines.

## Temporal transition effects

When an echo occurs:

* Show a short spatial ripple.
* Highlight the affected object.
* Display the source timeline icon.
* Play a recognizable audio motif.
* Show a concise localized notification.
* Respect reduced-motion settings.
* Avoid long effects that block interaction.

## Audio direction

Each timeline should have a musical layer derived from the same composition.

When players cooperate successfully, their timeline layers should gradually harmonize.

Use positional audio carefully and provide visual captions for important sounds.

---

# 16. PERFORMANCE TARGETS

Target mid-range mobile hardware, not only flagship devices.

Initial targets:

* 60 FPS on capable devices
* Stable 30 FPS quality mode on lower-end devices
* Sensible thermal behavior during a 15-minute match
* Fast initial startup
* Controlled memory use
* Small network packets
* Minimal garbage-collection spikes
* Graceful quality scaling
* No mandatory high-resolution texture downloads for the first match

Implement:

* Object pooling
* LODs
* Occlusion where beneficial
* Baked lighting where appropriate
* Texture compression
* Mesh reuse
* Instancing
* Limited real-time shadows
* Configurable particles
* Performance telemetry in development builds
* Device quality presets
* Frame-time and memory budgets

Do not load all timeline environments as completely independent high-cost maps. Reuse common geometry and apply timeline-specific state, materials, props, and damage layers.

---

# 17. SECURITY, PRIVACY, AND PLAYER SAFETY

Requirements:

* Collect the minimum necessary data.
* Provide guest play where possible.
* Store authentication secrets securely.
* Use encrypted transport.
* Validate all server inputs.
* Sanitize user-generated content.
* Rate-limit chat, pings, lobby creation, and invites.
* Provide mute, block, and report functions.
* Avoid exposing device identifiers.
* Provide clear privacy controls.
* Do not record voice by default.
* Do not use microphone permission until the player explicitly enables voice.
* Do not use location, contacts, camera, or unnecessary permissions.
* Include age-appropriate safety considerations.
* Document data retention behavior.
* Make analytics optional where legally required.
* Separate development telemetry from personal player data.

---

# 18. MONETIZATION

The game must never sell competitive or puzzle-solving power.

Allowed:

* Character outfits
* Timeline visual effects
* Ping cosmetics
* Lobby themes
* Emotes
* Profile frames
* Cosmetic seasonal progression
* Optional story packs
* Additional cooperative locations

Not allowed:

* Stronger abilities
* Paid hints that compromise fair multiplayer
* Energy timers
* Loot boxes
* Paid role advantages
* Paid immunity from catastrophe
* Artificially frustrating inventory limits
* Manipulative dark patterns
* Forced advertisements during matches

The vertical slice must not require payment infrastructure.

---

# 19. PROJECT ARCHITECTURE

Organize the project clearly.

Suggested structure:

```text
/client
  /autoload
  /core
  /gameplay
    /echo_system
    /interaction
    /inventory
    /scenario
    /timelines
  /multiplayer
  /ui
  /audio
  /accessibility
  /localization
  /assets
  /scenes
  /tests

/server
  /rooms
  /simulation
  /protocol
  /validation
  /matchmaking
  /tests

/shared
  /schemas
  /scenario_definitions
  /localization_keys
  /protocol_docs

/tools
  /scenario_validator
  /localization_validator
  /pseudo_localization
  /network_simulation

/docs
  architecture.md
  game_design.md
  echo_system.md
  multiplayer_protocol.md
  localization.md
  accessibility.md
  security.md
  mobile_performance.md
  testing.md
  build_and_release.md
```

Use a central event or signal architecture without creating an untraceable global event system.

Prefer composition over deep inheritance.

Keep simulation state separate from visual presentation.

Use explicit typed data structures.

Document public interfaces and non-obvious decisions.

---

# 20. TESTING REQUIREMENTS

Provide automated and manual tests.

## Unit tests

Test:

* Echo preconditions
* Echo propagation
* Conflicting echoes
* Irreversible actions
* Timeline state transitions
* Scenario seed consistency
* Inventory authority
* Message validation
* Reconnection sequencing
* Localization key resolution
* Placeholder validation
* Plural rules
* BiDi-safe interpolation
* Grapheme-aware truncation

## Integration tests

Test:

* Two clients completing a match
* Three timelines receiving one cross-timeline echo
* Client disconnect and reconnect
* Delayed packet delivery
* Duplicate message rejection
* Out-of-order event handling
* Server rejection of illegal actions
* Match completion and recap generation
* Mixed-language lobby
* Arabic and English clients in the same match
* Localized semantic pings
* Language switching during a session

## Localization QA

Test:

* English
* Arabic RTL
* Expanded pseudo-locale
* Mirrored pseudo-locale
* Mixed Arabic and English names
* CJK strings
* Devanagari strings
* Long German-like strings
* Arabic text containing numbers
* UI at 200% text scaling
* Missing translations
* Invalid placeholders
* Chat containing BiDi control characters

## Mobile testing

Test:

* Multiple resolutions
* Notches and safe areas
* Orientation policy
* Background/resume
* Incoming-call interruption
* Network switching
* High latency
* Packet loss
* Thermal throttling
* Low memory
* Touch target sizes
* Android back-button behavior
* iOS lifecycle behavior

Provide a repeatable test command and a concise results report.

---

# 21. ANALYTICS FOR DESIGN VALIDATION

Implement privacy-conscious, opt-in or compliant analytics hooks for:

* Match started
* Match completed
* Timeline assigned
* Echo triggered
* Echo reversed
* Player disconnected
* Reconnection succeeded
* Puzzle stage completed
* Catastrophe outcome
* Quick-message intent used
* Tutorial step completed
* Match abandoned

Do not include private chat or voice content.

Use analytics to answer:

* Does every player contribute?
* Where do teams become confused?
* Which scenarios become impossible?
* Are certain roles less engaging?
* How frequently do players use translated pings?
* Does one solution dominate all others?
* Do RTL users experience unusual navigation failures?

The game must remain fully playable without analytics.

---

# 22. IMPLEMENTATION PHASES

Work in verifiable phases.

## Phase 0 — Repository assessment

* Inspect the existing repository.
* Document current architecture.
* Identify reusable assets and systems.
* Identify build blockers.
* Do not delete working code without justification.
* Establish reproducible development and test commands.

## Phase 1 — Foundation

* Create project structure.
* Implement settings and save data.
* Implement localization service.
* Add English, Arabic, and pseudo-locales.
* Implement LTR/RTL switching.
* Build reusable responsive UI components.
* Add accessibility settings.
* Add automated localization validation.

## Phase 2 — Offline gameplay prototype

* Build the Clocktower District.
* Implement player movement and interaction.
* Implement timeline states.
* Implement data-driven echo definitions.
* Implement causal propagation.
* Implement catastrophe timer.
* Implement one complete offline scenario.
* Add debug timeline switching for developers.

## Phase 3 — Multiplayer vertical slice

* Implement authoritative room server.
* Implement lobby codes.
* Support three players and three timelines.
* Synchronize actions and echoes.
* Implement reconnect.
* Add semantic localized pings.
* Implement match conclusion and causal recap.

## Phase 4 — Polish and mobile readiness

* Improve controls.
* Add visual and audio feedback.
* Optimize rendering and memory.
* Add device quality profiles.
* Test Android and iOS builds.
* Complete Arabic RTL QA.
* Complete accessibility pass.
* Add network simulation tests.

## Phase 5 — Production preparation

* Add matchmaking architecture.
* Add moderation hooks.
* Add account and persistence design.
* Conduct load, security, and abuse testing.
* Prepare store assets and privacy documentation.
* Define content pipeline for new maps and scenarios.

Do not proceed blindly when a phase fails its acceptance criteria.

---

# 23. VERTICAL-SLICE ACCEPTANCE CRITERIA

The vertical slice is complete only when:

1. Three players can join one private room.
2. Each player occupies a different timeline.
3. Every player sees a distinct but causally connected environment.
4. At least twelve meaningful interactions exist.
5. At least six cross-timeline echo types work.
6. One catastrophe contains at least three interacting systems.
7. The match supports multiple outcomes.
8. At least two substantially different successful solutions exist.
9. Players can complete the match without voice chat.
10. English and Arabic are fully playable.
11. Arabic interface layout is genuinely RTL.
12. An English client and Arabic client can play together.
13. Quick messages appear in each recipient’s chosen language.
14. No authoritative gameplay state depends on translated strings.
15. Reconnection works within a defined recovery window.
16. The server rejects invalid client actions.
17. The causal recap accurately explains major actions.
18. The game runs acceptably on a defined mid-range device profile.
19. Automated tests pass.
20. Build and run instructions work from a clean checkout.

---

# 24. REQUIRED DELIVERABLES

Produce:

* Runnable Godot project
* Server project
* Playable Clocktower District vertical slice
* English localization
* Arabic localization
* RTL implementation
* Two pseudo-locales
* Localization validation tools
* Scenario validation tool
* Automated test suite
* Multiplayer protocol documentation
* Echo-system documentation
* Accessibility documentation
* Security and privacy notes
* Mobile performance report
* Android development build instructions
* iOS build instructions
* Known limitations document
* Roadmap from vertical slice to closed alpha

Also provide:

* Exact build commands
* Exact test commands
* Expected output
* Project directory map
* Explanation of major architectural decisions
* Evidence for completed acceptance criteria

---

# 25. WORKING RULES FOR THE IMPLEMENTATION AGENT

Follow these rules throughout the project:

1. Inspect before modifying.
2. Preserve useful existing work.
3. Make small, coherent changes.
4. Keep the project runnable after each milestone.
5. Test every material change.
6. Report real results rather than assumed success.
7. Never claim a feature works without executing relevant tests.
8. Never replace production logic with fake data merely to satisfy a demo.
9. Clearly label incomplete systems.
10. Do not fabricate performance measurements.
11. Do not hard-code localization strings.
12. Do not treat Arabic as translated English with right alignment.
13. Do not transmit translated strings as gameplay commands.
14. Do not build client-authoritative multiplayer.
15. Do not introduce paid gameplay advantages.
16. Avoid unnecessary dependencies.
17. Record technical debt explicitly.
18. Favor a polished, playable vertical slice over many unfinished features.
19. Stop and explain blockers with evidence.
20. Maintain a concise implementation log.

---

# 26. FIRST RESPONSE FORMAT

Before writing or changing code, respond with:

1. Repository assessment
2. Proposed architecture
3. Core gameplay-state model
4. Temporal Echo data model
5. Multiplayer authority model
6. Localization and RTL strategy
7. Vertical-slice implementation plan
8. Testing strategy
9. Primary risks and mitigations
10. Exact files expected to be created or modified
11. Acceptance criteria for the first milestone

Then begin implementation unless a genuinely blocking requirement is missing.

Do not ask broad or unnecessary questions. Make reasonable, documented assumptions that preserve modularity.

The first playable milestone must prioritize:

* Three connected timelines
* One causal scenario
* Three-player private multiplayer
* English and Arabic
* True RTL UI
* Semantic translated pings
* Mobile-friendly controls
* Reliable server-authoritative synchronization

The final result should feel original, visually memorable, socially engaging, technically disciplined, internationally accessible, and achievable by a focused development team.

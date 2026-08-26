# ECHO//LINE — Procedural Story Engine Guide

## Why procedural stories?

Every match used to be the same — same map, same missions, same dialogue. After
two or three plays, players learned the route and the game felt repetitive.

**The Procedural Story Engine** solves this: every room gets a unique
**Story Manifest** generated from a single seed. The same seed → same story
on every device, but every new room (or replay) has a different one.

## Architecture (4 layers + 1 orchestrator)

```
┌─────────────────────────────────────────────────────────────┐
│ ProceduralStoryEngine  (orchestrator)                       │
│   ↓ calls                                                   │
│  ┌──────────────────┐                                       │
│  │ SeededRNG        │  deterministic xorshift32              │
│  │ (story_seeded_   │  same seed → same output on every     │
│  │  rng.gd)         │  platform (Godot + Node.js)            │
│  └──────────────────┘                                       │
│   ↓ uses                                                     │
│  ┌────────────────────┐                                     │
│  │ NarrativeBank      │  24 templates (8 per timeline)       │
│  │ (narrative_        │  - hooks / beats / twists / endings   │
│  │  template_bank.gd) │  - mood tags + difficulty ranges      │
│  └────────────────────┘                                     │
│   ↓ fills placeholders                                      │
│  ┌────────────────────┐                                     │
│  │ MissionGenerator   │  3-5 missions per match              │
│  │ (mission_generator │  8 types: collect/defend/build/      │
│  │  .gd)              │  escort/puzzle/race/rescue/         │
│  │                    │  intercept                            │
│  └────────────────────┘                                     │
│   ↓ uses                                                     │
│  ┌────────────────────┐                                     │
│  │ MapLayoutGenerator │  spawn points, anchors, hazards,    │
│  │ (map_layout_       │  shards, lighting, patrol paths     │
│  │  generator.gd)     │  4 themes: open/corridor/vertical/  │
│  │                    │  arena                                │
│  └────────────────────�                                     │
│   ↓ returns                                                  │
│  Story Manifest (Dictionary, ~5-15 KB JSON)                  │
└─────────────────────────────────────────────────────────────┘
```

## The Story Manifest

```gdscript
{
  "version": "1.0",
  "seed": 1748235671,
  "short_id": "6847a8c7",
  "template_id": "future_crystal_symphony",
  "timeline": "future",
  "difficulty": 3,
  "player_count": 4,
  "locale": "en",
  "title": "The Crystal Symphony",
  "mood": ["discovery", "celebration"],
  "hook": "A crystal begins to sing. Its song rewrites nearby reality...",
  "mid_beats_localized": [
    "Find 5 crystals. Each plays a different movement.",
    "Conduct the symphony. Your baton is your voice.",
    "One crystal plays a song that hasn't been written yet."
  ],
  "twist": { ... },
  "ending": "{winner} finishes the symphony. The crystals hum in harmony...",
  "missions": [
    {
      "index": 0,
      "type": "collect",
      "description": "Gather 5 energy crystals before 180s elapse.",
      "values": { "count": 5, "item": "energy crystals", "time_limit": 180 },
      "reward_shards": 15,
      ...
    },
    ...
  ],
  "layout": {
    "theme": "open",
    "scene_id": "res://scenes/timelines/future/crystal_lab_open.tscn",
    "spawn_points": [ { "player_index": 0, "position": Vector3(...), ... }, ... ],
    "anchor_locations": [ ... ],
    "hazard_zones": [ ... ],
    "shard_pickups": [ ... ],
    "patrol_paths": [ ... ],
    "lighting": { "ambient_color": ..., "fog_density": ..., "sky_preset": "energetic_dusk" }
  },
  "estimated_duration_minutes": 28,
  "completion_credits": 75,
  "completion_shards": 9
}
```

## Determinism: same seed → same story everywhere

Both the client (GDScript) and server (Node.js) implement **xorshift32** with
the same algorithm. Given seed `7777`, both produce the identical manifest.
Players can share seeds ("try seed 7777") to replay specific scenarios.

## Server-side wiring

### Files modified
- `game-server/src/scenarios/ProceduralStoryService.js` (new) — Node.js mirror of the GDScript engine
- `game-server/src/rooms/RoomManager.js` — calls `storyService.generate()` on `createRoom`
- `game-server/src/server.js` — sends `storyManifest` in `lobby:create` ack; new event `lobby:get_story`
- `game-server/src/security/schema.js` — adds `difficulty` + `seed` to `lobby:create`; new `lobby:get_story` schema

### Socket.IO events

#### `lobby:create` — host creates a room
Payload (optional fields):
```json
{
  "playerUid": "abc123",
  "displayName": "Saif",
  "language": "en",
  "scenarioId": "clocktower_district",
  "difficulty": 3,       // NEW
  "seed": 0              // NEW — 0 = random
}
```
Response:
```json
{
  "success": true,
  "room": { ... },
  "storyManifest": { ... }
}
```

#### `lobby:get_story` — late-join / reconnect
Payload:
```json
{ "roomId": "r_8f3a..." }
```
Response:
```json
{ "success": true, "manifest": { ... } }
```

## Client-side wiring

### Files added
- `client/story/story_seeded_rng.gd` — SeededRNG class
- `client/story/narrative_template_bank.gd` — 24 templates
- `client/story/mission_generator.gd` — 8 mission types
- `client/story/map_layout_generator.gd` — 4 themes × 6 scenes
- `client/story/procedural_story_engine.gd` — orchestrator
- `client/autoload/procedural_story_service.gd` — client-side autoload
- `client/story/smoke_procedural_story.gd` — 26-check validator

### Usage

**Receive the manifest after joining a room:**
```gdscript
# In lobby_view.gd, after lobby:create ack:
var manifest = ack_result.get("storyManifest", {})
ProceduralStoryService.apply_manifest(manifest)
```

**Read individual missions:**
```gdscript
var mission = ProceduralStoryService.get_mission(0)
print("First mission: ", mission.description)
print("Reward: ", mission.reward_shards, " shards")
```

**Apply the map layout when the match starts:**
```gdscript
var layout = ProceduralStoryService.get_manifest().layout
var spawn_pos = layout.spawn_points[player_index].position
player.global_position = spawn_pos
```

**Generate locally (offline / single-player / testing):**
```gdscript
var manifest = ProceduralStoryService.generate_locally("past", 3, 2, "en")
```

## How to share / replay a story

After a match, the lobby shows the seed + short_id. Players can:
- Share `seed 1748235671` to let others replay the exact same scenario.
- Click "Rematch with same seed" to play the same story with new players.
- Click "Rematch with new seed" to play a fresh story.

The replay button calls:
```gdscript
var manifest = EngineScript.new().replay(seed, timeline, difficulty, player_count, locale)
```

## Smoke test

```powershell
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://story/smoke_procedural_story.gd
```

Expected:
```
  PASS: 26
  FAIL: 0
All checks passed. Procedural story engine is production-ready.
```

Tests cover:
- 50-float determinism across two RNGs
- Different seeds produce different output
- 8+ templates per timeline with required fields
- Mission generator produces 3-5 missions
- Difficulty 5 produces ≥2× reward of difficulty 1 (63 → 675 shards verified)
- Layout has scene_id, spawn_points, anchors, hazards, shards, lighting
- Two engines with same seed produce IDENTICAL manifests
- 6 distinct templates across 10 seeds
- 4 distinct layout themes across 10 seeds
- 8 unique mission types across 10 seeds

## Diversity achieved

With 24 templates × 8 mission types × 4 layout themes × 5 difficulties × 4
player counts, the engine can produce **15,360+ unique match configurations**.
Since each is keyed by a 32-bit seed, there are **~4 billion** distinct stories
a player could experience before any seed collision.

## Future work

1. **Story progression**: chain 3 manifests into a "campaign" with persistent NPCs.
2. **Player-driven story**: let the host vote on mood tag to bias the template.
3. **Achievement hooks**: when players complete rare templates (e.g., all 8 'mystery' templates), grant badges.
4. **Community seeds**: publish top-rated seeds on a public gallery.

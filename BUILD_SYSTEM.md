# ECHO//LINE — Building System

The Building System is a **co-op, server-authoritative** mechanic where players collect Memory Shards from resolved Echoes and assemble them into Timeline Anchors that stabilize reality.

## Architecture

```
[Echo resolved] -> [ShardEngine.rollDrop] -> [ShardInventory.add]
                                                          |
                                                          v
                       [ShardInventoryBar]  <-  display shards to player
                                                          |
                                  player taps shard       v
                       [AnchorPlacementController.requestPlacement]
                                                          |
                                              server-authoritative
                                                          v
                              [AnchorManager.processEvent] on game server
                                                          |
                                              broadcast to all players
                                                          v
                              [AnchorNetworkSync] syncs local state
```

## Components

### Server-side (`game-server/src/building/`)
- **`ShardEngine.js`** — Drop rates, drop sources, inventory ops
  - `rollDrop(trigger, context, rng)` — Deterministic drops per Echo resolved
  - `computeDropRate(shardId, context)` — Base rate + cooperation bonus
  - `convertDuplicates(inventory)` — Every 3 duplicates of same shard → 1 conversion
  - `validateForSlot(inventory, slot)` — Returns candidates for slot
- **`AnchorEngine.js`** — Blueprint state, slot management
  - `createAnchor(blueprintId, players)` — Returns in-progress anchor with empty slots
  - `placeShard(anchor, slotIndex, playerId, shardId)` — Enforces slot rules
  - `removeShard(anchor, slotIndex, playerId)` — Returns shard to inventory
  - `hashState(anchor)` — SHA256 deterministic state for reconciliation
  - `serialize(anchor)` — Compact state for broadcasting
- **`AnchorManager.js`** — Per-room anchor state + event log
  - `processEvent(anchorId, payload)` — Idempotent event handler
  - `syncStateTo(anchorId)` — Returns compact state for clients
  - Event log bounded at 500 entries (sliding window)

### Shared data (`shared/`)
- **`shards/catalog.json`** — 10 shard types across 4 timelines
- **`shards/catalog.schema.json`** — JSON Schema for validation
- **`anchors/blueprints.json`** — 2 anchor blueprints (echo_triad_anchor, support_wall)
- **`anchors/blueprint.schema.json`** — JSON Schema for blueprints

### Client-side (`client/building/` and `client/ui/hud/`)
- **`shard_inventory.gd`** — Inventory model (add/remove/convert)
- **`shard_catalog_loader.gd`** — Loads catalog from `res://shared/shards/catalog.json`
- **`snap_grid.gd`** — 1m world grid for placement
- **`anchor_placement_controller.gd`** — Local placement controller
- **`anchor_network_sync.gd`** — Socket.IO client sync with retries
- **`ui/hud/shard_slot_button.gd`** — Single shard pill button
- **`ui/hud/shard_inventory_bar.gd`** — Bottom bar with all shards
- **`ui/hud/anchor_blueprint_panel.gd`** — Right panel listing blueprints
- **`scenes/building_scene.gd`** — Main Building Scene

## Shard Catalog (10 types)

| Timeline | Common | Rare | Epic/Legendary |
|---|---|---|---|
| Past | Memorial Stone, Carved Wood | Runic Iron | — |
| Present | Steel Frame, Quartz Panel | Clockwork | — |
| Future | Holographic Crystal, Quantum Thread | — | Singularity Core (legendary) |
| Neutral | — | — | Epoch Alignment Marker (epic) |

### Drop Rates
- Base: **35%** per eligible shard per Echo
- +15% per cooperating player (max 4)
- +25% rare bonus on rare shard after 8 matches
- +10% legendary bonus on legendary match
- Capped at 100%

### Conversion
- Every **3 duplicates** of same shard → 1 conversion event
- Use conversions for cosmetic unlocks / future upgrades

## Anchor Blueprints

### 1. `echo_triad_anchor` (Primary, difficulty 3)
- **Co-op required**: minimum 2 builders
- 6 slots: past_core, present_core, future_core, junction_marker, brace_left, brace_right
- Each core slot has `owner_index_required` to enforce per-timeline cooperation
- 240s completion time
- Reward: **500 score** + `perfect_testament` outcome

### 2. `support_wall` (Secondary, difficulty 1)
- **Single player** allowed
- 4 slots: 3 base planks + 1 cap
- 90s completion time
- Reward: **150 score**

## Co-op Rules
1. **Owner enforcement**: Slots with `owner_index_required` reject other players' shards
2. **Idempotency**: Server stores `event_id` → no double-apply on retry
3. **Place_seq**: Each placement gets a monotonic seq → clients reconcile late events
4. **Reverse allowed**: Players can revert their own placements (returns shard to inventory)
5. **Completion effects**: Score award + outcome trigger + audio + VFX

## Security
- Server is **authoritative**: clients only send `place_shard` requests; server validates
- All slots have `valid_shards` allowlist (no type confusion)
- `owner_index_required` enforces per-player cooperation
- Event log stores all placements → audit trail
- Idempotency keys prevent duplicate effects on retry

## Tests
- **`tests/building/test_shard_engine.js`** — 19 tests
- **`tests/building/test_anchor_engine.js`** — 19 tests
- **`tests/building/test_anchor_manager.js`** — 18 tests
- **Total: 56 building-specific tests pass** (147 total in repo)

## Future Extensions
- **Shrine restoration**: build shrines to unlock bonus shards
- **Memory path visualizer**: 3D line showing cause→effect from sharded events
- **Cosmetic anchor skins**: per-player cosmetic color schemes
- **Leaderboards**: track largest anchor network across matches
- **Persistence**: anchors built during co-op are saved and visible in subsequent matches

## Anti-Cheat Considerations
- Server validates every `place_shard` — clients cannot bypass owner rules
- Rate limit on `place_shard` per player (configurable, default 10/sec)
- Anti-replay: each event has unique `event_id` + server tracks `place_seq`
- Client cannot accelerate `deadline_at` (server-only)
- Client cannot grant shards to itself — drops come only from validated Echo resolutions
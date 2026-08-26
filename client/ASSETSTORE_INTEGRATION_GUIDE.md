# ECHO//LINE — Godot AssetStore Integration Plan

> Comprehensive guide for installing premium assets from Godot AssetStore
> to elevate ECHO//LINE visuals, dialogues, icons, names, and roads.

---

## 🎯 Categories Mapped to ECHO//LINE Needs

| Category | Need | Recommended Assets |
|----------|------|-------------------|
| **🎨 Graphics** | Cinematic visuals, post-processing | Phantom Camera, LimboAI (cinematic AI camera) |
| **💬 Dialogue** | Branching conversations, NPC talk | Dialogue Manager (Nathan Hoad), GDQuest Formatter |
| **🎯 Icons** | UI icons, item icons, status icons | @icons — Custom node icons (VoXy) |
| **🛣️ Roads** | Procedural streets, city layouts | Road Generator (TheDuckCow), Terrain3D (Tokisan) |
| **🔊 Sound FX** | UI sounds, ambient, SFX | Sound FX Starter Pack Vol. 1 (Ovani Sound) |
| **🌍 Worlds** | Landscapes, environments | Terrain3D, Sky3D, Godot State Charts |
| **🧠 AI/Behavior** | NPC behavior trees, quests | LimboAI, Kanban Tasks (HolonProduction) |
| **🛠️ Dev Tools** | Code quality, formatting | GDQuest Formatter, GDScript Formatter |
| **🎬 Cinematic** | Cutscenes, camera work | Phantom Camera (Ramokz) |
| **📊 Data** | Resource databases | YARD — Yet Another Resource Database |

---

## � Top 10 Must-Have Assets for ECHO//LINE

### 1. **Phantom Camera** (Ramokz — MIT)
   - **Why**: Cinematic camera transitions, smooth follows, depth of field
   - **Use in ECHO//LINE**:
     - Intro cinematic camera sweep (Past → Present → Future)
     - Player focus during Echo puzzles
     - Smooth transitions between timeline views
   - **License**: MIT (commercial-safe)
   - **Stars**: 71

### 2. **Dialogue Manager** (Nathan Hoad — MIT)
   - **Why**: Industry-standard branching dialogue system
   - **Use in ECHO//LINE**:
     - NPC conversations in Clocktower District
     - Timeline Echo interactions
     - Tutorial/onboarding flows
   - **License**: MIT
   - **Stars**: 52
   - **Critical**: Already have `branching_dialogue.gd` — this is the production-ready replacement

### 3. **Terrain3D** (Tokisan Games — MIT)
   - **Why**: AAA-quality terrain rendering with LOD
   - **Use in ECHO//LINE**:
     - Past timeline (rolling hills, ancient ruins)
     - Present timeline (city streets, buildings)
     - Future timeline (crystal formations, energy fields)
   - **License**: MIT
   - **Stars**: 43

### 4. **@icons — Custom node icons** (VoXy — MIT)
   - **Why**: Visual debugging, code clarity in editor
   - **Use in ECHO//LINE**:
     - Better scene organization (icons on each node)
     - Easier team collaboration
   - **License**: MIT
   - **Stars**: 48

### 5. **Road Generator** (TheDuckCow — MIT)
   - **Why**: Procedural road/intersection generation
   - **Use in ECHO//LINE**:
     - Present timeline city streets
     - Clocktower District roads
     - Aqueduct scenario paths
   - **License**: MIT
   - **Stars**: 15

### 6. **Sound FX Starter Pack Vol. 1** (Ovani Sound — Proprietary)
   - **Why**: 50+ royalty-free SFX for UI/ambience
   - **License**: Proprietary royalty-free for commercial games
   - **Use in ECHO//LINE**:
     - Button click sounds
     - Echo ripple audio
     - Timeline transition whooshes
   - **Stars**: 21

### 7. **LimboAI** (limbonaut — MIT)
   - **Why**: Behavior tree AI for NPCs
   - **Use in ECHO//LINE**:
     - NPC behaviors (shopkeeper, citizens, enemies)
     - Bot AI for offline play
   - **License**: MIT
   - **Stars**: 18

### 8. **Sky3D** (Tokisan Games — MIT)
   - **Why**: Dynamic sky with weather
   - **Use in ECHO//LINE**:
     - Time-of-day shifts per timeline
     - Atmospheric mood changes
   - **License**: MIT
   - **Stars**: 15

### 9. **Godot State Charts** (GodotSteam — MIT)
   - **Why**: Hierarchical state machines
   - **Use in ECHO//LINE**:
     - Player state machine (idle → interact → dialogue → crafting)
     - Echo puzzle state management
   - **License**: MIT
   - **Stars**: 38

### 10. **Godot AI** (dlight — MIT)
    - **Why**: AI assistance in the editor
    - **License**: MIT
    - **Stars**: 20

---

## 📦 Asset Installation Workflow

### Step 1: Open AssetStore in Godot
```
1. Open Godot Editor → click "AssetStore" tab (top-right)
2. Browse / search for an asset
3. Click "Import" (free) or "Buy" (paid)
4. Asset downloaded to your Downloads folder
5. Click "Install" → choose your project's `addons/` folder
```

### Step 2: Enable Plugin
```
1. Project → Project Settings → Plugins
2. Enable the plugin (checkbox)
3. Configure plugin-specific settings
4. Restart editor if prompted
```

### Step 3: Verify Installation
```
1. Check `addons/<plugin_name>/` folder exists
2. Open `addons/<plugin_name>/plugin.cfg` to verify version
3. Test in a small scene
```

### Step 4: Integrate into ECHO//LINE

#### For **Dialogue Manager**:
```gdscript
# In client/ui/dialogue/branching_dialogue.gd
extends Control

@onvar dialogue_manager := preload("res://addons/dialogue_manager/dialogue_manager.gd")

func start_dialogue(resource: DialogueResource):
    DialogueManager.show_dialogue_balloon(resource, "start")
```

#### For **Phantom Camera**:
```gdscript
# In client/scenes/intro.gd
@onready var phantom_camera: PhantomCamera2D = $PhantomCamera2D

func play_intro_cinematic():
    var tween = phantom_camera.tween_to_position(Vector2(256, 128), 3.0)
```

#### For **Terrain3D**:
```gdscript
# In client/gameplay/world_generator.gd
@onvar terrain: Terrain3D = preload("res://addons/terrain_3d/Terrain3D.gd")

func generate_timeline_world(timeline: String):
    terrain.set_region_size(1024)
    terrain.generate_heightmap()
    terrain.apply_textures(PAST_GRASS_TEXTURE)
```

---

## 💡 Pro Tips for AssetStore Integration

1. **Always test in a separate sandbox project first** before integrating into your main game
2. **Keep the license receipts** for any paid assets (you'll need them for legal protection)
3. **Update regularly** but **pin versions** in production for stability
4. **Use version control** (git) so you can revert if an asset breaks your game
5. **Read the documentation** for each asset — they often have specific patterns you should follow
6. **Optimize textures** — AssetStore assets often have uncompressed textures; convert to .webp/.ktx2 for mobile
7. **License summary**:
   - **MIT**: Free for commercial use (most popular)
   - **GPL**: Free but requires your game to also be GPL (avoid for closed source)
   - **Proprietary royalty-free**: Free for use in commercial games (keep receipt)
   - **CC0**: Public domain

---

## 📊 Recommended Purchase Order (by priority for ECHO//LINE)

| Phase | Assets | Estimated Budget |
|-------|--------|------------------|
| **1. Core (free)** | Dialogue Manager, Phantom Camera, LimboAI, State Charts, @icons, GDScript Formatter | $0 |
| **2. Visuals (free)** | Terrain3D, Sky3D, Road Generator, Terrain3D | $0 |
| **3. Audio (paid)** | Sound FX Starter Pack Vol. 1 | $5-20 |
| **4. Polish (paid)** | Premium icon packs, cinematic packs | $20-50 |

---

## 🔗 Quick Access Links (when you have internet in editor)

- AssetStore tab: Click in Godot Editor → AssetStore
- Filter by: Sort: Reviews, Category: All, Source: godotengine.org (Official)

---

## 🎯 Specific ECHO//LINE Integrations (After Installing Assets)

### After installing **Dialogue Manager**:

1. Replace `client/ui/dialogue/branching_dialogue.gd` with DialogueManager integration
2. Create dialogue resources in `data/dialogues/`:
   - `past_intro.dialogue`
   - `present_intro.dialogue`
   - `future_intro.dialogue`
   - `tutorial_steps.dialogue`
3. Add translation keys to `shared/localization/{en,ar}.json`

### After installing **Phantom Camera**:

1. Add `PhantomCamera2D` node to:
   - `client/scenes/intro.tscn` (cinematic intro)
   - `client/scenes/main.tscn` (player focus)
   - `client/scenes/vertical_slice.tscn` (vertical slice demo)
2. Replace `_play_match_intro` in `main.gd` with PhantomCamera tween
3. Save camera presets in `data/cameras/`:
   - `past_view.tres`
   - `present_view.tres`
   - `future_view.tres`
   - `dialogue_view.tres`

### After installing **Terrain3D**:

1. Replace `world_generator.gd` terrain generation with Terrain3D
2. Create 3 terrain assets (one per timeline):
   - `data/terrain/past_terrain.tres`
   - `data/terrain/present_terrain.tres`
   - `data/terrain/future_terrain.tres`
3. Add texture sets per timeline:
   - Past: grass, dirt, ancient stone
   - Present: pavement, brick, steel
   - Future: crystal, energy, hologram

---

## 📁 Suggested Directory Structure (after integration)

```
client/
├── addons/
│   ├── dialogue_manager/          # Branching dialogues
│   ├── phantom_camera/            # Cinematic camera
│   ├── terrain_3d/                # Terrain rendering
│   ├── limboai/                   # NPC AI
│   ├── state_charts/              # State machines
│   ├── @icons/                    # Custom node icons
│   └── godotsteam_gdextension/    # Steam integration (future)
├── data/
│   ├── dialogues/                 # .dialogue files
│   ├── cameras/                   # .tres camera presets
│   ├── terrain/                   # .tres terrain data
│   ├── icons/                     # UI icons (.svg, .png)
│   └── audio/                     # Sound effects (.ogg)
└── shared/
    └── localization/
        ├── en.json
        └── ar.json
```

---

## ✅ Pre-Integration Checklist

- [ ] Create `client/addons/` folder (if not exists)
- [ ] Open AssetStore in Godot Editor
- [ ] Search for "Dialogue Manager" → install
- [ ] Search for "Phantom Camera" → install
- [ ] Search for "Terrain3D" → install
- [ ] Search for "LimboAI" → install
- [ ] Search for "State Charts" → install
- [ ] Search for "@icons" → install
- [ ] Verify each addon shows in Project Settings → Plugins
- [ ] Test each addon in a minimal scene
- [ ] Update ECHO//LINE scripts to use new APIs
- [ ] Commit + push changes

---

## 🆘 Troubleshooting AssetStore Issues

| Issue | Solution |
|-------|----------|
| Addon doesn't appear in Plugins | Check `addons/<name>/plugin.cfg` exists; restart editor |
| Compile errors after install | Read the addon's README; check required dependencies |
| Performance drop | Reduce texture sizes; enable LOD; use QualityProfile tiers |
| License violation | Check the addon's license; keep receipts for paid assets |
| Conflicts with existing code | Use namespace prefixes (e.g., `DM.show_dialogue_balloon()`) |

---

**Last Updated**: 2026-08-26
**Maintainer**: Saif (SaifHu98)
**License Note**: All MIT-licensed addons are commercial-safe. Keep receipts for any paid assets.

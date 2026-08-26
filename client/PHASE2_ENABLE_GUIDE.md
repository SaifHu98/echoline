# ECHO//LINE — Phase 2 Addon Activation Guide

## Goal
Enable the 9 Phase-2 AssetStore addons that polish visuals, audio, and logic.
These addons assume Phase 1 addons are already enabled.

## Addons in Phase 2

| # | Addon | Author | License | Activation type |
|---|-------|--------|---------|-----------------|
| 1 | **Low Poly Terrain Builder** | Fabian S (78sForge) | MIT | Editor plugin (enable in Plugins) |
| 2 | **FoliageFlow** | GdevSarvesh | MIT | Editor plugin |
| 3 | **Tree3D** | Artyom Bozhko (JekSun97) | MIT | GDExtension (auto-loaded) — DESKTOP ONLY |
| 4 | **GodotRetro** | Lucas Ângelo | MIT | Editor plugin (17 CompositorEffect types) |
| 5 | **shaderV2** | (community) | MIT | Pure shader library — no activation needed |
| 6 | **GodotX Health Bar** | Paulo Coutinho | MIT | Editor plugin (2 custom node types) |
| 7 | **GodotX Label Up** | Paulo Coutinho | MIT | Editor plugin (auto-adds autoload) |
| 8 | **Surfaces** | Evan Todd | MIT | Editor plugin |
| 9 | **Godot State Charts** | Jan Thomä | MIT | Editor plugin (StateChart node + debugger) |

---

## Step 1 — Enable editor plugins (7 of 9)

Open `D:\EcoUni\Echos\client` in Godot 4.7.2.

**Project → Project Settings → Plugins** → enable in this order:

| Order | Plugin | Notes |
|-------|--------|-------|
| 1 | Low Poly Terrain Builder | Adds `LowPolyTerrainManager` node |
| 2 | FoliageFlow | Adds `FoliageFlow` node + paint dock |
| 3 | GodotRetro | Adds 17 `Retro*Effect` CompositorEffect types |
| 4 | GodotX Health Bar | Adds `GodotxHealthBarControl` (Control) + `GodotxHealthBar2D` |
| 5 | GodotX Label Up | Auto-adds `/root/GodotxLabelUp` autoload |
| 6 | Surfaces | Adds `Surfaces` class (static detect()) |
| 7 | Godot State Charts | Adds `StateChart` node + debugger |

Restart the editor after enabling — several plugins register autoloads/sidebars
that only become available after restart.

## Step 2 — Verify GDExtensions (1 of 9)

**Tree3D** auto-loads via its `.gdextension` file. Confirm:
- Project → Manage Export Templates → Tree3D binaries appear
- In the Editor 3D viewport, the Add Node dialog should show "Tree3D"

**Important**: Tree3D v0.91 ships ONLY Windows / macOS / Linux binaries.
Android exports will fall back to `tree_spawner.gd`'s MeshInstance3D path.
This is expected — do NOT report Tree3D failures on Android.

## Step 3 — shaderV2 (no activation)

shaderV2 has no plugin — it's a folder of `.gdshaderinc` files.
Just confirm the folder exists at `res://addons/shaderV2/`. Designers can
reference includes from any custom `.gdshader`:

```glsl
shader_type canvas_item;
include "res://addons/shaderV2/rgba/BCSAdjustment.gdshaderinc"
include "res://addons/shaderV2/uv/twirl.gdshaderinc"
```

## Step 4 — Run smoke test

```powershell
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd --phase=2
```

Expected:
```
==================================================
 Total Summary
==================================================
  PASS: 33
  FAIL: 0

  ✓ lowpolyterrain
  ✓ FoliageFlow
  ✓ Tree3D
  ✓ godot_retro
  ✓ shaderV2
  ✓ godotx_health_bar
  ✓ godotx_label_up
  ✓ Surfaces
  ✓ godot_state_charts
```

For both phases at once:
```powershell
& "...Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Expected: **PASS: 60+**, FAIL: 0.

## Step 5 — Integrate each addon

### 5.1 lowpolyterrain → Mobile Terrain
```gdscript
var gen = preload("res://gameplay/mobile_terrain_generator.gd").new()
add_child(gen)
gen.generate_for_timeline("past")
```

### 5.2 FoliageFlow → Foliage Painter
```gdscript
var painter = preload("res://gameplay/foliage_painter.gd").new()
add_child(painter)
painter.attach_to_terrain(mobile_terrain_node, "past")
```

### 5.3 Tree3D → Tree Spawner (Android uses fallback)
```gdscript
var spawner = preload("res://gameplay/tree_spawner.gd").new()
add_child(spawner)
var tree = spawner.spawn_tree(Vector3(0, 0, 0), "past")
```

### 5.4 godot_retro → Timeline Visual Effects
```gdscript
var vfx = preload("res://autoload/timeline_visual_effects.gd").new()
add_child(vfx)
vfx.apply_to_world_environment($WorldEnvironment, "future")  # VHS + glitch
```

### 5.5 shaderV2 → Shader V2 Library
```gdscript
var lib = preload("res://autoload/shader_v2_lib.gd").new()
add_child(lib)
var inc_path = lib.include("rgba", "bloom")
```

### 5.6 GodotX Health Bar → Anchor Health Bar
```gdscript
var bar = preload("res://ui/building/anchor_health_bar.gd").new()
add_child(bar)
bar.set_stability(75.0)
```

### 5.7 GodotX Label Up → Floating Label Service
```gdscript
var labels = preload("res://autoload/floating_label_service.gd").new()
add_child(labels)
labels.damage(enemy_position, $Camera3D, 42.0)
labels.shard(player_position, $Camera3D, 5)
```

### 5.8 Surfaces → Surface Audio Manager
```gdscript
var surf = preload("res://autoload/surface_audio_manager.gd").new()
add_child(surf)
var surface_name = surf.detect_under_player(player_collision_object)
surf.play_footstep(player_collision_object)
```

### 5.9 Godot State Charts → HUD State Chart
```gdscript
var chart = preload("res://ui/hud/hud_state_chart.gd").new()
add_child(chart)
chart.send_event("match_started")
```

## Step 6 — Common failures

| Symptom | Fix |
|---------|-----|
| `class X not registered` after plugin enable | Restart editor; if still broken, delete `.godot/` folder |
| GodotX Label Up doesn't show labels | Verify autoload in Project Settings; it should be `/root/GodotxLabelUp` |
| godot_retro CompositorEffect invisible | Add `WorldEnvironment` node with `compositor` resource to the scene first |
| Tree3D fails on Android | Expected — use `tree_spawner.gd` fallback (MeshInstance3D) |
| Surfaces returns empty string | Material `resource_name` must be set (e.g., "stone", "dirt") |
| StateChart debugger hidden | Window → Debugger → State Charts tab |
| shaderV2 include not found | Verify path; some are sub-nested: `rgba/blur/blur9sample` |

## Step 7 — Build the new APK

After smoke test passes with PASS: 60+, FAIL: 0:

1. Project → Export → Android → Export Project
2. Save as `builds/echoline-v5.apk` (keystore debug for now)
3. APK should grow from 85MB → ~110MB (addons + shaders)
4. After build, deploy to a real Android device and verify:
   - Footstep audio changes per surface
   - Health bar visible on UI
   - Damage numbers float on hit
   - HUD transitions correctly (Hidden → Matching → Recap)
   - World environment changes per timeline (Past TV grain, Future VHS)

## Step 8 — Rollback

If APK fails:
```powershell
git checkout 8453da6 -- client/addons/
# revert wrapper files
git checkout HEAD -- client/autoload/surface_audio_manager.gd client/ui/building/anchor_health_bar.gd client/autoload/floating_label_service.gd client/ui/hud/hud_state_chart.gd client/autoload/timeline_visual_effects.gd client/gameplay/mobile_terrain_generator.gd client/gameplay/foliage_painter.gd client/gameplay/tree_spawner.gd client/autoload/shader_v2_lib.gd
```

## Security

PAT leak reminder: revoke `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`
at https://github.com/settings/tokens.

# ECHO//LINE — Phase 3 Addon Activation Guide

## Goal
Enable the 9 Phase-3 specialized addons. These addons assume Phase 1 + Phase 2
are already enabled. Most of these addons are **editor-only** (CGHEVEN, BlendKit,
Kit Browser) or **future-only** (Aero Physics). Phase 3 wraps them so the
codebase stays future-proof without committing to runtime usage yet.

## Addons in Phase 3

| # | Addon | Author | License | Activation type | Runtime impact |
|---|-------|--------|---------|-----------------|----------------|
| 16 | **LimboAI** | LimboAI Composer | MIT | GDExtension (auto) | Yes — NPC behavior trees |
| 17 | **Nexus Resonance** | Michael Kulzer | MIT | GDExtension + Plugin | Yes — spatial audio (Steam Audio) |
| 18 | **CGHEVEN Asset Library** | CGHEVEN | MIT | Editor dock | No — designer-only |
| 19 | **BlendKit** | Jakub Ruzicka | MIT | Editor dock | No — designer-only |
| 20 | **Gizmo3DScript** | Chris Charbonneau | MIT | Editor plugin | Yes — runtime gizmo node |
| 21 | **Reactive Signal** | iamyoki | MIT | Editor plugin (global class) | Yes — reactive state |
| 22 | **real-controller** | community | MIT | Code-only (no plugin) | Yes — first/third-person controller |
| 23 | **Godot Aerodynamic Physics** | Addmix | MIT | Editor plugin | Yes — drone/vehicle physics |
| 24 | **ProtoForge Kit Browser** | ProtoForge Systems | MIT | Editor dock | No — designer-only |

---

## Step 1 — Enable editor plugins (5 of 9)

Open `D:\EcoUni\Echos\client` in Godot 4.7.2.

**Project → Project Settings → Plugins** → enable in this order:

| Order | Plugin | Restart needed? |
|-------|--------|-----------------|
| 1 | **Nexus Resonance** | YES (Steam Audio GDExtension) |
| 2 | **Gizmo3DScript** | YES (custom node type) |
| 3 | **Reactive Signal** | YES (global class_name) |
| 4 | **Godot Aerodynamic Physics** | YES (9 custom node types) |
| 5 | **CGHEVEN Asset Library** | NO (editor dock) |
| 6 | **Blendkit** | NO (editor dock) |
| 7 | **ProtoForge Kit Browser** | NO (editor dock) |

Restart the editor after steps 1–4. Steps 5–7 are docks that appear immediately.

**Note**: enable **Gizmo3DScript OR Gizmo3DSharp, not both** — they register the
same `Gizmo3D` custom node type and will collide.

## Step 2 — Verify GDExtensions (2 of 9)

**LimboAI** auto-loads via `addons/limboai/bin/limboai.gdextension` (v1.8.1).
Confirm:
- The Add Node dialog shows `BTPlayer`, `BehaviorTree`, `BTBlackboard`.
- Android export templates include `liblimboai.android.template_release.arm64.so`
  (they do — verify via Project → Manage Export Templates).

**Nexus Resonance** auto-loads via `addons/nexus_resonance/nexus_resonance.gdextension`.
Confirm:
- The Add Node dialog shows `ResonanceProbeVolume`, `ResonancePlayer`.
- A new top-bar menu "Nexus Resonance" appears.

**Steamworks SDK linking (Nexus Resonance only):**
- For Steam distribution: link the Steamworks SDK by adding `user://steam_appid.txt`
  with your app ID before publishing.
- For non-Steam distribution: skip this; Resonance still works for spatial
  audio without Steam auth.

## Step 3 — Copy real-controller (code-only)

**real-controller** has no plugin to enable — it's a code library.

Confirm:
- `res://addons/real-controller/character.gd` exists.
- The scene `res://addons/real-controller/character.tscn` is available to copy.

Use `gameplay/player_controller.gd` to wrap it.

## Step 4 — Run smoke test

```powershell
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd --phase=3
```

Expected:
```
==================================================
 Total Summary
==================================================
  PASS: 33
  FAIL: 0

  ✓ limboai
  ✓ nexus_resonance
  ✓ cgheven
  ✓ blendkit
  ✓ Gizmo3DScript
  ✓ reactive_signal
  ✓ real-controller
  ✓ godot_aerodynamic_physics
  ✓ kit_browser
```

For all three phases at once:
```powershell
& "...Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Expected: **PASS: 93+**, FAIL: 0.

## Step 5 — Integrate each addon

### 5.1 LimboAI → NPC Behavior Trees
```gdscript
var npc = preload("res://gameplay/npc_behavior.gd").new()
add_child(npc)
var bt_player = npc.create_bt_player_for_npc("clockmaker", $ClockmakerNPC)
```

Author the .tres resource first: in the FileSystem dock, right-click
`res://behaviors/` → New Resource → BehaviorTree.

### 5.2 Nexus Resonance → Spatial Audio
```gdscript
var res = preload("res://autoload/resonance_audio.gd").new()
add_child(res)
res.apply_to_audio_bus("Master")  # inserts ResonanceAudioEffect on bus 0
# Designers bake probe volumes in editor:
res.bake_probe_volume("res://scenes/present_clock_shop.tscn", quality=2)
```

### 5.3 CGHEVEN → VFX/HDRI library
- Editor only: open the CGHEVEN dock (sidebar), log in, browse.
- Use the wrapper `editor_only/cgheven_lib.gd` for documentation only.

### 5.4 BlendKit → Free Blender assets
- Editor only: top-bar menu → BlendKit → login with blendkit.com credentials.
- Use the wrapper `editor_only/blendkit_browser.gd` for documentation only.

### 5.5 Gizmo3DScript → Runtime gizmos
```gdscript
var gizmo_ctrl = preload("res://ui/building/runtime_gizmo.gd").new()
add_child(gizmo_ctrl)
gizmo_ctrl.attach($ActiveAnchor)
gizmo_ctrl.set_mode("All")
```

### 5.6 Reactive Signal → UI state
```gdscript
var ui = preload("res://autoload/reactive_ui_state.gd").new()
add_child(ui)
ui.set_player_hp(75, 100)
# Any SignalEffect node in the scene auto-rebinds to player_state.value
```

### 5.7 real-controller → Player CharacterBody3D
```gdscript
var ctrl = preload("res://gameplay/player_controller.gd").new()
add_child(ctrl)
ctrl.spawn_in_timeline("present")
# Touch input:
ctrl.apply_touch_movement(Vector2(0.5, 0), true)  # sprint forward
```

### 5.8 Godot Aerodynamic Physics → Drones / Hover shards (future)
```gdscript
var aero = preload("res://gameplay/aero_physics.gd").new()
add_child(aero)
var drone = aero.create_drone("future")
add_child(drone)
var shard = aero.create_hover_shard(Vector3(0, 5, 0))
add_child(shard)
```

### 5.9 Kit Browser → Asset kit indexing (editor only)
- Editor: bottom-dock "Kits" → index `res://meshes/`, `res://materials/`, etc.
- Runtime API:
```gdscript
var index = preload("res://editor_only/asset_index.gd").new()
add_child(index)
var missing = index.list_missing_assets("past")
print("Need to import: ", missing)
```

## Step 6 — Common failures

| Symptom | Fix |
|---------|-----|
| `BTPlayer not found` after enabling LimboAI | Restart editor; LimboAI is a GDExtension, classes register after restart |
| Nexus Resonance classes missing | Re-import project (`Project → Reload Current Project`) |
| Gizmo3DSharp AND Gizmo3DScript both enabled | Disable one — they conflict |
| ResonanceAudioEffect not on bus | Confirm "Nexus Resonance" plugin is enabled (not just GDExtension) |
| LimboAI behavior tree runs at 0 FPS on Android | Reduce substeps_override in BTPlayer properties |
| real-controller character doesn't move | Confirm input actions `ui_up/down/left/right` exist in Project Settings → Input Map |
| AeroBody3D falls infinitely | Add AeroSurface3D children; without them there's no lift/drag |

## Step 7 — Build the new APK

After all three smoke tests pass with PASS: 93, FAIL: 0:

1. Project → Export → Android → Export Project
2. Save as `builds/echoline-v6.apk`
3. APK should grow to ~130MB (GDExtension binaries: limboai, nexus_resonance,
   tree3d, terrain_3d).

After install, verify:
- LimboAI BTPlayer nodes update in debug mode (visible tree state)
- ResonanceAudioEffect appears on the Master bus
- Gizmo3D renders in scene at runtime
- real-controller character responds to virtual joystick on Android

## Step 8 — Rollback

If APK fails or runtime crashes:
```powershell
# Disable the problematic addon in editor, rebuild
# OR revert the wrapper files entirely:
git checkout HEAD -- client/autoload/reactive_ui_state.gd
git checkout HEAD -- client/autoload/resonance_audio.gd
git checkout HEAD -- client/gameplay/npc_behavior.gd
git checkout HEAD -- client/gameplay/aero_physics.gd
git checkout HEAD -- client/gameplay/player_controller.gd
git checkout HEAD -- client/ui/building/runtime_gizmo.gd
git checkout HEAD -- client/editor_only/asset_index.gd
git checkout HEAD -- client/editor_only/blendkit_browser.gd
git checkout HEAD -- client/editor_only/cgheven_lib.gd
```

## Security

PAT leak reminder: revoke the previously exposed GitHub token; never store tokens in documentation.
at https://github.com/settings/tokens.

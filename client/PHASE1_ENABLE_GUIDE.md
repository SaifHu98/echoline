# ECHO//LINE — Phase 1 Addon Activation Guide

## Goal
Enable the 6 Phase-1 AssetStore addons that directly affect visual/gameplay polish:
**dialogue_manager, phantom_camera, terrain_3d, sky_3d, road-generator, at-icons**.

This guide assumes all 6 addons are already extracted into `D:\EcoUni\Echos\client\addons\`.

---

## Step 1 — Open project in Godot Editor

1. Launch `C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe`.
2. Import / Open Project → select `D:\EcoUni\Echos\client\project.godot`.
3. Wait for the editor to finish importing (watch the bottom-right progress bar).

## Step 2 — Enable the 6 plugins

**Project → Project Settings → Plugins** (tab at the top of the dialog).

Enable each of these in this exact order:

| # | Plugin | Author | Restart Editor? |
|---|--------|--------|-----------------|
| 1 | **Dialogue Manager** | Nathan Hoad | YES (autoload registered) |
| 2 | **Phantom Camera** | Marcus Skov | NO |
| 3 | **Terrain3D** | Cory Petkovsek | NO |
| 4 | **Sky3D** | Cory Petkovsek | YES (autoload registered) |
| 5 | **RoadGenerator** | TheDuckCow | YES (editor plugin heavy) |
| 6 | **@icons** | SuperDuperSword | NO |

Click **Enable** for each, then **close and reopen the editor** when prompted.
After all 6 are enabled, the autoloads `DialogueManager` and `Sky3D` should appear in
**Project → Project Settings → Autoload**.

## Step 3 — Run smoke test

After the editor restarts, open a terminal:

```powershell
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Expected output (truncated):
```
==================================================
 ECHO//LINE Phase-1 Addon Smoke Test
==================================================

[dialogue_manager]
  [PASS] plugin.cfg exists — 4.0.3
  [PASS] version >= 4.0.0 — 4.0.3
  [PASS] class DialogueManager registered — enabled in Editor → ...
  [PASS] autoload /root/DialogueManager — set in Project Settings → Autoload
  [PASS] dialogue file present — res://data/dialogues/ECHO_DIALOGUE_SAMPLES.dialogue

[phantom_camera]
  [PASS] plugin.cfg exists — 0.11.0.3
  [PASS] class PhantomCamera3D registered
  [PASS] phantom camera class available — scene-level node

...

==================================================
 Summary
==================================================
  PASS: 28
  FAIL: 0

  ✓ dialogue_manager
  ✓ phantom_camera
  ✓ terrain_3d
  ✓ sky_3d
  ✓ road-generator
  ✓ at-icons

All Phase-1 addons ready. Build APK now.
```

## Step 4 — Verify dialogue autoload

Dialogue Manager must be registered as autoload manually if not auto-detected.

**Project → Project Settings → Autoload** → add:
- Path: `res://addons/dialogue_manager/dialogue_manager.gd`
- Node Name: `DialogueManager`
- Enable: ✓ (Global)

Save the project. Restart editor.

## Step 5 — Test each addon in a 60-second scene

Open any `.tscn` (e.g. `res://scenes/intro.tscn`).
- Press F6 (Play Scene).
- For **dialogue_manager**: the test balloon should appear if you call
  `DialogueManager.show_example_dialogue_balloon("res://data/dialogues/ECHO_DIALOGUE_SAMPLES.dialogue", "intro_echo")`.
- For **phantom_camera**: add a `PhantomCamera3D` node; with a Camera3D selected,
  set its priority to 1, move the camera, watch it snap back.
- For **terrain_3d**: add a `Terrain3D` node, paint a heightmap.
- For **sky_3d**: the `Sky3D` autoload injects a sun + sky into the scene.
- For **road-generator**: a Road dock appears in the bottom panel.
- For **@icons**: an icon picker toolbar appears in the top editor.

## Step 6 — Fix common failures

### "Class X not registered"
Editor needs a hard reload. **Close Godot, delete `.godot/` folder, reopen**.

### "Autoload not found"
Manually add the autoload path (see Step 4).

### "Dialogue file not found"
The smoke test expects `res://data/dialogues/ECHO_DIALOGUE_SAMPLES.dialogue`.
If you didn't import the previous AssetStore integration commit, copy the file
from commit `ec3e3a5`:

```powershell
git show ec3e3a5:client/data/dialogues/ECHO_DIALOGUE_SAMPLES.dialogue > D:\EcoUni\Echos\client\data\dialogues\ECHO_DIALOGUE_SAMPLES.dialogue
```

### "Terrain3D assets missing"
Terrain3D needs default textures. Run once in editor:
**Terrain3D → Plugin Settings → Generate Default Assets**.

### "Sky3D sun missing"
Sky3D needs a sun sprite. In scene with `Sky3D` autoload active:
**Sky3D → Set Sun Sprite** → `res://addons/sky_3d/assets/sun.svg`.

## Step 7 — Build the new APK

After smoke test passes with **PASS: N  FAIL: 0**:

1. **Project → Export → Android** (already configured).
2. **Install Build Template** (only needed once).
3. **Export Project** → `builds/echoline-v5.apk` → keep keystore blank for debug.
4. The APK should be ~95MB (up from 85MB due to addon code).

## Step 8 — Restart Render game server

The game server already has `lobby:list_rooms` + `/api/rooms`. Force restart on
Render dashboard so the new code takes effect.

```powershell
# Local sanity check
curl https://echoline-game-server.onrender.com/api/rooms
```

Should return `{"rooms":[],"count":0}` (or list of test rooms).

---

## Rollback

If the new APK breaks:

```powershell
git revert HEAD
# or
git checkout 8453da6 -- client/addons/
```

The old APK at `D:\EcoUni\Echos\client\echoline.apk` (from commit `8453da6`)
remains valid until the new one is verified.

---

## Security

The GitHub PAT shared in earlier conversations
`<REVOKED_GITHUB_TOKEN_REDACTED>`
**must be revoked** at https://github.com/settings/tokens.

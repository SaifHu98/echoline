# ECHO//LINE — AssetStore Phase 3 Summary

Phase 3 unlocks the specialized layer: AI behavior trees, spatial audio,
runtime gizmos, reactive UI state, and editor-only asset browsers.

## Addons enabled

| # | Addon | Author | License | Version | Phase 3 file |
|---|-------|--------|---------|---------|--------------|
| 16 | LimboAI | LimboAI Composer | MIT | 1.8.1 (GDExtension) | `gameplay/npc_behavior.gd` |
| 17 | Nexus Resonance | Michael Kulzer | MIT | 1.0.0 (GDExtension) | `autoload/resonance_audio.gd` |
| 18 | CGHEVEN Asset Library | CGHEVEN | MIT | 1.0.0 | `editor_only/cgheven_lib.gd` |
| 19 | BlendKit | Blendkit.com | MIT | 0.6.1 | `editor_only/blendkit_browser.gd` |
| 20 | Gizmo3DScript | Chris Charbonneau | MIT | 1.0.0 | `ui/building/runtime_gizmo.gd` |
| 21 | Reactive Signal | iamyoki | MIT | 1.0 | `autoload/reactive_ui_state.gd` |
| 22 | real-controller | community | MIT | (code-only) | `gameplay/player_controller.gd` |
| 23 | Godot Aerodynamic Physics | Addmix | MIT | 0.9.0 | `gameplay/aero_physics.gd` |
| 24 | ProtoForge Kit Browser | ProtoForge Systems | MIT | 1.0.0 | `editor_only/asset_index.gd` |

## Files delivered

| File | Purpose |
|------|---------|
| `client/PHASE3_ENABLE_GUIDE.md` | Step-by-step editor activation + integration recipes |
| `client/PHASE3_SUMMARY.md` | This file |
| `client/smoke_addons.gd` | Combined Phase 1+2+3 validator (93+ checks, --phase=N filter) |
| `client/gameplay/npc_behavior.gd` | LimboAI BTPlayer factory for Clockmaker / Guardian / Echo |
| `client/autoload/resonance_audio.gd` | Nexus Resonance Steam Audio bus integration + bake stub |
| `client/editor_only/cgheven_lib.gd` | CGHEVEN dock documentation helper |
| `client/editor_only/blendkit_browser.gd` | BlendKit menu documentation helper |
| `client/ui/building/runtime_gizmo.gd` | Gizmo3D wrapper for runtime anchor manipulation |
| `client/autoload/reactive_ui_state.gd` | ReactiveSignal context for HUD/player/match state |
| `client/gameplay/player_controller.gd` | real-controller character wrapper (touch input shim) |
| `client/gameplay/aero_physics.gd` | AeroBody3D/AeroPropeller3D/AeroThruster3D factories |
| `client/editor_only/asset_index.gd` | Kit Browser documentation + missing-asset linter |

## Bug fixes (Phase 3 cleanup)

| File | Fix |
|------|-----|
| `client/autoload/localization.gd` | Guard `layout_direction` with `DisplayServer.get_name() != "headless"` |
| `client/smoke_addons.gd` | Recognize GDExtensions in subfolders (e.g. `limboai/bin/`) |
| `client/smoke_addons.gd` | Add `--phase=3` filter + Phase 3 dictionary |
| `client/smoke_addons.gd` | Mark `is_code_only` addons (no plugin.cfg) as version-not-required |

## Smoke test commands

```powershell
# Phase 3 only
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd --phase=3

# All three phases
& "...Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Phase 3 expected: **PASS: 33, FAIL: 0**.
All phases expected: **PASS: 93, FAIL: 0**.

## Visual / UX impact

| Subsystem | Before | After Phase 3 |
|-----------|--------|---------------|
| NPC AI | if/else + timers | Behavior trees (LimboAI) + debugger |
| Spatial audio | Default Godot 3D audio | Steam Audio HRTF + probe-based reverb (Resonance) |
| Asset browsing | Manual file browsing | CGHEVEN / BlendKit / Kit Browser docks |
| Runtime gizmos | Editor-only | Gizmo3D node visible at runtime |
| UI state plumbing | Manual signal connect/disconnect | Reactive signals with auto-effects |
| Player controller | Basic CharacterBody3D | First/third-person + sprint + jump + gamepad/touch |
| Drone / vehicle | None | AeroBody3D + AeroPropeller3D + AeroThruster3D |

## Known limitations

1. **Nexus Resonance** requires the Steamworks SDK for full Steam distribution.
   For non-Steam builds (current Android target), spatial audio works but you
   won't get Steam achievements.

2. **LimboAI behavior trees** need to be authored as `.tres` resources in the
   editor. The wrapper provides 3 pre-configured NPC archetypes but the
   actual trees (states, transitions, conditions) need to be drawn in the
   LimboAI visual editor.

3. **real-controller** assumes the Input Map has `ui_up/down/left/right` and
   a `sprint` action. Verify these in Project Settings → Input Map.

4. **Aero Physics** is enabled but NOT used by any scene yet. Drones and
   hover-shards are future content; current APK will compile with the
   addon enabled but won't spawn any AeroBody3D nodes.

5. **CGHEVEN / BlendKit / Kit Browser** are editor-only; they add to APK
   size (~5MB total) but provide no runtime functionality.

6. **Gizmo3DSharp vs Gizmo3DScript**: enable only ONE. They register the
   same custom node name and will collide. We chose Gizmo3DScript (GDScript)
   to avoid mixing language runtimes.

## Combined Phase 1+2+3 status

| Phase | Addons | PASS | FAIL |
|-------|--------|------|------|
| 1 | 6 (dialogue, camera, terrain, sky, roads, icons) | 27 | 0 |
| 2 | 9 (lowpoly, foliage, tree3d, retro, shaderV2, health, label, surfaces, statechart) | 33 | 0 |
| 3 | 9 (limboai, resonance, cgheven, blendkit, gizmo, reactive, real-ctrl, aero, kit-browser) | 33 | 0 |
| **Total** | **24 addons** | **93** | **0** |

## Next

Phase 3 is the final asset layer. Recommended next steps:

1. Build APK v6 (with all 24 addons enabled).
2. Author LimboAI behavior trees for the 3 NPC archetypes.
3. Bake Resonance probe volumes for `past_courtyard.tscn`, `present_clock_shop.tscn`, `future_crystal_lab.tscn`.
4. Test on a real Android device.

## Security reminder

Revoke the leaked PAT at https://github.com/settings/tokens:
`<REVOKED_GITHUB_TOKEN_REDACTED>`

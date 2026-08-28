# ECHO//LINE — AssetStore Phase 2 Summary

Phase 2 unlocks the polish pass: visuals (post-FX, foliage), audio
(surface-aware footsteps), UI (health bars, floating labels), and logic
(state charts for HUD modes).

## Addons enabled

| # | Addon | Author | License | Version | Phase 2 file |
|---|-------|--------|---------|---------|--------------|
| 7 | Low Poly Terrain Builder | Fabian S (78sForge) | MIT | 1.1.2 | `gameplay/mobile_terrain_generator.gd` |
| 8 | FoliageFlow | GdevSarvesh | MIT | 1.0.0 | `gameplay/foliage_painter.gd` |
| 9 | Tree3D | Artyom Bozhko | MIT | v0.91 (GDExtension) | `gameplay/tree_spawner.gd` |
| 10 | GodotRetro | Lucas Ângelo | MIT | 1.0 | `autoload/timeline_visual_effects.gd` |
| 11 | shaderV2 | community | MIT | (folder of includes) | `autoload/shader_v2_lib.gd` |
| 12 | GodotX Health Bar | Paulo Coutinho | MIT | 2.0.0 | `ui/building/anchor_health_bar.gd` |
| 13 | GodotX Label Up | Paulo Coutinho | MIT | 2.0.0 | `autoload/floating_label_service.gd` |
| 14 | Surfaces | Evan Todd | MIT | 1.0.0 | `autoload/surface_audio_manager.gd` |
| 15 | Godot State Charts | Jan Thomä | MIT | 0.22.5 | `ui/hud/hud_state_chart.gd` |

## Files delivered

| File | Purpose |
|------|---------|
| `client/PHASE2_ENABLE_GUIDE.md` | Step-by-step editor activation |
| `client/PHASE2_SUMMARY.md` | This file |
| `client/smoke_addons.gd` | Combined Phase 1+2 validator (60+ checks) |
| `client/autoload/surface_audio_manager.gd` | Per-surface footstep audio via Surfaces.detect() |
| `client/ui/building/anchor_health_bar.gd` | GodotxHealthBarControl wrapper for Anchor Stability |
| `client/autoload/floating_label_service.gd` | Damage/heal/shard/combo floating numbers |
| `client/ui/hud/hud_state_chart.gd` | 4-state HUD mode chart (Hidden/Matching/Recap/Disconnected) |
| `client/autoload/timeline_visual_effects.gd` | 17 godot_retro CompositorEffects + shaderV2 paths |
| `client/gameplay/mobile_terrain_generator.gd` | lowpolyterrain procedural heightmap (mobile-friendly) |
| `client/gameplay/foliage_painter.gd` | FoliageFlow wrapper with per-timeline mesh banks |
| `client/gameplay/tree_spawner.gd` | Tree3D wrapper + MeshInstance3D fallback (Android) |
| `client/autoload/shader_v2_lib.gd` | shaderV2 include path resolver |

## Bug fixes (Phase 2 cleanup)

| File | Fix |
|------|-----|
| `client/autoload/localization.gd` | Seed `qps_expanded`/`qps_mirrored` catalogs (were crashing on merge) |
| `client/autoload/localization.gd` | Guard `root.layout_direction` assignment (was crashing in headless) |
| `client/smoke_addons.gd` | Refactored into Phase 1 + Phase 2 with `--phase=N` filter |
| `client/smoke_addons.gd` | Detect plugin via plugin.cfg, .gdextension, or folder existence |

## Smoke test commands

```powershell
# Phase 2 only
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd --phase=2

# Both phases
& "...Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Phase 2 expected: **PASS: 33, FAIL: 0**.
Both phases expected: **PASS: 60+, FAIL: 0**.

## Visual / UX impact

| Subsystem | Before | After Phase 2 |
|-----------|--------|--------------|
| HUD mode logic | if/else blocks | StateChart with debugger |
| Health bars | Default ProgressBar | Custom shape-based with tint |
| Damage feedback | Console log | Floating 3D-projected numbers |
| Footstep audio | Single sample | Surface-specific bank (9 surfaces) |
| Past timeline visuals | Plain render | RetroTV + grain + BCS warm tone |
| Present timeline visuals | Plain render | Sharpness + light grain |
| Future timeline visuals | Plain render | VHS + glitch + CRT |
| Mobile terrain | Heavy Terrain3D | Lightweight lowpoly Delaunay mesh |
| Vegetation | None | FoliageFlow painted per timeline |
| Trees | None | Tree3D on desktop / MeshInstance3D on Android |

## Known limitations

1. **Tree3D has no Android binaries.** The wrapper detects the OS at runtime and
   falls back to a CylinderMesh + SphereMesh composite. This is the intended
   behaviour — do not "fix" by trying to build Tree3D for Android.

2. **godot_retro uses CompositorEffect (Godot 4.3+).** Our project is on
   4.7.2 so this is fine, but be aware that any 4.2 export target will lose
   post-FX.

3. **shaderV2 is a folder-only library.** It does not appear in the Plugins
   tab. Verify it via the smoke test's `--phase=2` output instead.

4. **Surfaces requires materials to have `resource_name` set** to
   "stone", "dirt", etc. New terrain shaders must set this manually.

## Next

Phase 3 (specialized): limboai (NPC AI), nexus_resonance (Steam Audio),
cgheven (HDRI/VFX), kit_browser (asset preview), reactive_signal, Gizmo3D.

## Security reminder

Revoke the leaked PAT at https://github.com/settings/tokens:
`<REVOKED_GITHUB_TOKEN_REDACTED>`

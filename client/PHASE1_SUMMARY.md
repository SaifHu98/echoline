# ECHO//LINE — AssetStore Phase 1 Summary

Phase 1 unlocks the visual + cinematic + narrative core of the game.

## Addons enabled

| # | Addon | Author | License | Version | Phase 1 file |
|---|-------|--------|---------|---------|--------------|
| 1 | Dialogue Manager | Nathan Hoad | MIT | 4.0.3 | `autoload/dialogue_service.gd` |
| 2 | Phantom Camera | Marcus Skov (Ramokz) | MIT | 0.11.0.3 | `cinematic_camera_manager.gd` |
| 3 | Terrain3D | Cory Petkovsek, Roope Palmroos | MIT | 1.0.2 (GDExtension) | `gameplay/terrain_world_generator.gd` |
| 4 | Sky3D | Cory Petkovsek, J. Cuéllar | MIT | 2.1 | autoload + scene integration |
| 5 | RoadGenerator | Moo-Ack! Productions | MIT | 0.9.3 | terrain anchor nodes |
| 6 | @icons | SuperDuperSword, Voxy | MIT | 1.4.0 | editor toolbar |

## Files delivered

| File | Purpose |
|------|---------|
| `client/PHASE1_ENABLE_GUIDE.md` | Step-by-step editor activation |
| `client/smoke_addons.gd` | Validates 6 addons in one run |
| `client/cinematic_camera_manager.gd` | 3 PhantomCamera3D presets + intro/recap sequences |
| `client/gameplay/terrain_world_generator.gd` | 3 Terrain3D worlds (past/present/future) with noise heightmap |
| `client/data/dialogues/echo_greetings.dialogue` | Real `.dialogue` file (importable) with 3 labels |
| `client/autoload/dialogue_service.gd` | Wraps DialogueManager.show_dialogue_balloon_scene() |

## Smoke test command

```powershell
cd D:\EcoUni\Echos\client
& "C:\Users\saifx\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --quit --script res://smoke_addons.gd
```

Expected: **PASS: 28, FAIL: 0**.

## Next

Phase 2 will add lowpolyterrain, FoliageFlow, Tree3D, godot_retro, shaderV2,
godotx_health_bar, godotx_label_up, Surfaces, godot_state_charts. Phase 2 unlocks
the polish pass (post-FX, health UI, surface-aware footsteps).

## Security reminder

Revoke the leaked PAT at https://github.com/settings/tokens:
`<REVOKED_GITHUB_TOKEN_REDACTED>`

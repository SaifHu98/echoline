# ECHO//LINE — Performance Budget
**Engine**: Godot 4.7 (Mobile Renderer)
**Target**: Android 8+, OpenGL ES 3.0 / Vulkan 1.1
**Hardware targets**:
- **Low**: Snapdragon 660, Adreno 512, 3GB RAM, Mali T830MP2
- **Medium (default)**: Snapdragon 720G, Adreno 618, 4GB RAM
- **High**: Snapdragon 8 Gen 2, Adreno 740, 8GB RAM

---

## 1. Frame Budget (16.6ms @ 60fps / 33.3ms @ 30fps)

| Stage | Low (ms) | Medium (ms) | High (ms) |
|---|---|---|---|
| **CPU — Game logic** | 4.0 | 6.0 | 8.0 |
| **CPU — Physics (Rapier3D)** | 2.0 | 3.0 | 4.0 |
| **CPU — Audio** | 1.0 | 1.5 | 2.0 |
| **CPU — Networking** | 0.5 | 1.0 | 1.5 |
| **GPU — Forward+ lights** | 4.0 | 5.0 | 6.0 |
| **GPU — Shadows** | 1.0 | 1.5 | 2.0 |
| **GPU — Post-processing** | 0 | 1.0 | 2.5 |
| **GPU — Particles** | 1.5 | 2.0 | 2.5 |
| **GPU — UI** | 1.0 | 1.5 | 2.0 |
| **Reserve (OS + headroom)** | 1.6 | 1.0 | 1.5 |
| **Total** | **16.6** | **23.5** | **30.0** |

**Strategy**: stay at 30 FPS locked on Low (no half-rate rendering needed) and 60 FPS locked on Medium/High. If FPS drops below target, quality auto-degrades one tier (configurable in `QualityProfile.gd`).

---

## 2. Draw Call Budget

| Category | Low | Medium | High |
|---|---|---|---|
| World geometry | 60 | 120 | 200 |
| Props | 25 | 50 | 80 |
| Characters | 12 | 12 | 24 (with shadow casters) |
| UI elements | 80 | 100 | 120 |
| Particles | 30 | 60 | 100 |
| **Total** | **≤ 207** | **≤ 342** | **≤ 524** |

**Mitigation**:
- World uses **static batching** (Godot's `GeometryInstance3D` `gi_lightmap` baked on Low).
- Props beyond 30m use **LOD billboards** (single triangle with alpha texture).
- Characters share **atlas textures** (per timeline).
- UI uses **atlas + 9-slice** (single draw call per panel).

---

## 3. Triangle Budget

| Category | Low | Medium | High |
|---|---|---|---|
| World (per player visible) | 12k | 25k | 50k |
| Props | 4k | 8k | 16k |
| Characters (4 players + bots) | 8k | 16k | 30k |
| Particles (per system) | 200 | 400 | 600 |
| UI | 1k | 2k | 4k |
| **Total** | **≤ 25.2k** | **≤ 51.4k** | **≤ 100.6k** |

**Mitigation**:
- Trees use **impostor LOD**: at distance > 25m, switch to a quad with baked tree-shadow alpha.
- All foliage uses **MeshInstance3D merged via static batching** at startup.
- Particles use **GPU points** with billboard shader (1 tri per particle).

---

## 4. Texture Budget

| Texture | Resolution | Format | Memory |
|---|---|---|---|
| Timeline albedo (3×) | 1024×1024 | ETC2 | 3 × 0.5MB = 1.5MB |
| Timeline normal (3×) | 1024×1024 | ETC2 | 1.5MB |
| Timeline roughness/AO (3×) | 512×512 | ETC2 | 0.4MB |
| Sky / HDR substitute | procedural | — | 0 |
| Character (3 × 4 anims) | 512×512 | ETC2 | 1.2MB |
| UI atlas | 2048×2048 | ETC2 | 2MB |
| Particle atlas | 512×512 | ETC2 | 0.5MB |
| **Total** | | | **7.1MB** |

**Strategy**:
- All textures **ETC2/ASTC compressed** (mobile universal).
- Texture **streaming disabled** — preloaded at scene start.
- **No mipmaps** beyond 4 levels on Low (saves 30% VRAM).

---

## 5. VRAM Budget

| Buffer | Low | Medium | High |
|---|---|---|---|
| Textures | 12MB | 20MB | 40MB |
| Shadow atlas | 8MB (1024²×4) | 16MB (2048²×4) | 32MB (4096²×4) |
| G-buffer (SSR only) | — | — | 16MB |
| Render targets | 4MB (1× 1080p RGBA8) | 8MB (1× 1080p RGBA16) | 12MB |
| Vertex buffers | 2MB | 4MB | 8MB |
| **Total** | **≤ 26MB** | **≤ 48MB** | **≤ 108MB** |

**Targets**:
- Low devices have ~512MB shared VRAM → 26MB is safe.
- Medium devices have ~1GB → 48MB is safe.
- High devices have ~2GB+ → 108MB is safe.

---

## 6. Audio Budget

| Category | Low | Medium | High |
|---|---|---|---|
| Active 2D voices | 8 | 16 | 24 |
| Active 3D voices | 4 | 8 | 12 |
| Reverb voices | 1 | 2 | 2 |
| Sample rate | 22050 Hz | 44100 Hz | 48000 Hz |
| Format | Ogg Vorbis q2 | Ogg Vorbis q4 | Ogg Vorbis q5 |

**Strategy**: voice stealing policy — oldest quietest voice gets cut. Spatial audio uses Godot's HRTF.

---

## 7. Memory (RAM) Budget

| Category | Low | Medium | High |
|---|---|---|---|
| Scene + assets | 50MB | 80MB | 120MB |
| Audio buffers | 8MB | 16MB | 24MB |
| VFX pool (in-flight) | 4MB | 8MB | 12MB |
| Network buffers | 1MB | 2MB | 4MB |
| Working memory | 20MB | 30MB | 50MB |
| **Total** | **≤ 83MB** | **≤ 136MB** | **≤ 210MB** |

---

## 8. Particle Budget

| Effect | Low | Medium | High |
|---|---|---|---|
| Echo ripple | 1 ripple, 0 particles | 1 ripple, 16 particles | 1 ripple, 32 particles + bloom |
| Interaction burst | 4 particles | 8 particles | 12 particles + spark |
| Dust motes (Past ambient) | 30 | 60 | 100 |
| Sparks (Present ambient) | 0 (off) | 20 | 40 |
| Plasma (Future ambient) | 30 | 60 | 120 |
| Cinematic bloom (key moments only) | off | 1× | 1× with refraction |

**Hard rule**: ambient particles turn off when the action panel is open (overdraw cost).

---

## 9. Network Budget

| Packet | Frequency | Size |
|---|---|---|
| Heartbeat | 4/sec | 8 bytes |
| Position update | 10/sec | 16 bytes (compressed) |
| Interaction | on event | 32 bytes |
| State snapshot | every 5s | 200 bytes |
| Voice chat | 50 Kbps Opus | variable |

**Total bandwidth target**: < 30 KB/s average, < 100 KB/s peak.

---

## 10. Battery Budget

| Tier | Target drain (mA) | Hours @ 4000mAh |
|---|---|---|
| Low (30 FPS, all effects off) | 600 | 6.5h |
| Medium (60 FPS, FXAA + bloom) | 1100 | 3.6h |
| High (60 FPS, SSAO + SSR) | 1700 | 2.4h |

**Adaptive**: when battery < 20%, auto-switch to Low.

---

## 11. Optimization Techniques Implemented

### 11.1 Object Pool
- `ObjectPool.gd` already exists, extended with **typed pools per VFX type**.
- **Pre-warmed at scene start**: ripple, spark, dust, plasma each have 16 instances ready.
- **Zero `instantiate()` calls during gameplay loop**.

### 11.2 LOD (Level of Detail)
- Props beyond **30m** become **billboards** with alpha.
- Trees beyond **50m** drop to 1-triangle silhouette.
- World geometry uses **3 LOD levels** for large meshes.

### 11.3 Culling
- **Occlusion culling**: enabled via Godot's `OccluderInstance3D` baked at scene compile.
- **Distance culling**: nodes beyond 80m are `visible = false`.
- **View frustum**: handled by Godot's `Camera3D.cull_mask`.

### 11.4 Lighting
- **Baked GI on Low**: precomputed lightmaps stored as textures.
- **Baked GI on Medium**: lightmaps + 1 dynamic light per timeline.
- **Dynamic GI on High**: 4 dynamic lights, runtime GI.

### 11.5 Shadow Strategy
| Tier | Cascades | Resolution | Distance |
|---|---|---|---|
| Low | 2 | 1024² | 30m |
| Medium | 4 | 2048² | 60m |
| High | 4 | 4096² | 100m |

### 11.6 LOD + Object Pool integration
- `LODNode.gd` automatically swaps to low-poly mesh + reduces material features at distance.
- `VFXPool.gd` pre-allocates particle systems, recycles on release.

### 11.7 Texture Compression
- All textures imported with `compress/high_quality` for ASTC on Vulkan, ETC2 on OpenGL.
- Texture arrays used where multiple variants share UV space.

---

## 12. Profile-Based Auto-Detection

On first launch, run a 5-second microbenchmark:

```gdscript
# scripts/quality_detector.gd
func detect_quality() -> int:
    var gpu_name = RenderingServer.get_video_adapter_name()
    var cpu_cores = OS.get_processor_count()
    var memory_mb = OS.get_memory_info().physical / 1024 / 1024
    
    var score = 0
    # GPU tier
    if "Adreno 7" in gpu_name or "Apple A" in gpu_name: score += 3
    elif "Adreno 6" in gpu_name or "Mali-G7" in gpu_name: score += 2
    elif "Mali-G5" in gpu_name or "Adreno 5" in gpu_name: score += 1
    
    # CPU cores
    score += clamp(cpu_cores - 4, 0, 2)
    
    # RAM
    if memory_mb >= 6000: score += 2
    elif memory_mb >= 3000: score += 1
    
    if score >= 6: return QualityTier.HIGH
    elif score >= 3: return QualityTier.MEDIUM
    else: return QualityTier.LOW
```

The user can override in Settings → Graphics.

---

## 13. Runtime Monitoring

### 13.1 Performance HUD (debug only)
Toggle with F3 in dev builds. Shows:
- FPS / frame time
- Draw calls / triangles
- Particle count
- Memory usage
- Network RTT

### 13.2 Adaptive Quality
If frame time exceeds budget for 60 consecutive frames (1 second), drop one tier automatically. Recover if stable for 5 seconds.

### 13.3 Telemetry
Collect (with user consent) per-minute averages to a local log:
- Average FPS
- Battery drain rate
- Thermal throttle events (via `OS.get_temperature()`)

---

## 14. Test Methodology

### 14.1 Target Devices for QA
- **Low**: Samsung Galaxy A20 (Exynos 7884)
- **Medium**: Samsung Galaxy A52 (Snapdragon 720G)
- **High**: OnePlus 11 (Snapdragon 8 Gen 2)

### 14.2 Test Scenarios
1. **Idle scene**: 60s of camera idle, measure FPS stability.
2. **Active echo chain**: trigger all 12 echoes in succession, measure FPS during VFX peak.
3. **4-player match**: full match with bots, measure sustained FPS over 10 minutes.
4. **Reconnect storm**: kill WiFi 10 times in 60s, measure recovery time.

### 14.3 Acceptance
- ✅ Sustained 30/60/60 FPS on respective tiers for 10 minutes.
- ✅ No frame > 50ms (Low) / 25ms (Medium) / 18ms (High) at the 99th percentile.
- ✅ Battery drain < 1700mA on High tier.
- ✅ APK < 80MB.

---

## 15. APK Size Budget

| Component | Size |
|---|---|
| Engine runtime | 22MB |
| Scenes | 4MB |
| Scripts (compiled) | 2MB |
| Generated textures | 4MB |
| Generated audio (cached on first run) | 0 |
| Fonts | 1MB |
| **Total APK** | **≤ 33MB** |

**Strategy**: procedural assets mean most content is generated at runtime from seeds, not bundled.

---

## 16. Build Pipeline Enforcement

CI (GitHub Actions) runs on every PR:

1. **Linting**: GDScript static analysis via `gdlint`
2. **Tests**: `node --test` for server, Godot headless for client
3. **Profiling**: run vertical slice for 60s on each tier, fail if FPS < target
4. **APK size check**: fail if `client/builds/*.apk` > 80MB
5. **Memory leak check**: run 5min scene, fail if heap > 250MB

A failing CI blocks merging to `main`.

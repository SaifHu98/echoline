# ECHO//LINE — Visual Bible
**Project**: Cooperative Cross-Timeline Multiplayer Social Puzzle
**Engine**: Godot 4.7 (Forward+ Mobile Renderer)
**Target**: Mid-range Android (Snapdragon 660 → 8 Gen 2), 1280×720 → 1920×1080
**Author role**: Art Direction + Technical Art

---

## 1. Core Philosophy

ECHO//LINE is a single-player / cooperative game where **each player inhabits a different timeline** simultaneously. The visual language must make those timelines *immediately distinguishable* through **shape, material, and lighting** — **not color alone** (color-blind safe).

Three pillars:
1. **Cause-and-effect made visible** — when a player acts in one timeline, the others see an "Echo" ripple.
2. **Honest materials** — Past is organic and weathered; Present is industrial and clean; Future is crystalline and holographic.
3. **Restrained post-processing** — bloom is a signal, not decoration. SSR and SSAO are off by default on Low/Medium tiers.

---

## 2. Timeline Identities

Each timeline has a **shape grammar**, **material vocabulary**, **lighting signature**, and **motion language**. Players can identify a timeline with **color removed**.

### ◆ PAST — Amber Heritage
- **Shape grammar**: irregular, hand-cut, carved. Curves preferred over straight lines. Stones chipped at edges.
- **Material vocabulary**: rough sandstone, weathered bronze, sun-bleached wood, hand-spun clay, oiled leather.
- **Lighting**: warm directional sun (5500K, low angle), strong fill from ground bounce, no specular highlights. **Light shafts** through arches.
- **Motion**: organic sway (trees, banners), dripping water, dust motes drifting upward. No hard cuts.
- **Particle palette**: dust motes, water droplets, falling leaves.
- **Sound palette (visualized)**: low brass + strings + reverb. Particles emit on the *downbeat*.
- **Color anchor**: `#D4AF37` (gold), but the timeline reads correctly even desaturated.
- **UI accent glyph**: ◆ (rhombus) — used on buttons, badges, particle shapes.
- **Signature VFX**: ripple shape is a **half-circle arc opening outward** (sun rising).

### ▲ PRESENT — Steel Equilibrium
- **Shape grammar**: clean rectilinear geometry. Bevelled edges, visible welds, machined surfaces. Asymmetric.
- **Material vocabulary**: brushed steel, painted concrete, transparent glass with subtle reflection, anodized aluminum, rubber gaskets.
- **Lighting**: neutral 6500K, balanced key+fill. Soft shadows (penumbra). **No volumetric haze.**
- **Motion**: mechanical pivots, ticking gears, conveyor-like rotation. Smooth easing (cubic).
- **Particle palette**: subtle sparks, steam, oil mist.
- **Sound palette**: clean piano, ticking clockwork. Particles emit on the *beat*.
- **Color anchor**: `#4FC3F7` (cyan-blue). Reads as "neutral" without it.
- **UI accent glyph**: ▲ (triangle) — pointing forward.
- **Signature VFX**: ripple shape is a **concentric square pulse** (ticking).

### ● FUTURE — Violet Spectrum
- **Shape grammar**: hexagons, lattices, smooth crystalline facets. Sharp 60° angles. Floating, anti-gravity.
- **Material vocabulary**: holographic panels, refractive crystal, plasma fields, animated circuits, particle clouds.
- **Lighting**: cool 8000K from above, **animated colored point lights** cycling spectrum. High specular.
- **Motion**: hover-and-glide. Slow rotation (0.5 rad/s), particle streams, chromatic aberration on edges. **Foreshortening emphasized.**
- **Particle palette**: data fragments, plasma sparks, holographic glyphs.
- **Sound palette**: synth pad, glass bells, sub-bass. Particles emit on the *offbeat*.
- **Color anchor**: `#B388FF` (violet-magenta). Reads as "spectral" without it.
- **UI accent glyph**: ● (circle) — completion.
- **Signature VFX**: ripple shape is a **hexagonal expanding frame** (gate opening).

---

## 3. Color System

Each timeline has a **primary** (anchor), **secondary** (support), **accent** (signal), and **neutral** (background). All values are PBR-safe (sRGB → linear).

| Token | Past | Present | Future |
|---|---|---|---|
| `--primary` | `#D4AF37` (gold) | `#4FC3F7` (cyan) | `#B388FF` (violet) |
| `--secondary` | `#8B6F2E` (bronze) | `#2C6E8F` (steel) | `#6B4FBB` (deep violet) |
| `--accent` | `#FFB347` (amber glow) | `#00E5FF` (spark) | `#FF4FBF` (magenta) |
| `--neutral` | `#3A2E1A` (dark wood) | `#1E2429` (gunmetal) | `#1A1530` (deep space) |
| `--ink` | `#F5E6C8` (parchment) | `#E8EEF2` (paper) | `#E0D4FF` (hologram) |
| `--danger` | `#C0392B` (rust) | `#E74C3C` (alert) | `#FF3366` (glitch) |
| `--success` | `#6B8E23` (olive) | `#2ECC71` (green) | `#00FFCC` (plasma) |

**Accessibility**: every state (`danger`, `success`, etc.) carries an icon shape **as well as** color, so color-blind players get the same signal.

---

## 4. Materials

### 4.1 Past — Heritage Stone
- **Base color**: rough tan sandstone (`#9B7E4A` → albedo map)
- **Roughness**: 0.85 (matte, weathered)
- **Metallic**: 0.0 (organic)
- **Normal**: subtle hand-tooled bumps; tiles show chiselled cracks
- **Emissive**: never, except for active Echo glow (`emission = #FFB347`, intensity 0.4)
- **Tri-planar mapping** for low-end devices (no UV stretch on curved stones)

### 4.2 Present — Industrial Steel
- **Base color**: brushed cool gray (`#7C8A93`)
- **Roughness**: 0.35 (semi-matte, brushed)
- **Metallic**: 0.6 (visible reflections)
- **Normal**: parallel brushed grooves (anisotropic on tier HIGH)
- **Emissive**: only on active mechanics (gears, console screens)
- **Anisotropy strength**: 0.4 — directional sheen on rotating gears

### 4.3 Future — Holographic Crystal
- **Base color**: pale violet (`#D9CCFF`)
- **Roughness**: 0.1 (mirror-smooth)
- **Metallic**: 0.0 (dielectric)
- **Normal**: hex-faceted subtle
- **Emissive**: animated (`#B388FF` ↔ `#FF4FBF`), intensity 1.2 base + 0.6 spectrum shift
- **Refraction**: thin glass on consoles, refractive IOR 1.4 on tier HIGH only

---

## 5. Lighting Signatures

| Timeline | Sun (Key) | Fill | Rim | Ambient | Volumetric |
|---|---|---|---|---|---|
| Past | warm 5500K, low angle (45°), energy 1.3 | warm bounce 0.5× | none | sky 0.3× (warm) | god rays through arches (low density) |
| Present | neutral 6500K, mid (60°), energy 1.0 | ambient 0.4× | cool backlight 0.3× | sky 0.4× (neutral) | none |
| Future | cool 8000K, high (75°), energy 1.4 | colored 0.6× | spectrum rim 0.8× | sky 0.5× (cool) | colored fog at low density |

**Shadows**:
- Past: long shadows (low sun). 1024 atlas on Low, 2048 on Medium, 4096 on High.
- Present: medium shadows. Same atlas sizes.
- Future: short shadows + colored ambient. Slightly softer.

**Specular**:
- Always enabled on Medium+.
- Anisotropy on Present gears (Medium+).
- Roughness never below 0.05 (mobile GPU cost).

---

## 6. UI Conventions

### 6.1 Buttons
- **Past buttons**: bevelled sandstone shape, gold border, warm glow on press.
- **Present buttons**: rectangular steel frame, cyan border, spark on press.
- **Future buttons**: hex frame with violet glow, plasma flicker on press.

All buttons share:
- **Touch target ≥ 72dp tall** (Android accessibility)
- **Idle**: outline only; **Hover/Press**: filled; **Disabled**: outline desaturated 40%
- **Animation**: 200ms ease-out scale 1.0 → 0.96 → 1.04 → 1.0 on press

### 6.2 HUD
- **Top-left**: timeline badge with timeline glyph (◆ ▲ ●) + color. Always visible.
- **Top-center**: stability bar (segmented, glyph ticks).
- **Top-right**: timer (MM:SS monospace).
- **Bottom**: action bar with 3 large buttons (88dp tall minimum).
- **Subtitles**: bottom-center, 24pt, 70% opacity background, 2s display, ease-out fade.

### 6.3 Typography
- **Display**: **Cinzel** (Google Fonts) for ECHO//LINE wordmark. Serif, regal, fits Past/Present/Future.
- **UI Latin**: **Inter** (system fallback). 14–32pt.
- **UI Arabic**: **Cairo** (Google Fonts). Matches Inter metrics.
- **Mono (timer)**: **JetBrains Mono**. Monospace fallback.

Font scaling supports accessibility 80% → 160%.

### 6.4 Icons
Every UI state uses an icon glyph alongside color:
- 🟢 success → ✓
- 🔴 danger → �
- 🟡 warn → !
- Timeline glyphs: ◆ ▲ ●
- Action glyphs: 🔧 interact, 📍 ping, 💬 chat, ⏱ pause, � back

---

## 7. VFX Library

### 7.1 Echo Ripple
**Trigger**: a player fires an action that affects another timeline.
**Visual**:
- Shape: timeline-specific (arc / square / hex)
- Color: from-timeline's accent
- Lifetime: 1.5s
- Animation: scale 0 → 5× with exponential ease-out, alpha 0.8 → 0
- Sound: low ping (sine, 440Hz → 880Hz, 200ms)
- Spawned in **both** timelines (origin and target) so players see the cause locally

### 7.2 Timeline Resonance Pulse
**Trigger**: an Echo reaches its target (delayed propagation).
**Visual**:
- 3 concentric rings at target entity
- Timeline-target color
- Lifetime: 2s
- Sound: chime (timeline-specific timbre)

### 7.3 Object Interaction
**Trigger**: player interacts with a prop.
**Visual**:
- Small particle burst (8 sprites, 0.3s lifetime)
- Subtle bloom flash on the prop (0.4s, energy 1.2 → 0.5)
- Audio: tactile click + reverb tail

### 7.4 Cinematic Bloom (used sparingly)
**Trigger**: match starts, ends, key echo.
**Visual**: 1.5s radial bloom with timeline accent color + slow zoom.
**Used at most 3 times per match** — never during gameplay loop.

---

## 8. Motion Language

### 8.1 Camera
- **Follow**: spring-arm camera with 0.15s damping (no instant snap)
- **Cinematic**: dolly + slight roll (max 2°) for drama
- **No handheld shake** — motion is deliberate, not jittery
- **Subtitle camera**: small 5° tilt during voice lines

### 8.2 UI
- **All UI transitions**: 200ms ease-out
- **Page transitions**: 350ms with shared-element fade
- **No bouncy springs** (excessive); only a 1.04 → 1.0 settle on press

### 8.3 World
- **Organic motion** (Past): noise-based sway, 0.3 rad amplitude, 4s period
- **Mechanical motion** (Present): constant rotation, ticks every 1s
- **Crystalline motion** (Future): slow rotation 0.1 rad/s, particle drift upward

---

## 9. Audio-Reactive Visuals

| Audio Event | Visual Response |
|---|---|
| Echo ripple sound | Ripple expands 5% larger |
| Timeline chime | HUD stability bar ticks |
| Match start | Sky brightens 10% over 1s |
| Match win | Slow color grade shift to success hue |
| Match lose | Color grade desaturate 30% + grain |

---

## 10. Cause-Effect Visualization (Echo Trail)

When an Echo propagates from Timeline A → Timeline B:
1. **In A**: ripple spawns at the action entity. Color = A's accent.
2. **In B (delayed 0.3–1.5s based on propagation_delay_ms)**: ripple spawns at the target entity. Color = A's accent (the *cause*, not the *target's* color).
3. **HUD**: small icon at top of screen shows "Echo from ◆ (Past)" with arrow pointing to "→ ▲ (Present)".
4. **Trail**: thin beam between the two entities (only visible to players who can see both timelines, i.e., shared-screen co-op; in split-screen multiplayer each player sees only their own side).

This makes the **cause** visually distinct from the **effect** even when the cause and effect are different timelines.

---

## 11. Restrained Post-Processing

Default per tier:

| Effect | Low | Medium | High |
|---|---|---|---|
| MSAA | off | 2× | 4× |
| FXAA | off | on | on |
| Tonemap | Reinhard | Filmic | Filmic |
| Exposure | 1.0 | 1.05 | 1.1 |
| Bloom | off | on (intensity 0.4) | on (intensity 0.6) |
| Bloom threshold | — | 0.95 | 0.85 |
| SSAO | off | off | on (radius 1.0, power 1.0) |
| SSR | off | off | on (max steps 32, fade 1.0) |
| Glow (UI only) | off | on | on |
| Vignette | on (0.3) | on (0.25) | on (0.2) |
| Chromatic aberration | off | off | micro (0.005) on Future only |

**Philosophy**: post-processing is a *signal*, not decoration. Bloom only appears on active interactions or final beats. No permanent "prettify" filters.

---

## 12. Vertical Slice Showcase

The vertical slice scene (`res://scenes/vertical_slice.tscn`) demonstrates:
1. **Past plaza**: 1 clocktower + 1 workshop + 1 soil bed + 1 canal debris (interactive)
2. **Present courtyard**: 1 clock gear mechanism + 1 courtyard tree + 1 manuscript
3. **Future spire**: 1 gate console + 1 stabilizer unit
4. **3 player characters** in their timelines, each with a unique silhouette
5. **One Echo chain**: lift memory stone → plant seed → water flow → seat gear → tune console → anchor stabilizer
6. **HUD** with timeline badges, stability bar, action bar, mini-map
7. **Echo ripple VFX** triggered automatically every 8s for demo

Camera starts above Past plaza, dollys through Present courtyard, ends in Future spire.

---

## 13. Do's & Don'ts

✅ Use timeline-specific glyphs + colors for state signals.
✅ Spawn VFX in pools, never instantiate inside `_process`.
✅ LOD props beyond 30m (turn to billboard with reduced detail).
✅ Bake ambient light for low tiers; compute it for high.

❌ Don't tint a single mesh with multiple timeline colors.
❌ Don't use particle count > 100 on Low, > 250 on Medium, > 500 on High.
❌ Don't use depth-of-field (mobile GPU cost).
❌ Don't add chromatic aberration globally — only on Future key moments.
❌ Don't use `add_child` for short-lived VFX inside gameplay loop — use `VFXPool`.

---

## 14. Asset Checklist (no third-party IP)

All assets are procedural or original:
- **Geometry**: CSG + procedural noise (no imported meshes)
- **Textures**: generated shaders (no PNGs from copyrighted sources)
- **Audio**: synthesized at runtime (OscillatorStream)
- **Fonts**: Cinzel + Inter + Cairo + JetBrains Mono (all CC-OFL or Apache 2.0)
- **HDR**: procedural sky shader (no HDR file imports)

This makes the project 100% shippable to Google Play without IP risk.

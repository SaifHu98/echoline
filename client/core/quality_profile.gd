extends Node

# Quality Profile System for ECHO//LINE
# 3 tiers with full visual & performance matrix
# Designed for mid-range Android (Snapdragon 720G baseline)

enum Tier {
	LOW_30FPS,           # Older devices, locked 30 FPS
	MEDIUM_60FPS,        # Default for most devices
	HIGH_60FPS_PREMIUM,  # Flagship devices with extra FX
}

# === Active Profile (singleton-style) ===
static var current_tier: int = Tier.MEDIUM_60FPS
static var auto_detect: bool = true
static var adaptive_quality_enabled: bool = true
static var low_fps_streak: int = 0
static var recovery_streak: int = 0

# === Profile Matrix ===
const PROFILES = {
	Tier.LOW_30FPS: {
		"name": "Low",
		"description": "Suitable for older devices. Locked 30 FPS, no post-processing.",
		"target_fps": 30,
		"resolution_scale": 0.75,
		"msaa_2d": 0,            # DISABLED
		"msaa_3d": 0,            # DISABLED
		"screen_space_aa": 0,    # DISABLED
		"shadow_size": 1024,
		"shadow_atlas_count": 2,
		"shadow_distance": 30.0,
		"max_directional_lights": 2,
		"max_omni_lights": 4,
		"max_spot_lights": 2,
		"bloom_enabled": false,
		"bloom_intensity": 0.0,
		"bloom_threshold": 1.0,
		"ssao_enabled": false,
		"ssao_radius": 0.0,
		"ssr_enabled": false,
		"glow_enabled": false,
		"vignette_enabled": true,
		"vignette_intensity": 0.30,
		"chromatic_aberration": 0.0,
		"tonemap": "Reinhard",
		"tonemap_exposure": 1.0,
		"particles_max": 100,
		"particles_dust_motes": 30,
		"particles_sparks": 0,
		"particles_plasma": 30,
		"vfx_pool_size": 16,
		"tree_lod_distance": 25.0,
		"prop_lod_distance": 20.0,
		"billboard_lod_distance": 50.0,
		"audio_voices_2d": 8,
		"audio_voices_3d": 4,
		"audio_sample_rate": 22050,
		"shader_complexity": 1,   # 1=basic, 2=normal, 3=full
		"texture_filter": 2,      # LINEAR
		"anisotropic_filter": 0,  # DISABLED
		"max_lights_per_object": 4,
		"shadow_filter": 0,       # HARD
		"lightmap_baked": true,
		"occlusion_culling": true,
		"distance_cull": 80.0,
		"lod_bias": 0.7,          # aggressive LOD
		"subdivision_skip": 2,
		"frustum_culling": true,
	},
	Tier.MEDIUM_60FPS: {
		"name": "Medium",
		"description": "Default. 60 FPS with FXAA and light bloom.",
		"target_fps": 60,
		"resolution_scale": 1.0,
		"msaa_2d": 2,            # 2X
		"msaa_3d": 2,            # 2X
		"screen_space_aa": 1,    # FXAA
		"shadow_size": 2048,
		"shadow_atlas_count": 4,
		"shadow_distance": 60.0,
		"max_directional_lights": 3,
		"max_omni_lights": 6,
		"max_spot_lights": 4,
		"bloom_enabled": true,
		"bloom_intensity": 0.4,
		"bloom_threshold": 0.95,
		"ssao_enabled": false,
		"ssao_radius": 0.0,
		"ssr_enabled": false,
		"glow_enabled": true,
		"vignette_enabled": true,
		"vignette_intensity": 0.25,
		"chromatic_aberration": 0.0,
		"tonemap": "Filmic",
		"tonemap_exposure": 1.05,
		"particles_max": 250,
		"particles_dust_motes": 60,
		"particles_sparks": 20,
		"particles_plasma": 60,
		"vfx_pool_size": 32,
		"tree_lod_distance": 35.0,
		"prop_lod_distance": 30.0,
		"billboard_lod_distance": 70.0,
		"audio_voices_2d": 16,
		"audio_voices_3d": 8,
		"audio_sample_rate": 44100,
		"shader_complexity": 2,
		"texture_filter": 2,
		"anisotropic_filter": 4,
		"max_lights_per_object": 6,
		"shadow_filter": 2,      # PCF soft
		"lightmap_baked": false,
		"occlusion_culling": true,
		"distance_cull": 100.0,
		"lod_bias": 1.0,
		"subdivision_skip": 1,
		"frustum_culling": true,
	},
	Tier.HIGH_60FPS_PREMIUM: {
		"name": "High",
		"description": "Premium visuals for flagship devices. SSAO, SSR, full bloom, chromatic aberration on Future.",
		"target_fps": 60,
		"resolution_scale": 1.0,
		"msaa_2d": 4,            # 4X
		"msaa_3d": 4,            # 4X
		"screen_space_aa": 1,    # FXAA
		"shadow_size": 4096,
		"shadow_atlas_count": 4,
		"shadow_distance": 100.0,
		"max_directional_lights": 4,
		"max_omni_lights": 8,
		"max_spot_lights": 6,
		"bloom_enabled": true,
		"bloom_intensity": 0.6,
		"bloom_threshold": 0.85,
		"ssao_enabled": true,
		"ssao_radius": 1.0,
		"ssao_power": 1.0,
		"ssr_enabled": true,
		"ssr_max_steps": 32,
		"ssr_fade_in": 0.3,
		"glow_enabled": true,
		"vignette_enabled": true,
		"vignette_intensity": 0.20,
		"chromatic_aberration": 0.005,  # very subtle, Future only
		"tonemap": "Filmic",
		"tonemap_exposure": 1.1,
		"particles_max": 500,
		"particles_dust_motes": 100,
		"particles_sparks": 40,
		"particles_plasma": 120,
		"vfx_pool_size": 64,
		"tree_lod_distance": 50.0,
		"prop_lod_distance": 40.0,
		"billboard_lod_distance": 100.0,
		"audio_voices_2d": 24,
		"audio_voices_3d": 12,
		"audio_sample_rate": 48000,
		"shader_complexity": 3,
		"texture_filter": 2,
		"anisotropic_filter": 16,
		"max_lights_per_object": 8,
		"shadow_filter": 5,      # VSM
		"lightmap_baked": false,
		"occlusion_culling": true,
		"distance_cull": 150.0,
		"lod_bias": 1.5,          # generous LOD (more detail)
		"subdivision_skip": 0,
		"frustum_culling": true,
	},
}


# === Public API ===

static func get_profile(tier: int = -1) -> Dictionary:
	if tier < 0:
		tier = current_tier
	if not PROFILES.has(tier):
		tier = Tier.MEDIUM_60FPS
	return PROFILES[tier]


static func set_tier(tier: int) -> void:
	current_tier = tier
	_apply_to_renderer()


static func get_tier_name(tier: int = -1) -> String:
	var profile = get_profile(tier)
	return profile.get("name", "Unknown")


static func apply_tier_to_scene_tree(tree: SceneTree, tier: int) -> void:
	var profile = get_profile(tier)
	var root = tree.root

	# Frame rate
	Engine.max_fps = profile.target_fps

	# Resolution scale
	root.scaling_3d_scale = profile.resolution_scale

	# MSAA
	var rid = root.get_viewport_rid()
	RenderingServer.viewport_set_msaa_2d(rid, profile.msaa_2d)
	RenderingServer.viewport_set_msaa_3d(rid, profile.msaa_3d)
	RenderingServer.viewport_set_screen_space_aa(rid, profile.screen_space_aa)

	# Shadow atlas
	RenderingServer.directional_shadow_atlas_set_size(profile.shadow_size, true)

	# LOD bias
	root.lod_bias = profile.lod_bias

	# Subdivision
	# Note: actual subdivision is per-mesh; the global setting affects new loads


static func _apply_to_renderer() -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		apply_tier_to_scene_tree(tree, current_tier)


# === Auto-Detection ===

static func detect_tier() -> int:
	var gpu_name: String = RenderingServer.get_video_adapter_name().to_lower()
	var cpu_cores: int = OS.get_processor_count()
	var memory_mb: int = int(OS.get_memory_info().physical / 1024.0 / 1024.0)

	var score: int = 0

	# GPU tier
	if "adreno 7" in gpu_name or "adreno 6" in gpu_name or "apple" in gpu_name:
		score += 3
	elif "adreno 5" in gpu_name or "mali-g7" in gpu_name or "mali-g7" in gpu_name:
		score += 2
	elif "adreno 4" in gpu_name or "mali-g5" in gpu_name or "mali-t8" in gpu_name:
		score += 1

	# CPU cores
	score += clamp(cpu_cores - 4, 0, 2)

	# RAM
	if memory_mb >= 6000:
		score += 2
	elif memory_mb >= 3000:
		score += 1

	if score >= 6:
		return Tier.HIGH_60FPS_PREMIUM
	elif score >= 3:
		return Tier.MEDIUM_60FPS
	else:
		return Tier.LOW_30FPS


# === Adaptive Quality ===

static func report_frame_time(frame_time_ms: float) -> void:
	if not adaptive_quality_enabled:
		return
	var profile = get_profile()
	var budget = 1000.0 / profile.target_fps * 1.20  # 20% slack

	if frame_time_ms > budget:
		low_fps_streak += 1
		recovery_streak = 0
		if low_fps_streak >= 60:
			_downgrade_tier()
			low_fps_streak = 0
	else:
		recovery_streak += 1
		low_fps_streak = 0
		if recovery_streak >= 300:  # 5 seconds
			_upgrade_tier()
			recovery_streak = 0


static func _downgrade_tier() -> void:
	if current_tier == Tier.HIGH_60FPS_PREMIUM:
		set_tier(Tier.MEDIUM_60FPS)
	elif current_tier == Tier.MEDIUM_60FPS:
		set_tier(Tier.LOW_30FPS)


static func _upgrade_tier() -> void:
	if current_tier == Tier.LOW_30FPS:
		set_tier(Tier.MEDIUM_60FPS)
	elif current_tier == Tier.MEDIUM_60FPS:
		set_tier(Tier.HIGH_60FPS_PREMIUM)


# === Persistence ===

static func save_to_disk() -> void:
	var f = FileAccess.open("user://quality_profile.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"tier": current_tier,
			"auto_detect": auto_detect,
			"adaptive": adaptive_quality_enabled,
		}))


static func load_from_disk() -> void:
	if FileAccess.file_exists("user://quality_profile.json"):
		var f = FileAccess.open("user://quality_profile.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			current_tier = parsed.get("tier", Tier.MEDIUM_60FPS)
			auto_detect = parsed.get("auto_detect", true)
			adaptive_quality_enabled = parsed.get("adaptive", true)


# === Diagnostics ===

static func get_summary() -> String:
	var p = get_profile()
	var gpu = RenderingServer.get_video_adapter_name()
	var cpu = OS.get_processor_count()
	var mem = int(OS.get_memory_info().physical / 1024.0 / 1024.0)
	return """
Quality Profile: %s (Tier %d)
Target: %d FPS @ %.0f%% resolution
MSAA: 2D=%dx 3D=%dx FXAA=%d
Shadows: %d atlas @ %d px
Post-FX: bloom=%s ssao=%s ssr=%s
Particles max: %d
GPU: %s
CPU: %d cores
RAM: %d MB
""" % [
		p.name, current_tier,
		p.target_fps, p.resolution_scale * 100,
		p.msaa_2d, p.msaa_3d, p.screen_space_aa,
		p.shadow_atlas_count, p.shadow_size,
		"yes" if p.bloom_enabled else "no",
		"yes" if p.ssao_enabled else "no",
		"yes" if p.ssr_enabled else "no",
		p.particles_max,
		gpu, cpu, mem,
	]


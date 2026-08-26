extends Node

# Mobile Graphics, Frame Rate (FPS), and Performance Optimization Manager

signal graphics_profile_changed(fps_target: int, quality_tier: String)

enum TargetFPS {
	FPS_30_BATTERY_SAVER = 30,
	FPS_60_BALANCED_SMOOTH = 60,
	FPS_90_HIGH_REFRESH = 90,
	FPS_120_ULTRA = 120
}

enum ShadowTier {
	OFF = 0,
	LOW_512 = 512,
	MEDIUM_1024 = 1024,
	HIGH_2048 = 2048
}

var current_fps: int = TargetFPS.FPS_60_BALANCED_SMOOTH
var resolution_scale: float = 1.0 # 0.5 to 1.0
var shadow_quality: int = ShadowTier.MEDIUM_1024
var bloom_enabled: bool = true
var ssao_enabled: bool = false # Disabled by default on mobile for performance
var msaa_level: int = 1 # 0: Off, 1: 2X, 2: 4X
var battery_saver_active: bool = false

func _ready() -> void:
	load_saved_settings()
	apply_all_settings()

func set_target_fps(target: int) -> void:
	current_fps = target
	Engine.max_fps = current_fps
	graphics_profile_changed.emit(current_fps, _get_tier_name())

func set_resolution_scale(scale_val: float) -> void:
	resolution_scale = clamp(scale_val, 0.5, 1.0)
	var root = get_tree().root
	if root:
		root.scaling_3d_scale = resolution_scale

func set_shadow_quality(tier: int) -> void:
	shadow_quality = tier
	if shadow_quality == ShadowTier.OFF:
		RenderingServer.directional_shadow_atlas_set_size(256, false)
	else:
		RenderingServer.directional_shadow_atlas_set_size(shadow_quality, true)

func set_bloom(enabled: bool) -> void:
	bloom_enabled = enabled

func set_msaa(level: int) -> void:
	msaa_level = level
	var root = get_tree().root
	if not root: return

	match msaa_level:
		0:
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED)
		1:
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X)
		2:
			RenderingServer.viewport_set_msaa_3d(root.get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X)

func set_battery_saver_mode(enabled: bool) -> void:
	battery_saver_active = enabled
	if battery_saver_active:
		set_target_fps(TargetFPS.FPS_30_BATTERY_SAVER)
		set_resolution_scale(0.75)
		set_shadow_quality(ShadowTier.LOW_512)
		set_bloom(false)
		set_msaa(0)
	else:
		set_target_fps(TargetFPS.FPS_60_BALANCED_SMOOTH)
		set_resolution_scale(1.0)
		set_shadow_quality(ShadowTier.MEDIUM_1024)
		set_bloom(true)
		set_msaa(1)

func apply_all_settings() -> void:
	set_target_fps(current_fps)
	set_resolution_scale(resolution_scale)
	set_shadow_quality(shadow_quality)
	set_msaa(msaa_level)

func _get_tier_name() -> String:
	match current_fps:
		TargetFPS.FPS_30_BATTERY_SAVER: return "battery_saver"
		TargetFPS.FPS_60_BALANCED_SMOOTH: return "smooth_60"
		TargetFPS.FPS_90_HIGH_REFRESH: return "high_90"
		TargetFPS.FPS_120_ULTRA: return "ultra_120"
		_: return "custom"

func save_settings() -> void:
	var settings = {
		"current_fps": current_fps,
		"resolution_scale": resolution_scale,
		"shadow_quality": shadow_quality,
		"bloom_enabled": bloom_enabled,
		"msaa_level": msaa_level,
		"battery_saver_active": battery_saver_active
	}
	var f = FileAccess.open("user://graphics_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings, "\t"))

func load_saved_settings() -> void:
	if FileAccess.file_exists("user://graphics_settings.json"):
		var f = FileAccess.open("user://graphics_settings.json", FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			current_fps = parsed.get("current_fps", TargetFPS.FPS_60_BALANCED_SMOOTH)
			resolution_scale = parsed.get("resolution_scale", 1.0)
			shadow_quality = parsed.get("shadow_quality", ShadowTier.MEDIUM_1024)
			bloom_enabled = parsed.get("bloom_enabled", true)
			msaa_level = parsed.get("msaa_level", 1)
			battery_saver_active = parsed.get("battery_saver_active", false)


extends Node

# ECHO//LINE — Timeline Visual Effects (Phase 2, godot_retro + shaderV2)
# Composes a WorldEnvironment with timeline-specific post-FX:
#   - Past  → RetroTvEffect + grain (sepia warmth)
#   - Present → RetroSharpnessEffect + subtle grain (clean clarity)
#   - Future → RetroVhsEffect + RetroGlitchSimpleEffect (energy distortion)
#
# godot_retro (Lucas Ângelo, MIT) registers 17 custom CompositorEffect
# types when enabled in Project Settings → Plugins.
#
# shaderV2 is a pure shader-include library (no plugin) — its
# gdshaderinc files can be referenced from any gdshader.

const RETRO_TV := "res://addons/godot_retro/effects/compositor/tv_effect.gd"
const RETRO_VHS := "res://addons/godot_retro/effects/compositor/vhs_effect.gd"
const RETRO_VHS_PAUSE := "res://addons/godot_retro/effects/compositor/vhs_pause_effect.gd"
const RETRO_GRAIN_SIMPLE := "res://addons/godot_retro/effects/compositor/grain_simple_effect.gd"
const RETRO_GRAIN_COMPLEX := "res://addons/godot_retro/effects/compositor/grain_complex_effect.gd"
const RETRO_GLITCH_SIMPLE := "res://addons/godot_retro/effects/compositor/glitch_simple_effect.gd"
const RETRO_GLITCH_COMPLEX := "res://addons/godot_retro/effects/compositor/glitch_complex_effect.gd"
const RETRO_SHARPNESS := "res://addons/godot_retro/effects/compositor/sharpness_effect.gd"
const RETRO_BLUR := "res://addons/godot_retro/effects/compositor/blur_effect.gd"
const RETRO_POSTERIZATION := "res://addons/godot_retro/effects/compositor/posterization_simple_effect.gd"
const RETRO_MONOCHROME := "res://addons/godot_retro/effects/compositor/monochrome_effect.gd"
const RETRO_COLOR := "res://addons/godot_retro/effects/compositor/color_correction_effect.gd"
const RETRO_CRT_BASIC := "res://addons/godot_retro/effects/compositor/crt_basic_effect.gd"

var is_ready: bool = false
var current_timeline: String = "present"

signal effects_changed(timeline: String)


func _ready() -> void:
	is_ready = ClassDB.class_exists("RetroTvEffect") or _file_exists(RETRO_TV)
	if is_ready:
		print("[TimelineVisualEffects] godot_retro CompositorEffects available")
	else:
		push_warning("[TimelineVisualEffects] godot_retro not enabled — effects will be inert")


func apply_to_world_environment(env: WorldEnvironment, timeline: String) -> void:
	current_timeline = timeline
	if not is_ready or env == null:
		return
	var composer: Compositor = env.compositor
	if composer == null:
		return
	composer.compositor_effects.clear()
	var chain: Array = _chain_for_timeline(timeline)
	for entry in chain:
		var path: String = entry["path"]
		if not _file_exists(path):
			continue
		var effect_script: Script = load(path)
		if effect_script == null:
			continue
		var effect: CompositorEffect = effect_script.new()
		if entry.has("intensity"):
			effect.set("intensity", entry["intensity"])
		composer.compositor_effects.append(effect)
	effects_changed.emit(timeline)


func _chain_for_timeline(timeline: String) -> Array:
	match timeline:
		"past":
			return [
				{"path": RETRO_COLOR, "intensity": 0.6},
				{"path": RETRO_TV, "intensity": 0.4},
				{"path": RETRO_GRAIN_SIMPLE, "intensity": 0.25},
			]
		"future":
			return [
				{"path": RETRO_VHS, "intensity": 0.35},
				{"path": RETRO_GLITCH_SIMPLE, "intensity": 0.2},
				{"path": RETRO_CRT_BASIC, "intensity": 0.3},
			]
		_:
			return [
				{"path": RETRO_SHARPNESS, "intensity": 0.4},
				{"path": RETRO_GRAIN_SIMPLE, "intensity": 0.05},
			]


func _file_exists(p: String) -> bool:
	return FileAccess.file_exists(p)


# === shaderV2 include helpers ===
# shaderV2 is a pure library. The shader file would look like:
#
#   shader_type canvas_item;
#   include "res://addons/shaderV2/rgba/BCSAdjustment.gdshaderinc"
#   include "res://addons/shaderV2/uv/twirl.gdshaderinc"
#
# Use these accessors so shaders stay declarative.

static func get_include_path(category: String, effect: String) -> String:
	return "res://addons/shaderV2/%s/%s.gdshaderinc" % [category, effect]

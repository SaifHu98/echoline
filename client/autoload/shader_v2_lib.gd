extends Node

# ECHO//LINE — Shader V2 Library (Phase 2, shaderV2)
# shaderV2 is a PURE shader-include library (no plugin to enable).
# Activation: nothing to enable; the .gdshaderinc files are usable from
# any custom .gdshader.
#
# Usage from a shader file:
#   shader_type canvas_item;
#   include "res://addons/shaderV2/rgba/BCSAdjustment.gdshaderinc"
#   include "res://addons/shaderV2/rgba/blur/blur9sample.gdshaderinc"
#   include "res://addons/shaderV2/uv/pixelate.gdshaderinc"
#
# This autoload exposes convenient paths + GDScript helpers so designers
# don't need to memorise folder structures.

const SHADERV2_BASE := "res://addons/shaderV2"

const CATEGORIES := {
	"rgba": ["BCSAdjustment", "blackNwhite", "blendAwithB", "bloom",
		"blur/blur9sample", "blur/blurCustom", "blur/zoomBlur",
		"generate_shapes/chekerboardPattern", "generate_shapes/generateCircle",
		"generate_shapes/generateCircle2", "glow/innerGlow", "glow/innerGlowEmpty",
		"glow/outerGlow", "glow/outerGlowEmpty", "noise/perlinNoise",
		"noise/simplexNoise", "noise/valueNoise"],
	"uv": ["flipUV", "lensDistortion", "pixelate", "rotate",
		"scaleUV", "sphericalUV", "tileUV", "tilingNoffset",
		"transformUV", "twirl", "distortionUV",
		"animated/distortionUVAnimated", "animated/doodleUV",
		"animated/rotateAnimated", "animated/swirlUV",
		"animated/tilingNoffsetAnimated"],
	"tools": ["sinTime", "remap", "vec2Compose",
		"random/hash1d", "random/hash2d", "random/hash2dvector",
		"random/randomFloat", "random/randomFloat4D",
		"random/randomGoldNoiseFloat"],
}

var is_ready: bool = false


func _ready() -> void:
	is_ready = DirAccess.dir_exists_absolute(SHADERV2_BASE)
	if not is_ready:
		push_warning("[ShaderV2Lib] shaderV2 addon folder missing")
		return
	print("[ShaderV2Lib] shaderV2 shader-includes available")


func include(category: String, effect: String) -> String:
	if not CATEGORIES.has(category):
		push_error("[ShaderV2Lib] Unknown category '%s'" % category)
		return ""
	return "%s/%s/%s.gdshaderinc" % [SHADERV2_BASE, category, effect]


func list_includes(category: String) -> Array:
	return CATEGORIES.get(category, [])


func all_includes() -> Array:
	var out: Array = []
	for cat in CATEGORIES.keys():
		for eff in CATEGORIES[cat]:
			out.append(include(cat, eff))
	return out

extends Node

# ECHO//LINE — Floating Label Service (Phase 2, GodotX Label Up)
# Wraps the GodotX Label Up autoload "GodotxLabelUp" registered by the plugin.
# Activation: enable "GodotX Label Up" in Project Settings → Plugins.
# The plugin auto-adds the autoload; do NOT add it manually.
#
# Use cases:
#   - Damage numbers floating above NPCs / buildings.
#   - Shard gains ("+5 Memory Shards").
#   - Combo counters in the match HUD.

const LABEL_STYLE_PATH := "res://addons/godotx_label_up/runtime/godotx_label_up_style.gd"

enum LabelKind { DAMAGE, HEAL, SHARD, COMBO, NARRATIVE }

var is_ready: bool = false
var _style_cache: Dictionary = {}
var _style_script: Script = null


func _ready() -> void:
	is_ready = ClassDB.class_exists("GodotxLabelUpManager")
	if FileAccess.file_exists(LABEL_STYLE_PATH):
		_style_script = load(LABEL_STYLE_PATH) as Script
	if is_ready:
		print("[FloatingLabelService] GodotX Label Up autoload available")
	else:
		push_warning("[FloatingLabelService] GodotX Label Up plugin not enabled — labels print to console")


func spawn_2d(position: Vector2, text: String, kind: int = LabelKind.DAMAGE) -> int:
	var style: Resource = _get_style(kind)
	if not is_ready or style == null:
		print("[FloatingLabelService] (fallback) %s @ %s" % [text, position])
		return -1
	var label_up: Node = get_node_or_null("/root/GodotxLabelUp")
	if label_up == null:
		print("[FloatingLabelService] (no autoload) %s @ %s" % [text, position])
		return -1
	if label_up.has_method("show"):
		return label_up.call("show", position, text, style)
	return -1


func spawn_world(world_position: Vector3, camera: Camera3D, text: String,
		kind: int = LabelKind.DAMAGE) -> int:
	if camera == null:
		return -1
	var screen: Vector2 = camera.unproject_position(world_position)
	return spawn_2d(screen, text, kind)


# Convenience helpers
func damage(world_pos: Vector3, camera: Camera3D, amount: float) -> int:
	return spawn_world(world_pos, camera, "-%d" % int(amount), LabelKind.DAMAGE)

func heal(world_pos: Vector3, camera: Camera3D, amount: float) -> int:
	return spawn_world(world_pos, camera, "+%d" % int(amount), LabelKind.HEAL)

func shard(world_pos: Vector3, camera: Camera3D, amount: int) -> int:
	return spawn_world(world_pos, camera, "+%d Shard" % amount, LabelKind.SHARD)

func combo(world_pos: Vector3, camera: Camera3D, text: String) -> int:
	return spawn_world(world_pos, camera, text, LabelKind.COMBO)


# === Style cache ===

func _get_style(kind: int) -> Resource:
	if _style_script == null:
		return null
	if _style_cache.has(kind):
		return _style_cache[kind]
	var style: Resource = _style_script.new()
	match kind:
		LabelKind.DAMAGE:
			style.set("color", Color(1.0, 0.3, 0.3, 1.0))
			style.set("outline_color", Color(0.0, 0.0, 0.0, 1.0))
		LabelKind.HEAL:
			style.set("color", Color(0.3, 1.0, 0.4, 1.0))
			style.set("outline_color", Color(0.0, 0.0, 0.0, 1.0))
		LabelKind.SHARD:
			style.set("color", Color(0.85, 0.75, 1.0, 1.0))
			style.set("outline_color", Color(0.1, 0.05, 0.2, 1.0))
		LabelKind.COMBO:
			style.set("color", Color(1.0, 0.85, 0.3, 1.0))
			style.set("outline_color", Color(0.2, 0.05, 0.0, 1.0))
		LabelKind.NARRATIVE:
			style.set("color", Color(1.0, 1.0, 1.0, 1.0))
			style.set("outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_style_cache[kind] = style
	return style

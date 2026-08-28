extends Control

# ECHO//LINE — Anchor Health Bar (Phase 2, GodotX Health Bar)
# Wraps GodotxHealthBarControl (UI) and GodotxHealthBar2D (world overlay).
# Activate the plugin in Project Settings → Plugins to register the custom
# types "GodotxHealthBarControl" and "GodotxHealthBar2D".
#
# Used by building_scene.gd to display Anchor Stability per timeline.

const HEALTH_BAR_CONTROL_PATH := "res://addons/godotx_health_bar/runtime/godotx_health_bar_control.gd"
const HEALTH_BAR_STYLE_PATH := "res://addons/godotx_health_bar/runtime/godotx_health_bar_style.gd"

var _bar: Control = null
var is_ready: bool = false
var _bar_script: Script = null
var _style_script: Script = null


func _ready() -> void:
	is_ready = ClassDB.class_exists("GodotxHealthBarControl")
	if FileAccess.file_exists(HEALTH_BAR_CONTROL_PATH):
		_bar_script = load(HEALTH_BAR_CONTROL_PATH) as Script
	if FileAccess.file_exists(HEALTH_BAR_STYLE_PATH):
		_style_script = load(HEALTH_BAR_STYLE_PATH) as Script
	is_ready = is_ready and _bar_script != null and _style_script != null
	if not is_ready:
		push_warning("[AnchorHealthBar] GodotX Health Bar plugin not enabled")
		return
	_build_bar()


func _build_bar() -> void:
	_bar = _bar_script.new()
	_bar.name = "AnchorStabilityBar"
	_bar.custom_minimum_size = Vector2(220, 22)
	if _bar.has_method("set"):
		_bar.set("min_value", 0.0)
		_bar.set("max_value", 100.0)
		_bar.set("value", 100.0)
	add_child(_bar)


func set_stability(value: float) -> void:
	if _bar == null:
		return
	var clamped: float = clamp(value, 0.0, 100.0)
	if _bar.has_method("set_value"):
		_bar.call("set_value", clamped)


func set_style_fill(color: Color) -> void:
	if _bar == null:
		return
	var style: Resource = _style_script.new()
	if style and style.has_method("set"):
		style.set("fill_color", color)
		_bar.set("style", style)


func set_label(text: String) -> void:
	if _bar and _bar.has_method("set"):
		_bar.set("label_text", text)

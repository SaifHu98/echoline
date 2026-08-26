extends Control

# ECHO//LINE — Anchor Health Bar (Phase 2, GodotX Health Bar)
# Wraps GodotxHealthBarControl (UI) and GodotxHealthBar2D (world overlay).
# Activate the plugin in Project Settings → Plugins to register the custom
# types "GodotxHealthBarControl" and "GodotxHealthBar2D".
#
# Used by building_scene.gd to display Anchor Stability per timeline.

const GodotxHealthBarControlScript := preload("res://addons/godotx_health_bar/runtime/godotx_health_bar_control.gd")
const GodotxHealthBarStyleScript := preload("res://addons/godotx_health_bar/runtime/godotx_health_bar_style.gd")

var _bar: Control = null
var is_ready: bool = false


func _ready() -> void:
	is_ready = ClassDB.class_exists("GodotxHealthBarControl")
	if not is_ready:
		push_warning("[AnchorHealthBar] GodotX Health Bar plugin not enabled")
		return
	_build_bar()


func _build_bar() -> void:
	_bar = GodotxHealthBarControlScript.new()
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
	var style: Resource = GodotxHealthBarStyleScript.new()
	if style and style.has_method("set"):
		style.set("fill_color", color)
		_bar.set("style", style)


func set_label(text: String) -> void:
	if _bar and _bar.has_method("set"):
		_bar.set("label_text", text)

class_name SmartPingWheel
extends Control

# Radial Smart Ping Selector for Mobile Touch and Mouse

signal ping_selected(ping_id: String)

var pings = [
	{ "id": "PING_LOOK_HERE", "loc_key": "ping.look_here", "color": Color("#4A90E2") },
	{ "id": "PING_INTERACT_REQUIRED", "loc_key": "ping.interact_required", "color": Color("#F5A623") },
	{ "id": "PING_DANGER_HAZARD", "loc_key": "ping.danger_hazard", "color": Color("#D0021B") },
	{ "id": "PING_CAUSAL_CHANGE", "loc_key": "ping.causal_change", "color": Color("#7ED321") },
	{ "id": "PING_CODE_FOUND", "loc_key": "ping.code_found", "color": Color("#BD10E0") },
	{ "id": "PING_COUNTDOWN", "loc_key": "ping.countdown", "color": Color("#FF851B") }
]

var is_open: boolean = false
var buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	_build_wheel()

func _build_wheel() -> void:
	var radius = 110.0
	var count = pings.size()
	for i in range(count):
		var angle = (i * 2.0 * PI / count) - (PI / 2.0)
		var btn = Button.new()
		var p_data = pings[i]
		btn.text = Localization.tr_key(p_data["loc_key"])
		btn.custom_minimum_size = Vector2(140, 38)
		btn.position = Vector2(cos(angle) * radius - 70, sin(angle) * radius - 19)

		var style = StyleBoxFlat.new()
		style.bg_color = p_data["color"] * Color(0.8, 0.8, 0.8, 0.9)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func():
			ping_selected.emit(p_data["id"])
			close()
		)
		add_child(btn)
		buttons.append(btn)

func open_at(screen_pos: Vector2) -> void:
	position = screen_pos
	visible = true
	is_open = true

func close() -> void:
	visible = false
	is_open = false

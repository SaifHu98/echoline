class_name VirtualJoystick
extends Control

# Mobile Multi-Touch Virtual Thumbstick with RTL Left/Right Handed Layout Support

signal joystick_updated(output_vector: Vector2)

@export var max_radius: float = 60.0
@export var deadzone: float = 0.15
@export var is_left_handed: boolean = false

var touch_id: int = -1
var stick_center: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var output: Vector2 = Vector2.ZERO

func _ready() -> void:
	EventBus.locale_changed.connect(_on_locale_changed)
	_reposition_joystick()

func _reposition_joystick() -> void:
	var vp_size = get_viewport_rect().size
	if is_left_handed:
		# Position on right side for left-handed dominant play
		position = Vector2(vp_size.x - 140, vp_size.y - 140)
	else:
		# Position on left side by default
		position = Vector2(140, vp_size.y - 140)
	stick_center = size / 2.0
	current_pos = stick_center

func _on_locale_changed(_loc: String, _is_rtl: boolean) -> void:
	_reposition_joystick()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_update_position(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			_reset_joystick()

	elif event is InputEventScreenDrag and event.index == touch_id:
		_update_position(event.position)

func _update_position(touch_pos: Vector2) -> void:
	var diff = touch_pos - stick_center
	var dist = diff.length()

	if dist > max_radius:
		diff = diff.normalized() * max_radius

	current_pos = stick_center + diff
	var raw_output = diff / max_radius

	if raw_output.length() < deadzone:
		output = Vector2.ZERO
	else:
		output = raw_output

	joystick_updated.emit(output)
	queue_redraw()

func _reset_joystick() -> void:
	current_pos = stick_center
	output = Vector2.ZERO
	joystick_updated.emit(output)
	queue_redraw()

func _draw() -> void:
	# Base outer ring
	draw_circle(stick_center, max_radius, Color(1, 1, 1, 0.15))
	draw_arc(stick_center, max_radius, 0, TAU, 32, Color(1, 1, 1, 0.4), 2.0)
	# Inner thumb knob
	draw_circle(current_pos, max_radius * 0.45, Color(0.0, 0.9, 1.0, 0.7))
	draw_circle(current_pos, max_radius * 0.2, Color.WHITE)

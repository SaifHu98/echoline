extends Control

# ECHO//LINE — Virtual Joystick (Touch)

@export var radius: float = 80.0
@export var deadzone: float = 0.15

var touch_index: int = -1
var center_position: Vector2
var knob_position: Vector2
var current_vector: Vector2 = Vector2.ZERO

@onready var bg: Control = $Background
@onready var knob: Control = $Knob


func _ready() -> void:
	center_position = Vector2(size.x / 2, size.y / 2)
	knob.position = center_position - knob.size / 2


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	var local_pos = event.position - global_position
	var dist = (local_pos - center_position).length()

	if event.pressed and dist <= radius + 40:
		touch_index = event.index
		_update_knob(local_pos)
	elif not event.pressed and event.index == touch_index:
		touch_index = -1
		_reset()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != touch_index:
		return
	var local_pos = event.position - global_position
	_update_knob(local_pos)


func _update_knob(local_pos: Vector2) -> void:
	var offset = local_pos - center_position
	var clamped_offset = offset.limit_length(radius)
	knob.position = center_position + clamped_offset - knob.size / 2
	current_vector = clamped_offset / radius

	# Send to player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_movement"):
		player.set_touch_movement(current_vector)


func _reset() -> void:
	knob.position = center_position - knob.size / 2
	current_vector = Vector2.ZERO
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_touch_movement"):
		player.set_touch_movement(Vector2.ZERO)


func get_vector() -> Vector2:
	return current_vector if current_vector.length() > deadzone else Vector2.ZERO

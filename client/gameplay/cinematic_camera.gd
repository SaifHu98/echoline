class_name CinematicCamera
extends Camera3D

# ECHO//LINE — Cinematic Camera System
# Smooth transitions, focus zoom, dramatic angles

enum Mode { FOLLOW_PLAYER, CINEMATIC, FOCUS_OBJECT, OVERVIEW }

var mode: Mode = Mode.FOLLOW_PLAYER
var target: Node3D = null
var focus_offset: Vector3 = Vector3(0, 2, 6)
var focus_smooth_speed: float = 5.0
var cinematic_targets: Array[Dictionary] = []
var cinematic_index: int = 0
var cinematic_duration: float = 0.0
var cinematic_timer: float = 0.0


func _process(delta: float) -> void:
	match mode:
		Mode.CINEMATIC:
			_process_cinematic(delta)
		Mode.FOCUS_OBJECT:
			_process_focus(delta)
		Mode.FOLLOW_PLAYER:
			_process_follow(delta)


func _process_follow(delta: float) -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")
	if not target:
		return

	var target_pos = target.global_position + focus_offset
	global_position = global_position.lerp(target_pos, focus_smooth_speed * delta)
	look_at(target.global_position + Vector3(0, 1.0, 0))


func _process_focus(delta: float) -> void:
	if not target:
		return
	var target_pos = target.global_position + Vector3(0, 2, 4)
	global_position = global_position.lerp(target_pos, focus_smooth_speed * delta)
	look_at(target.global_position)


func _process_cinematic(delta: float) -> void:
	if cinematic_targets.is_empty():
		return
	cinematic_timer += delta
	if cinematic_timer >= cinematic_duration:
		_next_cinematic_target()


func _next_cinematic_target() -> void:
	cinematic_index += 1
	if cinematic_index >= cinematic_targets.size():
		mode = Mode.FOLLOW_PLAYER
		return

	var ct = cinematic_targets[cinematic_index]
	var node = ct.get("node")
	var duration = ct.get("duration", 2.0)
	if node:
		target = node
		focus_offset = ct.get("offset", Vector3(0, 2, 6))
		cinematic_duration = duration
		cinematic_timer = 0.0
		mode = Mode.FOCUS_OBJECT


func play_cinematic_sequence(shots: Array[Dictionary]) -> void:
	cinematic_targets = shots
	cinematic_index = -1
	mode = Mode.CINEMATIC
	_next_cinematic_target()


func focus_on(node: Node3D, offset: Vector3 = Vector3(0, 2, 6)) -> void:
	target = node
	focus_offset = offset
	mode = Mode.FOCUS_OBJECT

class_name DragToSocket
extends Node3D

# Drag-and-Place Interaction Controller for Mobile Touch & Desktop

signal object_socketed(entity_id: String, target_socket_id: String)
signal drag_cancelled(entity_id: String)

@export var snap_distance: float = 1.5
@export var drag_plane_height: float = 1.0

var dragging_object: Node3D = null
var initial_pos: Vector3 = Vector3.ZERO
var available_sockets: Array[Node3D] = []

func register_socket(socket_node: Node3D) -> void:
	if not available_sockets.has(socket_node):
		available_sockets.append(socket_node)

func start_drag(object_node: Node3D) -> void:
	dragging_object = object_node
	initial_pos = object_node.global_position

func update_drag(camera: Camera3D, screen_pos: Vector2) -> void:
	if not dragging_object:
		return

	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	
	# Intersect with horizontal plane at drag_plane_height
	if abs(dir.y) > 0.001:
		var t = (drag_plane_height - from.y) / dir.y
		var world_pos = from + dir * t
		dragging_object.global_position = world_pos

func end_drag() -> void:
	if not dragging_object:
		return

	var snapped_socket = _find_closest_socket(dragging_object.global_position)
	if snapped_socket:
		dragging_object.global_position = snapped_socket.global_position
		object_socketed.emit(dragging_object.name, snapped_socket.name)
	else:
		# Return with tween
		var tween = create_tween()
		tween.tween_property(dragging_object, "global_position", initial_pos, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		drag_cancelled.emit(dragging_object.name)

	dragging_object = null

func _find_closest_socket(pos: Vector3) -> Node3D:
	var closest: Node3D = null
	var min_dist = snap_distance
	for socket in available_sockets:
		var dist = pos.distance_to(socket.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = socket
	return closest

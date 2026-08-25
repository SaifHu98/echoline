class_name InteractionController
extends Node

# Player Movement, Virtual Touch Control & Interaction Triggers

@export var move_speed: float = 5.0
var player_node: Node3D = null
var current_target_echo: String = ""

func _ready() -> void:
	EventBus.interact_requested.connect(_on_interact_requested)

func set_player_node(node: Node3D) -> void:
	player_node = node

func _process(delta: float) -> void:
	if not player_node:
		return

	# Handle Keyboard & Virtual Stick Movement
	var input_vec = Vector2.ZERO
	if Input.is_action_pressed("ui_left"): input_vec.x -= 1.0
	if Input.is_action_pressed("ui_right"): input_vec.x += 1.0
	if Input.is_action_pressed("ui_up"): input_vec.y -= 1.0
	if Input.is_action_pressed("ui_down"): input_vec.y += 1.0

	if input_vec.length_squared() > 0:
		input_vec = input_vec.normalized()
		var move_3d = Vector3(input_vec.x, 0, input_vec.y) * move_speed * delta
		player_node.translate(move_3d)

func check_nearby_interactable(pos: Vector3, interactables: Array) -> String:
	var closest_echo = ""
	var min_dist = 2.5 # Interaction radius
	for item in interactables:
		var dist = pos.distance_to(item.world_pos)
		if dist < min_dist:
			min_dist = dist
			closest_echo = item.echo_id
	current_target_echo = closest_echo
	return closest_echo

func _on_interact_requested(entity_id: String, action_id: String) -> void:
	if current_target_echo != "":
		NetworkClient.send_intent(current_target_echo)

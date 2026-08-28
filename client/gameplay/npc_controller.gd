class_name NPCController
extends Node3D

# ECHO//LINE — NPC Controller (AI)
# Simple AI: idle, wander, interact when approached

enum State { IDLE, WANDER, TALK }

@export var npc_name: String = "Villager"
@export var dialogue_lines: Array[String] = []
@export var wander_radius: float = 5.0
@export var move_speed: float = 2.0
@export var idle_time_min: float = 2.0
@export var idle_time_max: float = 5.0
@export var timeline_color: Color = Color(0.6, 0.6, 0.6)

var state: State = State.IDLE
var wander_target: Vector3 = Vector3.ZERO
var idle_timer: float = 0.0
var current_line_index: int = 0
var label_3d: Label3D = null
var model_node: Node3D = null


func _ready() -> void:
	_setup_visuals()
	_setup_label()
	_start_idle()


func _setup_visuals() -> void:
	model_node = Node3D.new()
	model_node.name = "Model"
	add_child(model_node)

	# Body
	var body = CSGCylinder3D.new()
	body.radius = 0.35
	body.height = 1.4
	body.position = Vector3(0, 0.7, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = timeline_color
	mat.roughness = 0.8
	body.material = mat
	model_node.add_child(body)

	# Head
	var head = CSGSphere3D.new()
	head.radius = 0.25
	head.position = Vector3(0, 1.6, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.75, 0.65)
	head.material = head_mat
	model_node.add_child(head)


func _setup_label() -> void:
	label_3d = Label3D.new()
	label_3d.text = npc_name
	label_3d.font_size = 32
	label_3d.outline_modulate = Color.BLACK
	label_3d.outline_size = 8
	label_3d.position = Vector3(0, 2.2, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label_3d)


func _process(delta: float) -> void:
	match state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)


func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0:
		_start_wander()


func _process_wander(_delta: float) -> void:
	var to_target = wander_target - global_position
	to_target.y = 0
	if to_target.length() < 0.3:
		_start_idle()
		return

	var dir = to_target.normalized()
	var motion = dir * move_speed * _delta
	global_position += Vector3(motion.x, 0, motion.z)

	if model_node:
		model_node.rotation.y = atan2(dir.x, dir.z)


func _start_idle() -> void:
	state = State.IDLE
	idle_timer = randf_range(idle_time_min, idle_time_max)


func _start_wander() -> void:
	state = State.WANDER
	var angle = randf() * TAU
	var dist = randf() * wander_radius
	wander_target = global_position + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func interact(_player: Node3D) -> void:
	if dialogue_lines.is_empty():
		EventBus.subtitle_requested.emit("...", 2.0)
		return

	var line = dialogue_lines[current_line_index]
	current_line_index = (current_line_index + 1) % dialogue_lines.size()
	EventBus.subtitle_requested.emit(npc_name + ": " + line, 4.0)

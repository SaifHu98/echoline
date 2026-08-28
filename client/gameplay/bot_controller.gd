class_name BotController
extends CharacterBody3D

# ECHO//LINE — Advanced Bot AI Controller
# Intelligent NPC with FSM, learning, and adaptive behavior

signal state_changed(new_state: BotState)
signal bot_speech(text: String)
signal bot_action(action: String, target: Node3D)

enum BotState {
	IDLE,            # Waiting, no goal
	PATROL,          # Walking around area
	INVESTIGATE,     # Going to a point of interest
	INTERACT,        # Interacting with a prop
	HELP_TEAMMATE,   # Going to assist another player/bot
	DANGER,          # Reacting to danger
	COMPLETE_OBJECTIVE,  # Working on a quest
	CELEBRATE        # Match won or objective completed
}

enum Personality {
	ARCHIVIST_AGGRESSIVE,   # Past timeline, fast completion
	ENGINEER_BALANCED,      # Present timeline, methodical
	ORACLE_CAUTIOUS,        # Future timeline, careful planning
	SUPPORTIVE              # Helper, prioritizes team
}

@export var bot_name: String = "Bot"
@export var personality: Personality = Personality.ENGINEER_BALANCED
@export var timeline_color: Color = Color(0.5, 0.7, 1)
@export var move_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var rotation_speed: float = 5.0
@export var vision_range: float = 12.0
@export var interaction_range: float = 2.5
@export var decision_interval: float = 1.5

# State tracking
var current_state: BotState = BotState.IDLE
var previous_state: BotState = BotState.IDLE
var state_timer: float = 0.0
var decision_cooldown: float = 0.0
var target_node: Node3D = null
var target_position: Vector3 = Vector3.ZERO
var patrol_center: Vector3 = Vector3.ZERO
var patrol_radius: float = 8.0
var patrol_point: Vector3 = Vector3.ZERO

# Intelligence / learning
var intelligence_level: float = 1.0  # Grows over time
var total_decisions: int = 0
var successful_actions: int = 0
var failure_streak: int = 0
var knowledge_base: Dictionary = {}  # prop_id → success_rate

# References
var model_node: Node3D
var label_3d: Label3D
var speech_bubble: Control
var awareness_indicator: CSGSphere3D
var detection_area: Area3D
var animation_player: AnimationPlayer
var current_prop_target: Node3D = null
var teammate_targets: Array = []


func _ready() -> void:
	add_to_group("bots")
	add_to_group("interactable")  # bots can be talked to
	_setup_visuals()
	_setup_collision()
	_setup_awareness()
	patrol_center = global_position
	_change_state(BotState.PATROL)
	_introduce_self()


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
	mat.metallic = 0.2
	mat.roughness = 0.7
	body.material = mat
	model_node.add_child(body)

	# Head
	var head = CSGSphere3D.new()
	head.radius = 0.22
	head.position = Vector3(0, 1.6, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.75, 0.65)
	head.material = head_mat
	model_node.add_child(head)

	# Glowing marker above head (shows awareness state)
	var marker = CSGSphere3D.new()
	marker.radius = 0.12
	marker.position = Vector3(0, 2.1, 0)
	var marker_mat = StandardMaterial3D.new()
	marker_mat.albedo_color = Color(0, 1, 0.5, 0.8)
	marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(0, 1, 0.5)
	marker_mat.emission_energy_multiplier = 2.0
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material = marker_mat
	awareness_indicator = marker
	model_node.add_child(marker)

	# Name label
	label_3d = Label3D.new()
	label_3d.text = bot_name
	label_3d.font_size = 28
	label_3d.outline_size = 8
	label_3d.outline_modulate = Color.BLACK
	label_3d.position = Vector3(0, 2.5, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label_3d)


func _setup_collision() -> void:
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	shape.shape = capsule
	add_child(shape)


func _setup_awareness() -> void:
	detection_area = Area3D.new()
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = vision_range
	shape.shape = sphere
	detection_area.add_child(shape)
	detection_area.area_entered.connect(_on_area_detected)
	detection_area.area_exited.connect(_on_area_lost)
	add_child(detection_area)


func _physics_process(delta: float) -> void:
	state_timer += delta
	decision_cooldown -= delta

	# Execute current state behavior
	match current_state:
		BotState.IDLE:
			_state_idle(delta)
		BotState.PATROL:
			_state_patrol(delta)
		BotState.INVESTIGATE:
			_state_investigate(delta)
		BotState.INTERACT:
			_state_interact(delta)
		BotState.HELP_TEAMMATE:
			_state_help(delta)
		BotState.DANGER:
			_state_danger(delta)
		BotState.COMPLETE_OBJECTIVE:
			_state_objective(delta)
		BotState.CELEBRATE:
			_state_celebrate(delta)

	# AI decision making periodically
	if decision_cooldown <= 0:
		decide_next_action()
		decision_cooldown = decision_interval

	# Update awareness marker
	_update_awareness_marker()

	# Intelligence grows over time
	intelligence_level += delta * 0.02  # 2% per second


# === STATE MACHINE ===
func _change_state(new_state: BotState) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	state_timer = 0.0
	state_changed.emit(new_state)
	_update_awareness_marker()


# === State Behaviors ===
func _state_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	if state_timer > 2.0:
		_change_state(BotState.PATROL)


func _state_patrol(delta: float) -> void:
	if target_position == Vector3.ZERO or global_position.distance_to(patrol_point) < 1.0:
		_pick_new_patrol_point()

	_move_toward(patrol_point, delta, move_speed * 0.7)

	if state_timer > 8.0:
		_change_state(BotState.IDLE)


func _state_investigate(delta: float) -> void:
	if not is_instance_valid(target_node):
		_change_state(BotState.PATROL)
		return
	_move_toward(target_node.global_position, delta, move_speed)
	if global_position.distance_to(target_node.global_position) < interaction_range:
		_change_state(BotState.INTERACT)


func _state_interact(delta: float) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(target_node):
		_change_state(BotState.IDLE)
		return

	# Face the target
	_look_at(target_node.global_position, delta)

	# Interact
	if target_node.has_method("interact"):
		target_node.interact(self)
		_record_action(target_node.prop_id if "prop_id" in target_node else "unknown", true)
		_say("Done!")
		_change_state(BotState.PATROL)
	else:
		_record_action(target_node.name, false)
		_change_state(BotState.IDLE)


func _state_help(delta: float) -> void:
	if not is_instance_valid(target_node):
		_change_state(BotState.PATROL)
		return
	_move_toward(target_node.global_position, delta, sprint_speed)
	if global_position.distance_to(target_node.global_position) < interaction_range:
		_say("I'm here to help!")
		_change_state(BotState.PATROL)


func _state_danger(_delta: float) -> void:
	velocity = Vector3.ZERO
	_say("Danger!")
	if state_timer > 2.0:
		_change_state(BotState.PATROL)


func _state_objective(delta: float) -> void:
	if not is_instance_valid(target_node):
		_change_state(BotState.PATROL)
		return
	_move_toward(target_node.global_position, delta, move_speed)
	if global_position.distance_to(target_node.global_position) < interaction_range:
		_change_state(BotState.INTERACT)


func _state_celebrate(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Spin in celebration
	model_node.rotation.y += 0.1
	if state_timer > 3.0:
		_change_state(BotState.IDLE)


# === AI Decision Logic ===
func decide_next_action() -> void:
	total_decisions += 1

	# Adapt based on intelligence level
	var options = _get_action_options()
	var weights = _calculate_weights(options)
	var chosen = _weighted_choice(options, weights)

	if chosen.has("type"):
		match chosen.type:
			"patrol":
				_change_state(BotState.PATROL)
				_pick_new_patrol_point()
			"interact":
				if chosen.target:
					target_node = chosen.target
					_change_state(BotState.INVESTIGATE)
			"help":
				if chosen.target:
					target_node = chosen.target
					_change_state(BotState.HELP_TEAMMATE)
			"objective":
				if chosen.target:
					target_node = chosen.target
					_change_state(BotState.COMPLETE_OBJECTIVE)


func _get_action_options() -> Array:
	var options = []

	# Option: Patrol
	options.append({"type": "patrol", "score": 0.5, "data": null})

	# Option: Find interactable props
	var nearby_props = _find_nearby_props()
	for prop in nearby_props:
		var prop_data = {"type": "interact", "target": prop, "score": 0.6}
		# Adjust score based on learned knowledge
		var prop_id = prop.prop_id if "prop_id" in prop else prop.name
		if knowledge_base.has(prop_id):
			prop_data.score *= knowledge_base[prop_id]
		options.append(prop_data)

	# Option: Help teammates
	teammate_targets = _find_teammates_needing_help()
	for teammate in teammate_targets:
		options.append({"type": "help", "target": teammate, "score": 0.8})

	# Option: Work on objectives
	var objective_targets = _find_objective_targets()
	for obj in objective_targets:
		options.append({"type": "objective", "target": obj, "score": 0.9})

	return options


func _calculate_weights(options: Array) -> Array:
	var weights = []
	for opt in options:
		var w = opt.score
		# Personality influences
		match personality:
			Personality.ARCHIVIST_AGGRESSIVE:
				if opt.type == "objective" or opt.type == "interact":
					w *= 1.3
			Personality.ENGINEER_BALANCED:
				pass  # No modifiers
			Personality.ORACLE_CAUTIOUS:
				if opt.type == "patrol":
					w *= 1.2  # More cautious, prefers to scout
			Personality.SUPPORTIVE:
				if opt.type == "help":
					w *= 2.0  # Strongly prioritizes helping

		# Intelligence allows smarter choices
		w *= (1.0 + intelligence_level * 0.1)
		weights.append(w)
	return weights


func _weighted_choice(options: Array, weights: Array) -> Dictionary:
	if options.is_empty():
		return {}
	var total_weight = 0.0
	for w in weights:
		total_weight += w
	var roll = randf() * total_weight
	var cumulative = 0.0
	for i in range(options.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return options[i]
	return options.back()


# === World Interaction ===
func _find_nearby_props() -> Array:
	var found = []
	var world = get_tree().get_first_node_in_group("world")
	if world:
		for child in world.get_children():
			if child.has_method("interact"):
				if global_position.distance_to(child.global_position) < vision_range:
					found.append(child)
	return found


func _find_teammates_needing_help() -> Array:
	var found = []
	# Check for players/bots with low health or in danger
	for bot in get_tree().get_nodes_in_group("bots"):
		if bot == self:
			continue
		if global_position.distance_to(bot.global_position) < vision_range:
			if bot.current_state == BotState.DANGER:
				found.append(bot)
	return found


func _find_objective_targets() -> Array:
	# Look for props that match quest objectives
	var quest_sys = get_tree().get_first_node_in_group("quests")
	if not quest_sys:
		return []
	var found = []
	for child in get_tree().get_nodes_in_group("world"):
		if child.has_method("interact"):
			found.append(child)
	return found


func _move_toward(target: Vector3, delta: float, speed: float) -> void:
	var to_target = target - global_position
	to_target.y = 0
	if to_target.length() < 0.1:
		velocity = Vector3.ZERO
		return
	var dir = to_target.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if model_node:
		var target_rot = atan2(dir.x, dir.z)
		model_node.rotation.y = lerp_angle(model_node.rotation.y, target_rot, rotation_speed * delta)

	move_and_slide()


func _look_at(target: Vector3, delta: float) -> void:
	var to_target = target - global_position
	to_target.y = 0
	if to_target.length() < 0.1:
		return
	var target_rot = atan2(to_target.x, to_target.z)
	if model_node:
		model_node.rotation.y = lerp_angle(model_node.rotation.y, target_rot, rotation_speed * 2.0 * delta)


func _pick_new_patrol_point() -> void:
	var angle = randf() * TAU
	var dist = randf() * patrol_radius
	patrol_point = patrol_center + Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _on_area_detected(area: Area3D) -> void:
	# Could detect props, players, danger zones
	pass


func _on_area_lost(area: Area3D) -> void:
	pass


func _update_awareness_marker() -> void:
	if not awareness_indicator or not awareness_indicator.material:
		return
	var mat = awareness_indicator.material as StandardMaterial3D
	match current_state:
		BotState.IDLE:
			mat.emission = Color(0.5, 0.5, 0.5)
			mat.emission_energy_multiplier = 0.5
		BotState.PATROL:
			mat.emission = Color(0, 1, 0.5)
			mat.emission_energy_multiplier = 1.5
		BotState.INVESTIGATE, BotState.INTERACT, BotState.COMPLETE_OBJECTIVE:
			mat.emission = Color(1, 0.84, 0.4)
			mat.emission_energy_multiplier = 2.0
		BotState.HELP_TEAMMATE:
			mat.emission = Color(0, 0.7, 1)
			mat.emission_energy_multiplier = 2.0
		BotState.DANGER:
			mat.emission = Color(1, 0.2, 0.2)
			mat.emission_energy_multiplier = 3.0
			# Blink
			var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.5 + 0.5
			mat.emission_energy_multiplier = 1.5 + pulse * 2.0
		BotState.CELEBRATE:
			mat.emission = Color(1, 0.95, 0.3)
			mat.emission_energy_multiplier = 2.5


# === Speech & Learning ===
func _say(text: String) -> void:
	bot_speech.emit(text)
	EventBus.subtitle_requested.emit("🤖 " + bot_name + ": " + text, 2.5)


func _introduce_self() -> void:
	var greetings = [
		"Ready to help!",
		"What's the plan?",
		"I can handle it.",
		"Let's do this.",
		"On it!"
	]
	_say(greetings[randi() % greetings.size()])


func _record_action(prop_id: String, success: bool) -> void:
	if success:
		successful_actions += 1
		failure_streak = 0
		# Update knowledge (positive reinforcement)
		if knowledge_base.has(prop_id):
			knowledge_base[prop_id] = min(knowledge_base[prop_id] * 1.05, 1.5)
		else:
			knowledge_base[prop_id] = 1.2
	else:
		failure_streak += 1
		if knowledge_base.has(prop_id):
			knowledge_base[prop_id] = max(knowledge_base[prop_id] * 0.9, 0.3)
		else:
			knowledge_base[prop_id] = 0.7


# === External interaction ===
func interact(_player: Node3D) -> void:
	# Player can talk to bot
	_say("Hello there!")


func get_intelligence() -> float:
	return intelligence_level


func get_skill_rating() -> String:
	var success_rate = float(successful_actions) / max(total_decisions, 1)
	if success_rate > 0.8 and intelligence_level > 3.0:
		return "Master"
	elif success_rate > 0.6 and intelligence_level > 2.0:
		return "Expert"
	elif success_rate > 0.4:
		return "Skilled"
	else:
		return "Novice"

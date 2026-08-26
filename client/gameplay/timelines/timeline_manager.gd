class_name TimelineManager
extends Node3D

# Multi-Timeline Environment & Props Manager for Clocktower District
# Polished: lighting, fog, props, animation

@export var current_timeline: String = "past"

# Environment node references (with safe fallback)
@onready var canal_water_mesh: Node3D = $CanalWater
@onready var courtyard_tree_mesh: Node3D = $CourtyardTree
@onready var turbine_mesh: Node3D = $HydroTurbine
@onready var canopy_bridge_mesh: Node3D = $CanopyBridge
@onready var gate_stabilizer_mesh: Node3D = $GateStabilizer
var world_env: WorldEnvironment
var directional_light: DirectionalLight3D

var turbine_rotation: float = 0.0

func _ready() -> void:
	# Get reference to WorldEnvironment and DirectionalLight from parent scene
	var parent = get_parent()
	if parent:
		var pparent = parent.get_parent()
		if pparent:
			world_env = pparent.get_node_or_null("WorldEnvironment")
			directional_light = pparent.get_node_or_null("DirectionalLight3D")

	if EventBus.has_signal("state_delta_received"):
		EventBus.state_delta_received.connect(_on_state_delta)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)

	_apply_timeline_lighting()
	_setup_environment()


func _process(delta: float) -> void:
	# Animate turbine continuously
	if turbine_mesh and turbine_mesh.visible:
		turbine_rotation += delta * 1.5
		turbine_mesh.rotation.y = turbine_rotation


func _on_match_started(_id: String, initial_state: Dictionary) -> void:
	current_timeline = NetworkClient.my_timeline if NetworkClient.my_timeline != "" else "past"
	_apply_timeline_lighting()
	_reconcile_all_props(initial_state)


func _setup_environment() -> void:
	# Setup WorldEnvironment if exists
	if world_env and world_env.environment:
		var env = world_env.environment
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.glow_enabled = true
		env.glow_intensity = 0.8
		env.glow_bloom = 0.3
		env.glow_hdr_threshold = 0.9


func _apply_timeline_lighting() -> void:
	var env = WorldEnvironment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat

	# Setup light for current timeline
	if directional_light:
		match current_timeline:
			"past":
				# Warm amber golden lighting
				sky_mat.sky_top_color = Color(0.85, 0.65, 0.4)
				sky_mat.sky_horizon_color = Color(0.95, 0.8, 0.6)
				sky_mat.ground_bottom_color = Color(0.5, 0.35, 0.2)
				sky_mat.ground_horizon_color = Color(0.7, 0.55, 0.35)
				directional_light.light_color = Color(1.0, 0.85, 0.6)
				directional_light.light_energy = 1.4
				directional_light.rotation_degrees = Vector3(-45, 30, 0)
			"present":
				# Natural steel blue-gray lighting
				sky_mat.sky_top_color = Color(0.4, 0.55, 0.75)
				sky_mat.sky_horizon_color = Color(0.7, 0.75, 0.8)
				sky_mat.ground_bottom_color = Color(0.3, 0.35, 0.4)
				sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.6)
				directional_light.light_color = Color(1.0, 0.98, 0.95)
				directional_light.light_energy = 1.2
				directional_light.rotation_degrees = Vector3(-50, 45, 0)
			"future":
				# Cold fractured violet & cyan lighting
				sky_mat.sky_top_color = Color(0.25, 0.1, 0.45)
				sky_mat.sky_horizon_color = Color(0.1, 0.6, 0.8)
				sky_mat.ground_bottom_color = Color(0.15, 0.05, 0.2)
				sky_mat.ground_horizon_color = Color(0.3, 0.2, 0.5)
				directional_light.light_color = Color(0.7, 0.85, 1.0)
				directional_light.light_energy = 1.6
				directional_light.rotation_degrees = Vector3(-40, -30, 0)
			_:
				directional_light.light_color = Color(1, 1, 1)
				directional_light.light_energy = 1.0

	if world_env:
		world_env.environment = env


func _on_state_delta(delta: Dictionary) -> void:
	var ent = delta.get("entity", "")
	var prop = delta.get("property", "")
	var val = delta.get("value")

	match ent:
		"canal_basin":
			if canal_water_mesh:
				canal_water_mesh.visible = (val == "flowing")
		"courtyard_tree":
			if courtyard_tree_mesh:
				courtyard_tree_mesh.visible = (val == "mature_oak")
		"canopy_bridge":
			if canopy_bridge_mesh:
				canopy_bridge_mesh.visible = (val == true)
		"hydro_turbine":
			pass  # Animated continuously
		"gate_stabilizer_unit":
			if gate_stabilizer_mesh:
				if val == "active_anchored":
					gate_stabilizer_mesh.modulate = Color(0.4, 1.0, 0.5)
					# Glow effect
					var mat = StandardMaterial3D.new()
					mat.emission_enabled = true
					mat.emission = Color(0.3, 1.0, 0.4)
					mat.emission_energy_multiplier = 1.5
				else:
					gate_stabilizer_mesh.modulate = Color.WHITE


func _reconcile_all_props(state: Dictionary) -> void:
	if not state.has(current_timeline): return
	var tl_state = state[current_timeline]
	for ent in tl_state.keys():
		for prop in tl_state[ent].keys():
			_on_state_delta({
				"timeline": current_timeline,
				"entity": ent,
				"property": prop,
				"value": tl_state[ent][prop]
			})

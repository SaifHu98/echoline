class_name TimelineManager
extends Node3D

# Multi-Timeline Environment & Props Manager for Clocktower District

@export var current_timeline: String = "past"

# Environment node references
@onready var canal_water_mesh: MeshInstance3D = $CanalWater
@onready var courtyard_tree_mesh: MeshInstance3D = $CourtyardTree
@onready var clock_mechanism_mesh: MeshInstance3D = $ClockMechanism
@onready var turbine_mesh: MeshInstance3D = $HydroTurbine
@onready var canopy_bridge_mesh: MeshInstance3D = $CanopyBridge
@onready var gate_stabilizer_mesh: MeshInstance3D = $GateStabilizer

func _ready() -> void:
	EventBus.state_delta_received.connect(_on_state_delta)
	EventBus.match_started.connect(_on_match_started)
	_apply_timeline_lighting()

func _on_match_started(_id: String, initial_state: Dictionary) -> void:
	current_timeline = NetworkClient.my_timeline
	_apply_timeline_lighting()
	_reconcile_all_props(initial_state)

func _apply_timeline_lighting() -> void:
	var env = WorldEnvironment.new()
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()

	match current_timeline:
		"past":
			# Warm amber golden lighting
			sky_mat.sky_top_color = Color(0.85, 0.65, 0.4)
			sky_mat.sky_horizon_color = Color(0.95, 0.8, 0.6)
		"present":
			# Natural steel blue-gray lighting
			sky_mat.sky_top_color = Color(0.4, 0.55, 0.75)
			sky_mat.sky_horizon_color = Color(0.7, 0.75, 0.8)
		"future":
			# Cold fractured violet & cyan lighting
			sky_mat.sky_top_color = Color(0.25, 0.1, 0.45)
			sky_mat.sky_horizon_color = Color(0.1, 0.6, 0.8)

	sky.sky_material = sky_mat

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
			if turbine_mesh:
				turbine_mesh.rotate_y(0.1) # Animated when powered
		"gate_stabilizer_unit":
			if gate_stabilizer_mesh:
				gate_stabilizer_mesh.modulate = Color.GOLD if val == "active_anchored" else Color.WHITE

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

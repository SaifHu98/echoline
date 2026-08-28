extends Node3D

# ECHO//LINE — Aero Physics (Phase 3, Godot Aerodynamic Physics)
# Wraps AeroBody3D, AeroSurface3D, AeroPropeller3D, AeroThruster3D (Addmix,
# MIT). The plugin adds 9 custom node types when enabled in
# Project → Project Settings → Plugins.
#
# Activation: enable "Godot Aerodynamic Physics" in Project Settings → Plugins.
#
# ECHO//LINE use cases (future, NOT in current APK):
#   - Time-travel drone that the Future player pilots over the timeline.
#   - Glider anchor: a Memory Shard that hovers via propellers.
#   - Cinematic vehicle flythrough between Past/Present/Future.
#
# Current scope: wrapper only — no scene uses Aero* nodes yet. The wrapper
# provides factories so the building system can spawn them procedurally.

const AERO_BODY_PATH := "res://addons/godot_aerodynamic_physics/core/aero_body_3d.gd"
const AERO_PROPELLER_PATH := "res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_mover_3d/aero_propeller_3d.gd"
const AERO_THRUSTER_PATH := "res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_thruster_3d/aero_thruster_3d.gd"

var _aero_body_script: Script = null
var _aero_propeller_script: Script = null
var _aero_thruster_script: Script = null

var is_ready: bool = false


func _ready() -> void:
	is_ready = ClassDB.class_exists("AeroBody3D")
	if FileAccess.file_exists(AERO_BODY_PATH):
		_aero_body_script = load(AERO_BODY_PATH) as Script
	if FileAccess.file_exists(AERO_PROPELLER_PATH):
		_aero_propeller_script = load(AERO_PROPELLER_PATH) as Script
	if FileAccess.file_exists(AERO_THRUSTER_PATH):
		_aero_thruster_script = load(AERO_THRUSTER_PATH) as Script
	is_ready = is_ready and _aero_body_script != null and _aero_propeller_script != null and _aero_thruster_script != null
	if not is_ready:
		push_warning("[AeroPhysics] Godot Aerodynamic Physics not enabled")


# === Factories ===

func create_drone(timeline: String) -> Node3D:
	if not is_ready:
		return null
	var body: Node3D = _aero_body_script.new()
	body.name = "DroneBody_" + timeline.capitalize()
	if body.has_method("set_mass"):
		body.call("set_mass", 2.0)
	var propeller: Node3D = _aero_propeller_script.new()
	propeller.name = "Propeller"
	if propeller.has_method("set_thrust"):
		propeller.call("set_thrust", 25.0)
	body.add_child(propeller)
	return body


func create_hover_shard(shard_position: Vector3) -> Node3D:
	if not is_ready:
		return null
	var body: Node3D = _aero_body_script.new()
	body.name = "HoverShard"
	body.global_position = shard_position
	if body.has_method("set_mass"):
		body.call("set_mass", 0.5)
	var thruster: Node3D = _aero_thruster_script.new()
	thruster.name = "HoverThruster"
	if thruster.has_method("set_thrust"):
		thruster.call("set_thrust", 6.0)
	body.add_child(thruster)
	return body


func is_addon_enabled() -> bool:
	return is_ready

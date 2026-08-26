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

const AeroBody3DScript := preload("res://addons/godot_aerodynamic_physics/core/aero_body_3d.gd")
const AeroSurface3DScript := preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_surface_3d/aero_surface_3d.gd")
const AeroPropeller3DScript := preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_mover_3d/aero_propeller_3d.gd")
const AeroThruster3DScript := preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_thruster_3d/aero_thruster_3d.gd")

var is_ready: bool = false


func _ready() -> void:
	is_ready = ClassDB.class_exists("AeroBody3D")
	if not is_ready:
		push_warning("[AeroPhysics] Godot Aerodynamic Physics not enabled")


# === Factories ===

func create_drone(timeline: String) -> Node3D:
	if not is_ready:
		return null
	var body: Node3D = AeroBody3DScript.new()
	body.name = "DroneBody_" + timeline.capitalize()
	if body.has_method("set_mass"):
		body.call("set_mass", 2.0)
	var propeller: Node3D = AeroPropeller3DScript.new()
	propeller.name = "Propeller"
	if propeller.has_method("set_thrust"):
		propeller.call("set_thrust", 25.0)
	body.add_child(propeller)
	return body


func create_hover_shard(shard_position: Vector3) -> Node3D:
	if not is_ready:
		return null
	var body: Node3D = AeroBody3DScript.new()
	body.name = "HoverShard"
	body.global_position = shard_position
	if body.has_method("set_mass"):
		body.call("set_mass", 0.5)
	var thruster: Node3D = AeroThruster3DScript.new()
	thruster.name = "HoverThruster"
	if thruster.has_method("set_thrust"):
		thruster.call("set_thrust", 6.0)
	body.add_child(thruster)
	return body


func is_addon_enabled() -> bool:
	return is_ready

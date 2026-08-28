extends Node3D

# ECHO//LINE — Mobile Terrain Generator (Phase 2, lowpolyterrain)
# Lightweight alternative to Terrain3D for the Android target.
# Activation: enable "Low Poly Terrain Builder" in Project Settings → Plugins.
# Adds the custom node type "LowPolyTerrainManager" usable in scenes.
#
# We construct the terrain procedurally via LowPolyTerrainManager API
# + a deterministic Delaunay heightmap (no sculpting required).

const LOWPOLY_MANAGER_PATH := "res://addons/lowpolyterrain/LowPolyTerrainManager.gd"

const TIMELINE_PROFILES := {
	"past": {
		"total_size_meters": Vector2(256.0, 256.0),
		"chunk_resolution": 32,
		"height_amplitude": 60.0,
		"frequency": 0.015,
		"color_base": Color(0.42, 0.32, 0.22),
	},
	"present": {
		"total_size_meters": Vector2(256.0, 256.0),
		"chunk_resolution": 32,
		"height_amplitude": 20.0,
		"frequency": 0.010,
		"color_base": Color(0.30, 0.32, 0.30),
	},
	"future": {
		"total_size_meters": Vector2(256.0, 256.0),
		"chunk_resolution": 32,
		"height_amplitude": 90.0,
		"frequency": 0.025,
		"color_base": Color(0.12, 0.22, 0.40),
	},
}

var terrain: Node3D = null
var current_timeline: String = ""
var is_ready: bool = false
var _lowpoly_manager_script: Script = null

signal mobile_terrain_ready(timeline: String, node: Node3D)


func _ready() -> void:
	is_ready = ClassDB.class_exists("LowPolyTerrainManager")
	if FileAccess.file_exists(LOWPOLY_MANAGER_PATH):
		_lowpoly_manager_script = load(LOWPOLY_MANAGER_PATH) as Script
	is_ready = is_ready and _lowpoly_manager_script != null
	if not is_ready:
		push_warning("[MobileTerrainGenerator] lowpolyterrain not enabled — using flat PlaneMesh fallback")


func generate_for_timeline(timeline: String) -> void:
	if not TIMELINE_PROFILES.has(timeline):
		push_error("[MobileTerrainGenerator] Unknown timeline '%s'" % timeline)
		return
	current_timeline = timeline
	if not is_ready:
		_build_fallback(timeline)
		return
	_build_lowpoly(timeline, TIMELINE_PROFILES[timeline])


func _build_lowpoly(timeline: String, profile: Dictionary) -> void:
	if terrain and is_instance_valid(terrain):
		terrain.queue_free()
	terrain = _lowpoly_manager_script.new()
	terrain.name = "MobileTerrain_" + timeline.capitalize()
	terrain.set("total_size_meters", profile.total_size_meters)
	add_child(terrain)
	_apply_height_field(profile)
	mobile_terrain_ready.emit(timeline, terrain)


func _apply_height_field(profile: Dictionary) -> void:
	if terrain == null:
		return
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = profile.frequency
	var amplitude: float = profile.height_amplitude
	# Use the chunk API to drive heights
	if terrain.has_method("set_height_at"):
		var step: int = 4
		var size: Vector2 = profile.total_size_meters
		for x in range(-int(size.x / 2), int(size.x / 2), step):
			for z in range(-int(size.y / 2), int(size.y / 2), step):
				var h: float = noise.get_noise_2d(float(x), float(z)) * amplitude
				terrain.call("set_height_at", Vector3(x, 0, z), h)


func _build_fallback(timeline: String) -> void:
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(256, 256)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.name = "FallbackMobileTerrain_" + timeline.capitalize()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TIMELINE_PROFILES[timeline].color_base
	mesh_instance.material_override = mat
	add_child(mesh_instance)
	terrain = mesh_instance
	mobile_terrain_ready.emit(timeline, mesh_instance)

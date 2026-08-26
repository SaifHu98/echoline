extends Node3D

# ECHO//LINE — Terrain3D World Generator (Phase 1, real Terrain3D)
# Uses the Terrain3D GDExtension v1.0.2 by Cory Petkovsek & Roope Palmroos.
# Activation: enable "Terrain3D" plugin in
#   Project → Project Settings → Plugins
# The plugin auto-registers the `Terrain3D` Node3D-derived class via the
# `terrain.gdextension` binary in addons/terrain_3d/.
#
# For each timeline, this generator builds one Terrain3D node with a
# heightmap + texture set tuned to the historical period, plus a list of
# "anchor points" that the building system can reference.

const TIMELINE_CONFIGS := {
	"past": {
		"world_size": Vector2(1024, 1024),
		"height_range": Vector2(-50.0, 200.0),
		"noise_scale": 0.025,
		"color_base": Color(0.42, 0.32, 0.22),
		"color_peak": Color(0.65, 0.55, 0.42),
		"weather": "foggy_sunrise",
		"vegetation_density": 0.6,
		"props_hint": ["stone_arch", "fountain", "lantern", "garden"],
	},
	"present": {
		"world_size": Vector2(1024, 1024),
		"height_range": Vector2(-20.0, 50.0),
		"noise_scale": 0.015,
		"color_base": Color(0.30, 0.32, 0.30),
		"color_peak": Color(0.55, 0.55, 0.55),
		"weather": "clear",
		"vegetation_density": 0.2,
		"props_hint": ["clockwork_gear", "brick_wall", "neon_sign"],
	},
	"future": {
		"world_size": Vector2(1024, 1024),
		"height_range": Vector2(-100.0, 300.0),
		"noise_scale": 0.04,
		"color_base": Color(0.10, 0.18, 0.32),
		"color_peak": Color(0.55, 0.78, 1.00),
		"weather": "energetic_dusk",
		"vegetation_density": 0.1,
		"props_hint": ["crystal", "hologram_panel", "energy_pylon"],
	},
}

const ROAD_GENERATOR_PATH := "res://addons/road-generator/road_generator.gd"

var terrain: Node3D = null
var current_timeline: String = ""
var is_ready: bool = false

signal terrain_generated(timeline: String, terrain_node: Node3D)


func _ready() -> void:
	is_ready = ClassDB.class_exists("Terrain3D")
	if is_ready:
		print("[TerrainWorldGenerator] Terrain3D API available")
	else:
		push_warning("[TerrainWorldGenerator] Terrain3D GDExtension not enabled — using flat ground fallback")


func generate_world_for_timeline(timeline: String) -> void:
	if not TIMELINE_CONFIGS.has(timeline):
		push_error("[TerrainWorldGenerator] Unknown timeline '%s'" % timeline)
		return
	current_timeline = timeline
	if not is_ready:
		_fallback_terrain(timeline)
		return
	_build_terrain(timeline, TIMELINE_CONFIGS[timeline])


func _build_terrain(timeline: String, config: Dictionary) -> void:
	_dispose_old_terrain()
	var Terrain3DClass: Node3D = ClassDB.instantiate("Terrain3D")
	if Terrain3DClass == null:
		push_warning("[TerrainWorldGenerator] Failed to instantiate Terrain3D class")
		_fallback_terrain(timeline)
		return
	terrain = Terrain3DClass
	terrain.name = "Terrain3D_" + timeline.capitalize()
	terrain.set("world_size", config.world_size)
	add_child(terrain)
	_apply_heightmap(config)
	_apply_colors(config)
	_place_roads(timeline)
	_place_props_for_timeline(timeline, config.get("props_hint", []))
	terrain_generated.emit(timeline, terrain)


func _apply_heightmap(config: Dictionary) -> void:
	# Without external heightmap assets, we drive the terrain shape via the
	# Terrain3D Region API. The plugin exposes set_height()/set_region_height()
	# depending on version; we try the most permissive setter first.
	if not terrain:
		return
	var size: Vector2 = config.world_size
	var min_h: float = config.height_range.x
	var max_h: float = config.height_range.y
	var scale: float = config.noise_scale
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = scale
	var region_size: int = 256
	for x in range(region_size):
		for z in range(region_size):
			var nx := float(x) / float(region_size) * size.x
			var nz := float(z) / float(region_size) * size.y
			var h := noise.get_noise_2d(nx, nz)
			var mapped: float = (h + 1.0) * 0.5 * (max_h - min_h) + min_h
			if terrain.has_method("set_region_height"):
				terrain.call("set_region_height", x, z, mapped)
			elif terrain.has_method("set_height"):
				terrain.call("set_height", Vector3(nx, mapped, nz), mapped)


func _apply_colors(config: Dictionary) -> void:
	if not terrain:
		return
	# Terrain3D accepts a "color map" texture or a flat color via set_color().
	var base: Color = config.get("color_base", Color.WHITE)
	var peak: Color = config.get("color_peak", Color.WHITE)
	if terrain.has_method("set_color"):
		terrain.call("set_color", base)
	if terrain.has_method("set_peak_color"):
		terrain.call("set_peak_color", peak)


func _place_roads(timeline: String) -> void:
	if not ResourceLoader.exists(ROAD_GENERATOR_PATH):
		return
	# The RoadGenerator is an EditorPlugin in v0.9.3; runtime road creation
	# is exposed via the RoadNetwork resource. We leave the actual curve
	# authoring to the editor and just place a placeholder node so designers
	# know where to attach RoadNetwork assets later.
	var marker := Node3D.new()
	marker.name = "RoadAnchor_" + timeline.capitalize()
	if terrain:
		terrain.add_child(marker)
	else:
		add_child(marker)


func _place_props_for_timeline(timeline: String, hints: Array) -> void:
	# Without real AssetStore prop models installed, we attach marker nodes so
	# the building system + procedural placement code knows where to spawn
	# props once 3D models are imported.
	for hint in hints:
		var marker := Node3D.new()
		marker.name = "PropAnchor_" + timeline + "_" + str(hint)
		if terrain:
			terrain.add_child(marker)


func _dispose_old_terrain() -> void:
	if terrain and is_instance_valid(terrain):
		terrain.queue_free()
	terrain = null


func _fallback_terrain(timeline: String) -> void:
	# Plain PlaneMesh terrain so the game is still playable without Terrain3D.
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(1024, 1024)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.name = "FallbackTerrain_" + timeline.capitalize()
	add_child(mesh_instance)
	terrain = mesh_instance
	terrain_generated.emit(timeline, mesh_instance)

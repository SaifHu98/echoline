extends Node3D

# ECHO//LINE — Terrain3D World Generator
# Uses Terrain3D for AAA-quality landscape per timeline.
# Install: AssetStore → Search "Terrain3D" by Tokisan Games

const TERRAIN_3D_PATH := "res://addons/terrain_3d/terrain_3d.gd"

var terrain: Node3D = null
var current_timeline: String = ""

# Texture assets per timeline (set after installing Terrain3D)
const PAST_TEXTURES := {
	"grass": "res://textures/timeline_past/grass_albedo.webp",
	"rock": "res://textures/timeline_past/rock_albedo.webp",
	"dirt": "res://textures/timeline_past/dirt_albedo.webp"
}

const PRESENT_TEXTURES := {
	"pavement": "res://textures/timeline_present/pavement_albedo.webp",
	"brick": "res://textures/timeline_present/brick_albedo.webp",
	"metal": "res://textures/timeline_present/metal_albedo.webp"
}

const FUTURE_TEXTURES := {
	"crystal": "res://textures/timeline_future/crystal_albedo.webp",
	"energy": "res://textures/timeline_future/energy_albedo.webp",
	"hologram": "res://textures/timeline_future/hologram_albedo.webp"
}


func _ready() -> void:
	# Check if Terrain3D is available
	if ResourceLoader.exists(TERRAIN_3D_PATH):
		print("[TerrainWorldGenerator] Terrain3D available")
	else:
		push_warning("[TerrainWorldGenerator] Terrain3D not installed — using basic terrain")


func generate_world_for_timeline(timeline: String) -> void:
	current_timeline = timeline
	match timeline:
		"past":
			_generate_past_world()
		"present":
			_generate_present_world()
		"future":
			_generate_future_world()


func _generate_past_world() -> void:
	# Ancient rolling hills, weathered stone, gardens
	_setup_terrain({
		"size": Vector2(1024, 1024),
		"height_range": Vector2(-50, 200),
		"noise_scale": 0.025,
		"textures": PAST_TEXTURES,
		"vegetation_density": 0.6,
		"weather": "foggy_sunrise"
	})
	_place_ancient_props()


func _generate_present_world() -> void:
	# Modern city, paved streets, brick buildings
	_setup_terrain({
		"size": Vector2(1024, 1024),
		"height_range": Vector2(-20, 50),
		"noise_scale": 0.015,
		"textures": PRESENT_TEXTURES,
		"vegetation_density": 0.2,
		"weather": "clear"
	})
	_place_modern_props()


func _generate_future_world() -> void:
	# Crystalline formations, energy fields, holographic structures
	_setup_terrain({
		"size": Vector2(1024, 1024),
		"height_range": Vector2(-100, 300),
		"noise_scale": 0.04,
		"textures": FUTURE_TEXTURES,
		"vegetation_density": 0.1,
		"weather": "energetic_dusk"
	})
	_place_future_props()


func _setup_terrain(config: Dictionary) -> void:
	if not ResourceLoader.exists(TERRAIN_3D_PATH):
		_fallback_terrain(config)
		return

	# Instantiate Terrain3D node
	var t3d_class = load(TERRAIN_3D_PATH)
	if t3d_class:
		terrain = t3d_class.new()
		terrain.region_size = config.size
		terrain.height_range = config.height_range
		add_child(terrain)
		# Texture setup would happen here via Terrain3D API
		_apply_textures(config.textures)
		_apply_weather(config.weather)


func _apply_textures(textures: Dictionary) -> void:
	# Apply textures based on timeline
	for type in textures:
		var path = textures[type]
		if ResourceLoader.exists(path):
			# terrain.set_texture(type, load(path))
			pass


func _apply_weather(weather: String) -> void:
	# Set sky/weather
	# terrain.set_weather(weather)
	pass


func _fallback_terrain(config: Dictionary) -> void:
	# Fall back to PlaneMesh terrain
	pass


# === Props per timeline ===

func _place_ancient_props() -> void:
	# Place: stone arches, fountains, lanterns, gardens
	# Uses AssetStore 3D models or generated CSG
	pass


func _place_modern_props() -> void:
	# Place: clockwork gears, brick walls, neon signs
	pass


func _place_future_props() -> void:
	# Place: crystals, holographic panels, energy pylons
	pass


# === Roads (Road Generator Integration) ===

const ROAD_GENERATOR_PATH := "res://addons/road_generator/road_generator.gd"

func _place_roads(timeline: String) -> void:
	if not ResourceLoader.exists(ROAD_GENERATOR_PATH):
		return
	# Use Road Generator to create streets
	match timeline:
		"present":
			# _generate_modern_streets()
			pass
		"past":
			# _generate_dirt_paths()
			pass
		"future":
			# _generate_energy_corridors()
			pass

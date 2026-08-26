class_name MapLayoutGenerator
extends RefCounted

# ECHO//LINE — Map Layout Generator
# Produces a deterministic map layout given:
#   - timeline (past / present / future)
#   - difficulty
#   - player_count
#   - seed (from SeededRNG)
#
# The layout specifies:
#   - scene_id: which base scene to load (from a small pool per timeline)
#   - spawn_points: Vector3 positions for each player (1-4)
#   - anchor_locations: Vector3 positions where Memory Shards / Anchors can be placed
#   - hazard_zones: Array of {position, radius, type} for enemy spawns / traps
#   - shard_pickups: Vector3 positions for collectible shards
#   - patrol_paths: Array of arrays of Vector3 (for LimboAI behavior trees later)
#   - lighting: sky parameters + ambient color
#
# Layouts are deterministic but feel handcrafted: the generator picks a
# "theme" (e.g., "open courtyard", "tight corridor", "vertical climb") then
# places elements using poisson-disc-like spacing.

const TIMELINE_SCENE_POOL := {
	"past": [
		"res://scenes/timelines/past/courtyard_open.tscn",
		"res://scenes/timelines/past/courtyard_corridor.tscn",
		"res://scenes/timelines/past/archive_wing.tscn",
		"res://scenes/timelines/past/garden_climb.tscn",
		"res://scenes/timelines/past/hollow_throne_room.tscn",
		"res://scenes/timelines/past/river_bank.tscn",
	],
	"present": [
		"res://scenes/timelines/present/clock_shop_open.tscn",
		"res://scenes/timelines/present/clock_shop_corridor.tscn",
		"res://scenes/timelines/present/tower_office.tscn",
		"res://scenes/timelines/present/midnight_alley.tscn",
		"res://scenes/timelines/present/factory_floor.tscn",
		"res://scenes/timelines/present/radio_studio.tscn",
	],
	"future": [
		"res://scenes/timelines/future/crystal_lab_open.tscn",
		"res://scenes/timelines/future/crystal_lab_corridor.tscn",
		"res://scenes/timelines/future/omega_chamber.tscn",
		"res://scenes/timelines/future/holographic_archive.tscn",
		"res://scenes/timelines/future/grid_maintenance.tscn",
		"res://scenes/timelines/future/satellite_array.tscn",
	],
}

const TIMELINE_LIGHTING := {
	"past": {
		"ambient_color": Color(0.85, 0.75, 0.55, 1.0),
		"ambient_energy": 0.6,
		"fog_color": Color(0.7, 0.65, 0.55, 1.0),
		"fog_density": 0.012,
		"sky_preset": "foggy_sunrise",
	},
	"present": {
		"ambient_color": Color(0.55, 0.65, 0.80, 1.0),
		"ambient_energy": 0.75,
		"fog_color": Color(0.4, 0.45, 0.55, 1.0),
		"fog_density": 0.006,
		"sky_preset": "clear",
	},
	"future": {
		"ambient_color": Color(0.30, 0.45, 0.75, 1.0),
		"ambient_energy": 0.55,
		"fog_color": Color(0.20, 0.30, 0.50, 1.0),
		"fog_density": 0.018,
		"sky_preset": "energetic_dusk",
	},
}

const LAYOUT_THEMES := {
	"open": {
		"world_size": Vector2(120.0, 120.0),
		"spawn_radius": 35.0,
		"anchor_count_range": [4, 6],
		"hazard_count_range": [3, 5],
		"shard_count_range": [12, 20],
	},
	"corridor": {
		"world_size": Vector2(160.0, 60.0),
		"spawn_radius": 50.0,
		"anchor_count_range": [3, 5],
		"hazard_count_range": [4, 7],
		"shard_count_range": [15, 25],
	},
	"vertical": {
		"world_size": Vector2(80.0, 80.0),
		"spawn_radius": 25.0,
		"anchor_count_range": [3, 4],
		"hazard_count_range": [5, 8],
		"shard_count_range": [10, 18],
	},
	"arena": {
		"world_size": Vector2(100.0, 100.0),
		"spawn_radius": 40.0,
		"anchor_count_range": [2, 3],
		"hazard_count_range": [6, 10],
		"shard_count_range": [8, 14],
	},
}

const TIMELINE_FLAVOR := {
	"past": {
		"enemies": ["stone guardians", "hollow knights", "memory wraiths"],
	},
	"present": {
		"enemies": ["rogue mechanics", "temporal smugglers", "neon wraiths"],
	},
	"future": {
		"enemies": ["rift echoes", "crystal wraiths", "timeline parasites"],
	},
}

var _rng = null
var _timeline: String = "present"
var _difficulty: int = 1
var _player_count: int = 2


func _init(rng, timeline: String, difficulty: int,
		player_count: int) -> void:
	_rng = rng
	_timeline = timeline
	_difficulty = clamp(difficulty, 1, 5)
	_player_count = clamp(player_count, 1, 4)


func generate() -> Dictionary:
	var theme_name: String = _rng.pick(LAYOUT_THEMES.keys())
	var theme: Dictionary = LAYOUT_THEMES[theme_name]
	var world_size: Vector2 = theme["world_size"]
	var center: Vector2 = Vector2.ZERO
	# Pick a base scene from the timeline pool.
	var pool: Array = TIMELINE_SCENE_POOL.get(_timeline, [])
	var scene_id: String = ""
	if pool.size() > 0:
		scene_id = _rng.pick(pool)
	# Generate spawn points distributed around the center.
	var spawn_points: Array = []
	for i in range(_player_count):
		var angle: float = TAU * float(i) / float(_player_count)
		var radius: float = theme["spawn_radius"] * (0.7 + _rng.rand_float(0, 0.3))
		var pos: Vector3 = Vector3(
			center.x + cos(angle) * radius,
			0.0,
			center.y + sin(angle) * radius
		)
		spawn_points.append({
			"player_index": i,
			"position": pos,
			"facing_angle": angle + PI,  # face inward
		})
	# Generate anchor locations using poisson-disc-like spacing.
	var anchor_count: int = _rng.rand_int(theme["anchor_count_range"][0],
		theme["anchor_count_range"][1])
	var anchor_locations: Array = _scatter_points(center, world_size * 0.4, anchor_count, 8.0)
	# Hazards scale with difficulty.
	var hazard_count: int = _rng.rand_int(theme["hazard_count_range"][0],
		theme["hazard_count_range"][1]) + int(_difficulty * 0.5)
	var hazard_zones: Array = []
	var hazard_types: Array = TIMELINE_FLAVOR[_timeline]["enemies"] if TIMELINE_FLAVOR.has(_timeline) else ["enemies"]
	for i in range(hazard_count):
		var pos2d: Vector2 = _rng.rand_position_in_box(center, world_size * 0.7)
		hazard_zones.append({
			"position": Vector3(pos2d.x, 0.0, pos2d.y),
			"radius": _rng.rand_float(4.0, 9.0),
			"type": _rng.pick(hazard_types),
			"spawn_count": _rng.rand_int(1, 1 + _difficulty),
		})
	# Shard pickups scale with difficulty × player_count.
	var shard_count: int = _rng.rand_int(theme["shard_count_range"][0],
		theme["shard_count_range"][1]) + _difficulty + _player_count
	var shard_pickups: Array = _scatter_points(center, world_size * 0.45, shard_count, 4.0)
	# Build a patrol path per hazard zone (for LimboAI).
	var patrol_paths: Array = []
	for hazard in hazard_zones:
		var waypoints: Array = []
		var waypoint_count: int = _rng.rand_int(3, 6)
		for j in range(waypoint_count):
			var offset: Vector3 = Vector3(
				_rng.rand_float(-hazard.radius, hazard.radius),
				0.0,
				_rng.rand_float(-hazard.radius, hazard.radius)
			)
			waypoints.append(hazard.position + offset)
		patrol_paths.append({
			"hazard_type": hazard.type,
			"waypoints": waypoints,
		})
	# Lighting.
	var lighting: Dictionary = TIMELINE_LIGHTING.get(_timeline, TIMELINE_LIGHTING["present"]).duplicate()
	# Random time of day shifts the mood slightly.
	var time_of_day: float = _rng.rand_float(0.0, 1.0)
	return {
		"theme": theme_name,
		"scene_id": scene_id,
		"world_size": world_size,
		"center": center,
		"spawn_points": spawn_points,
		"anchor_locations": anchor_locations,
		"hazard_zones": hazard_zones,
		"shard_pickups": shard_pickups,
		"patrol_paths": patrol_paths,
		"lighting": lighting,
		"time_of_day": time_of_day,
		"difficulty": _difficulty,
		"player_count": _player_count,
	}


func _scatter_points(center: Vector2, area_size: Vector2, count: int,
		min_distance: float) -> Array:
	var points: Array = []
	var attempts: int = 0
	var max_attempts: int = count * 16
	while points.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate: Vector2 = _rng.rand_position_in_box(center, area_size)
		var ok: bool = true
		for p in points:
			var existing: Vector2 = Vector2(p.x, p.z)
			if candidate.distance_to(existing) < min_distance:
				ok = false
				break
		if ok:
			points.append(Vector3(candidate.x, 0.0, candidate.y))
	return points

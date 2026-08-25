class_name EnvironmentBuilder
extends Node3D

# ECHO//LINE — Environment Builder
# Creates detailed multi-layered 3D world with foliage, rocks, paths

@export var current_timeline: String = "past"
@export var tile_size: float = 5.0

var spawned_props: Array[Node3D] = []


func _ready() -> void:
	_build_world()


func _build_world() -> void:
	_build_ground()
	_build_paths()
	_build_foliage()
	_build_rocks()
	_build_structures()
	_build_atmosphere()


func _build_ground() -> void:
	# Main ground with tile pattern
	var ground = CSGBox3D.new()
	ground.size = Vector3(60, 0.5, 60)
	ground.position = Vector3(0, -0.25, 0)
	var mat = _make_ground_material()
	ground.material = mat
	add_child(ground)

	# Decorative tile borders
	for x in range(-3, 4):
		for z in range(-3, 4):
			if (x + z) % 2 == 0:
				continue
			var tile = CSGBox3D.new()
			tile.size = Vector3(tile_size - 0.2, 0.55, tile_size - 0.2)
			tile.position = Vector3(x * tile_size, 0.025, z * tile_size)
			var tile_mat = StandardMaterial3D.new()
			match current_timeline:
				"past": tile_mat.albedo_color = Color(0.45, 0.35, 0.2)
				"present": tile_mat.albedo_color = Color(0.35, 0.4, 0.45)
				"future": tile_mat.albedo_color = Color(0.2, 0.15, 0.35)
			tile_mat.roughness = 0.85
			tile.material = tile_mat
			add_child(tile)


func _build_paths() -> void:
	# Stone path from origin to key locations
	var path_points = [
		Vector3(0, 0.02, 0),
		Vector3(0, 0.02, -8),
		Vector3(-5, 0.02, -8),
		Vector3(5, 0.02, -5),
		Vector3(0, 0.02, 8),
	]

	for i in range(path_points.size() - 1):
		var from = path_points[i]
		var to = path_points[i + 1]
		var segment = _make_path_segment(from, to)
		add_child(segment)


func _make_path_segment(from: Vector3, to: Vector3) -> CSGBox3D:
	var segment = CSGBox3D.new()
	var dir = to - from
	var length = dir.length()
	segment.size = Vector3(1.5, 0.06, length)
	segment.position = (from + to) / 2.0
	segment.position.y = 0.02
	segment.look_at(to + Vector3(0, 0.02, 0), Vector3.UP)
	segment.rotate_object_local(Vector3.RIGHT, PI / 2)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.4)
	mat.roughness = 0.7
	segment.material = mat
	return segment


func _build_foliage() -> void:
	# Trees scattered
	for i in range(12):
		var tree_pos = _random_ground_position(8, 25)
		var tree = _make_tree()
		tree.position = tree_pos
		add_child(tree)
		spawned_props.append(tree)

	# Bushes
	for i in range(20):
		var bush_pos = _random_ground_position(3, 15)
		var bush = _make_bush()
		bush.position = bush_pos
		add_child(bush)
		spawned_props.append(bush)

	# Flowers
	for i in range(30):
		var flower_pos = _random_ground_position(2, 20)
		var flower = _make_flower()
		flower.position = flower_pos
		add_child(flower)
		spawned_props.append(flower)


func _build_rocks() -> void:
	for i in range(15):
		var rock_pos = _random_ground_position(5, 25)
		var rock = _make_rock(randf() * 0.5 + 0.3)
		rock.position = rock_pos
		add_child(rock)
		spawned_props.append(rock)


func _build_structures() -> void:
	# Central clocktower (large landmark)
	var tower = _make_clocktower()
	tower.position = Vector3(0, 0, -12)
	add_child(tower)

	# Fountain near origin
	var fountain = _make_fountain()
	fountain.position = Vector3(6, 0, 3)
	add_child(fountain)

	# Arch (transition marker)
	var arch = _make_arch()
	arch.position = Vector3(-6, 0, 3)
	add_child(arch)


func _build_atmosphere() -> void:
	# Floating particles for ambiance
	var particles = GPUParticles3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.03
	particles.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	match current_timeline:
		"past": mat.emission = Color(1, 0.84, 0.4)
		"present": mat.emission = Color(0, 0.95, 1)
		"future": mat.emission = Color(1, 0.5, 0.95)
	mat.emission_energy_multiplier = 2.0
	particles.material_override = mat

	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(25, 3, 25)
	process.direction = Vector3(0, 1, 0)
	process.spread = 30.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.6
	process.gravity = Vector3(0, -0.1, 0)
	process.scale_min = 0.5
	process.scale_max = 1.5
	particles.process_material = process
	particles.amount = 80
	particles.lifetime = 8.0
	particles.position = Vector3(0, 3, 0)
	add_child(particles)


# === Helpers ===
func _make_ground_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	match current_timeline:
		"past":
			mat.albedo_color = Color(0.35, 0.28, 0.18)
		"present":
			mat.albedo_color = Color(0.3, 0.35, 0.4)
		"future":
			mat.albedo_color = Color(0.18, 0.12, 0.28)
	mat.roughness = 0.9
	return mat


func _random_ground_position(min_dist: float, max_dist: float) -> Vector3:
	var angle = randf() * TAU
	var dist = randf_range(min_dist, max_dist)
	return Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _make_tree() -> Node3D:
	var tree = Node3D.new()

	# Trunk
	var trunk = CSGCylinder3D.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.3
	trunk.height = 1.5 + randf() * 0.8
	trunk.position = Vector3(0, trunk.height / 2.0, 0)
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.25, 0.18, 0.1)
	trunk_mat.roughness = 0.95
	trunk.material = trunk_mat
	tree.add_child(trunk)

	# Canopy
	var canopy_size = 1.0 + randf() * 0.5
	var canopy = CSGSphere3D.new()
	canopy.radius = canopy_size
	canopy.position = Vector3(0, trunk.height + canopy_size * 0.7, 0)
	var canopy_mat = StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.15 + randf() * 0.1, 0.35 + randf() * 0.2, 0.15)
	canopy_mat.roughness = 0.8
	canopy.material = canopy_mat
	tree.add_child(canopy)

	return tree


func _make_bush() -> Node3D:
	var bush = Node3D.new()
	for i in range(randi_range(2, 4)):
		var sphere = CSGSphere3D.new()
		sphere.radius = 0.3 + randf() * 0.2
		sphere.position = Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.4 + randf() * 0.2, 0.15)
		mat.roughness = 0.85
		sphere.material = mat
		bush.add_child(sphere)
	return bush


func _make_flower() -> Node3D:
	var flower = Node3D.new()
	var stem = CSGCylinder3D.new()
	stem.top_radius = 0.02
	stem.bottom_radius = 0.03
	stem.height = 0.3
	stem.position = Vector3(0, 0.15, 0)
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.2, 0.5, 0.2)
	stem.material = stem_mat
	flower.add_child(stem)

	var petals = CSGSphere3D.new()
	petals.radius = 0.08
	petals.position = Vector3(0, 0.32, 0)
	var petal_mat = StandardMaterial3D.new()
	# Random bright color
	var colors = [Color(1, 0.3, 0.4), Color(1, 0.8, 0.2), Color(0.7, 0.3, 1), Color(1, 1, 0.3)]
	petal_mat.albedo_color = colors[randi() % colors.size()]
	petal_mat.emission_enabled = true
	petal_mat.emission = petal_mat.albedo_color
	petal_mat.emission_energy_multiplier = 0.3
	petals.material = petal_mat
	flower.add_child(petals)
	return flower


func _make_rock(scale: float) -> Node3D:
	var rock = Node3D.new()
	var shape = CSGSphere3D.new()
	shape.radius = scale
	shape.scale = Vector3(1.2 + randf() * 0.4, 0.7, 0.9 + randf() * 0.3)
	shape.position = Vector3(0, scale * 0.3, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.35)
	mat.roughness = 0.95
	shape.material = mat
	rock.add_child(shape)
	return rock


func _make_clocktower() -> Node3D:
	var tower = Node3D.new()

	# Base
	var base = CSGBox3D.new()
	base.size = Vector3(4, 8, 4)
	base.position = Vector3(0, 4, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.35)
	mat.roughness = 0.85
	base.material = mat
	tower.add_child(base)

	# Top section
	var top = CSGBox3D.new()
	top.size = Vector3(3, 2, 3)
	top.position = Vector3(0, 9, 0)
	top.material = mat
	tower.add_child(top)

	# Roof (pyramid via cone)
	var roof = CSGCylinder3D.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 2.5
	roof.height = 2.5
	roof.position = Vector3(0, 11.25, 0)
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.4, 0.2, 0.15)
	roof.material = roof_mat
	tower.add_child(roof)

	# Clock face
	var clock = CSGCylinder3D.new()
	clock.top_radius = 0.8
	clock.bottom_radius = 0.8
	clock.height = 0.1
	clock.position = Vector3(2.05, 9, 0)
	clock.rotation_degrees = Vector3(0, 0, 90)
	var clock_mat = StandardMaterial3D.new()
	clock_mat.albedo_color = Color(0.9, 0.85, 0.7)
	clock_mat.emission_enabled = true
	clock_mat.emission = Color(1, 0.95, 0.7)
	clock_mat.emission_energy_multiplier = 0.5
	clock.material = clock_mat
	tower.add_child(clock)

	# Clock hands
	var hour = CSGBox3D.new()
	hour.size = Vector3(0.05, 0.4, 0.05)
	hour.position = Vector3(2.1, 9, 0)
	hour.material = clock_mat
	tower.add_child(hour)

	var minute = CSGBox3D.new()
	minute.size = Vector3(0.05, 0.6, 0.05)
	minute.position = Vector3(2.1, 9, 0)
	minute.rotation_degrees = Vector3(0, 0, 45)
	minute.material = clock_mat
	tower.add_child(minute)

	return tower


func _make_fountain() -> Node3D:
	var fountain = Node3D.new()

	# Basin
	var basin = CSGCylinder3D.new()
	basin.top_radius = 1.2
	basin.bottom_radius = 1.2
	basin.height = 0.4
	basin.position = Vector3(0, 0.2, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.45)
	mat.metallic = 0.3
	basin.material = mat
	fountain.add_child(basin)

	# Center pillar
	var pillar = CSGCylinder3D.new()
	pillar.top_radius = 0.2
	pillar.bottom_radius = 0.25
	pillar.height = 1.2
	pillar.position = Vector3(0, 1.0, 0)
	pillar.material = mat
	fountain.add_child(pillar)

	# Water glow at top
	var water = CSGSphere3D.new()
	water.radius = 0.3
	water.position = Vector3(0, 1.7, 0)
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.4, 0.7, 0.95, 0.7)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.3, 0.7, 1.0)
	water_mat.emission_energy_multiplier = 1.5
	water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.material = water_mat
	fountain.add_child(water)

	return fountain


func _make_arch() -> Node3D:
	var arch = Node3D.new()

	# Left pillar
	var left = CSGBox3D.new()
	left.size = Vector3(0.5, 3, 0.5)
	left.position = Vector3(-1, 1.5, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.55, 0.5)
	left.material = mat
	arch.add_child(left)

	# Right pillar
	var right = CSGBox3D.new()
	right.size = Vector3(0.5, 3, 0.5)
	right.position = Vector3(1, 1.5, 0)
	right.material = mat
	arch.add_child(right)

	# Top arch (half torus via rotated cylinder)
	var top = CSGCylinder3D.new()
	top.top_radius = 0.25
	top.bottom_radius = 0.25
	top.height = 2.5
	top.position = Vector3(0, 3, 0)
	top.rotation_degrees = Vector3(0, 0, 90)
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.6, 0.55, 0.5)
	top.material = top_mat
	arch.add_child(top)

	return arch

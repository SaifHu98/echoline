class_name WorldGenerator
extends Node3D

# ECHO//LINE — Procedural World Generator
# Creates AAA-quality terrain with natural elevation, biomes, and details

@export var world_size: float = 80.0
@export var height_scale: float = 3.5
@export var noise_scale: float = 0.05
@export var tree_density: float = 0.7
@export var grass_density: float = 1.5
@export var current_timeline: String = "past"

var noise: FastNoiseLite
var height_map: Dictionary = {}
var spawned_objects: Array[Node3D] = []
var water_planes: Array[MeshInstance3D] = []


func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = noise_scale
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5


func generate_world() -> void:
	_clear_world()
	_generate_terrain()
	_generate_water_features()
	_generate_vegetation()
	_generate_structures()
	_generate_details()
	_generate_lighting_decoration()
	_apply_timeline_atmosphere()


func _clear_world() -> void:
	for child in get_children():
		child.queue_free()
	spawned_objects.clear()
	water_planes.clear()


# === TERRAIN ===
func _generate_terrain() -> void:
	# Base ground plane with height variations
	var ground = CSGBox3D.new()
	ground.size = Vector3(world_size, 0.5, world_size)
	ground.position = Vector3(0, -0.25, 0)
	var mat = _get_ground_material()
	ground.material = mat
	add_child(ground)

	# Add elevation bumps/hills
	for i in range(30):
		var bump = CSGSphere3D.new()
		var pos = _random_world_position(8, world_size / 2 - 5)
		var height = _get_height_at(pos.x, pos.z) * height_scale
		bump.radius = 1.5 + randf() * 3.0
		bump.position = Vector3(pos.x, height - 0.5, pos.z)
		bump.scale = Vector3(1, 0.3 + randf() * 0.4, 1)  # Flatten
		var bump_mat = StandardMaterial3D.new()
		bump_mat.albedo_color = mat.albedo_color.darkened(0.1)
		bump_mat.roughness = 0.9
		bump.material = bump_mat
		add_child(bump)

	# Tiled ground patches
	for x in range(-6, 7):
		for z in range(-6, 7):
			if randf() > 0.3:
				continue
			var tile = CSGBox3D.new()
			var tile_pos = Vector3(x * 6, 0.01, z * 6)
			tile.size = Vector3(5.5, 0.06, 5.5)
			tile.position = tile_pos
			var tile_mat = StandardMaterial3D.new()
			match current_timeline:
				"past":
					tile_mat.albedo_color = Color(0.45, 0.35, 0.22)
				"present":
					tile_mat.albedo_color = Color(0.35, 0.4, 0.45)
				"future":
					tile_mat.albedo_color = Color(0.2, 0.15, 0.35)
			tile_mat.roughness = 0.85
			tile.material = tile_mat
			add_child(tile)


func _get_height_at(x: float, z: float) -> float:
	var n1 = noise.get_noise_2d(x, z)
	var n2 = noise.get_noise_2d(x * 2.5, z * 2.5) * 0.5
	return (n1 + n2) * 0.5 + 0.5


# === WATER FEATURES ===
func _generate_water_features() -> void:
	# Main river/lake
	var river_points = []
	for i in range(20):
		var t = float(i) / 20.0
		var x = -world_size / 2 + t * world_size
		var z = sin(t * TAU * 2) * 5 + (noise.get_noise_2d(t * 5, 0) * 3)
		river_points.append(Vector3(x, -0.4, z))

	for i in range(river_points.size() - 1):
		var from = river_points[i]
		var to = river_points[i + 1]
		var water = _make_water_segment(from, to)
		add_child(water)

	# Small ponds
	for i in range(5):
		var pos = _random_world_position(8, world_size / 2 - 10)
		var pond = _make_pond(pos, 1.5 + randf() * 1.5)
		add_child(pond)


func _make_water_segment(from: Vector3, to: Vector3) -> MeshInstance3D:
	var water = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	var length = (to - from).length()
	plane.size = Vector2(length + 0.5, 4.0)
	water.mesh = plane
	water.position = (from + to) / 2.0
	water.look_at_from_position(water.position, to, Vector3.UP)
	water.rotate_object_local(Vector3.RIGHT, PI / 2)
	water.position.y = -0.45

	var mat = _get_water_material()
	water.material_override = mat
	water_planes.append(water)
	return water


func _make_pond(center: Vector3, radius: float) -> MeshInstance3D:
	var water = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(radius * 2, radius * 2)
	water.mesh = plane
	water.position = Vector3(center.x, -0.45, center.z)

	var mat = _get_water_material()
	water.material_override = mat
	water_planes.append(water)
	return water


# === VEGETATION ===
func _generate_vegetation() -> void:
	# Trees - dense in some areas, sparse in others
	var tree_clusters = []
	for i in range(8):
		tree_clusters.append(_random_world_position(5, world_size / 2 - 10))

	for cluster_center in tree_clusters:
		var trees_in_cluster = int(3 + randf() * 5 * tree_density)
		for i in range(trees_in_cluster):
			var offset = Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
			var pos = cluster_center + offset
			pos.y = _get_height_at(pos.x, pos.z) * height_scale
			var tree = _make_detailed_tree()
			tree.position = pos
			add_child(tree)
			spawned_objects.append(tree)

	# Grass patches (instanced visual)
	for i in range(int(60 * grass_density)):
		var pos = _random_world_position(2, world_size / 2 - 3)
		pos.y = _get_height_at(pos.x, pos.z) * height_scale
		var grass = _make_grass_patch(pos)
		add_child(grass)
		spawned_objects.append(grass)

	# Bushes
	for i in range(25):
		var pos = _random_world_position(2, world_size / 2 - 3)
		pos.y = _get_height_at(pos.x, pos.z) * height_scale
		var bush = _make_bush(pos)
		add_child(bush)
		spawned_objects.append(bush)

	# Flowers
	for i in range(50):
		var pos = _random_world_position(2, world_size / 2 - 3)
		pos.y = _get_height_at(pos.x, pos.z) * height_scale
		var flower = _make_flower(pos)
		add_child(flower)
		spawned_objects.append(flower)


func _make_detailed_tree() -> Node3D:
	var tree = Node3D.new()

	# Trunk - curved via multiple segments
	var trunk_height = 2.0 + randf() * 1.5
	var trunk_segments = 4
	for i in range(trunk_segments):
		var seg = CSGCylinder3D.new()
		var seg_height = trunk_height / trunk_segments
		var radius_top = 0.18 - (i * 0.02)
		var radius_bot = 0.22 - (i * 0.02)
		seg.radius = radius_bot
		seg.height = seg_height
		seg.position = Vector3(sin(i * 0.5) * 0.05, (i + 0.5) * seg_height, cos(i * 0.3) * 0.05)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.2, 0.12)
		mat.roughness = 0.95
		seg.material = mat
		tree.add_child(seg)

	# Canopy - multiple overlapping spheres
	var canopy_base_y = trunk_height + 0.3
	var num_canopy = 4 + randi() % 3
	for i in range(num_canopy):
		var leaf = CSGSphere3D.new()
		var size = 0.7 + randf() * 0.5
		leaf.radius = size
		var angle = float(i) / num_canopy * TAU
		leaf.position = Vector3(cos(angle) * 0.6, canopy_base_y + randf() * 0.5, sin(angle) * 0.6)
		var leaf_mat = StandardMaterial3D.new()
		# Slight color variation
		var base_color = Color(0.15 + randf() * 0.1, 0.35 + randf() * 0.2, 0.15)
		leaf_mat.albedo_color = base_color
		leaf_mat.roughness = 0.85
		leaf.material = leaf_mat
		tree.add_child(leaf)

	# Top canopy
	var top = CSGSphere3D.new()
	top.radius = 0.6 + randf() * 0.3
	top.position = Vector3(0, canopy_base_y + 0.7, 0)
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.2, 0.5, 0.2)
	top_mat.roughness = 0.85
	top.material = top_mat
	tree.add_child(top)

	return tree


func _make_grass_patch(pos: Vector3) -> Node3D:
	var patch = Node3D.new()
	patch.position = pos
	# Cluster of grass blades
	for i in range(randi_range(3, 7)):
		var blade = CSGCylinder3D.new()
		blade.radius = 0.015
		blade.cone = true
		blade.height = 0.15 + randf() * 0.1
		blade.position = Vector3(randf_range(-0.3, 0.3), blade.height / 2.0, randf_range(-0.3, 0.3))
		blade.rotation_degrees = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		var mat = StandardMaterial3D.new()
		var color_var = randf()
		if color_var < 0.6:
			mat.albedo_color = Color(0.3, 0.55, 0.2)
		elif color_var < 0.85:
			mat.albedo_color = Color(0.4, 0.6, 0.25)
		else:
			mat.albedo_color = Color(0.5, 0.65, 0.3)
		blade.material = mat
		patch.add_child(blade)
	return patch


func _make_bush(pos: Vector3) -> Node3D:
	var bush = Node3D.new()
	bush.position = pos
	for i in range(randi_range(3, 5)):
		var sphere = CSGSphere3D.new()
		sphere.radius = 0.3 + randf() * 0.2
		sphere.position = Vector3(randf_range(-0.3, 0.3), sphere.radius * 0.7, randf_range(-0.3, 0.3))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.45 + randf() * 0.15, 0.15)
		mat.roughness = 0.85
		sphere.material = mat
		bush.add_child(sphere)
	return bush


func _make_flower(pos: Vector3) -> Node3D:
	var flower = Node3D.new()
	flower.position = pos
	var stem = CSGCylinder3D.new()
	stem.radius = 0.02
	stem.height = 0.25
	stem.position = Vector3(0, 0.12, 0)
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.2, 0.5, 0.2)
	stem.material = stem_mat
	flower.add_child(stem)

	var petal = CSGSphere3D.new()
	petal.radius = 0.07
	petal.position = Vector3(0, 0.28, 0)
	var petal_mat = StandardMaterial3D.new()
	var colors = [Color(1, 0.3, 0.4), Color(1, 0.8, 0.2), Color(0.7, 0.3, 1), Color(1, 1, 0.3), Color(1, 0.5, 0.7)]
	petal_mat.albedo_color = colors[randi() % colors.size()]
	petal_mat.emission_enabled = true
	petal_mat.emission = petal_mat.albedo_color
	petal_mat.emission_energy_multiplier = 0.4
	flower.add_child(petal)
	return flower


# === STRUCTURES ===
func _generate_structures() -> void:
	# Central clocktower
	var tower_pos = Vector3(0, _get_height_at(0, -12) * height_scale, -12)
	var tower = _make_grand_clocktower()
	tower.position = tower_pos
	add_child(tower)
	spawned_objects.append(tower)

	# Fountain
	var fountain_pos = Vector3(6, _get_height_at(6, 3) * height_scale, 3)
	var fountain = _make_ornate_fountain()
	fountain.position = fountain_pos
	add_child(fountain)
	spawned_objects.append(fountain)

	# Stone arches
	for i in range(3):
		var arch_pos = Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		arch_pos.y = _get_height_at(arch_pos.x, arch_pos.z) * height_scale
		var arch = _make_arch()
		arch.position = arch_pos
		arch.rotation_degrees = Vector3(0, randf() * 360, 0)
		add_child(arch)
		spawned_objects.append(arch)

	# Decorative pillars
	for i in range(6):
		var pillar_pos = Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))
		pillar_pos.y = _get_height_at(pillar_pos.x, pillar_pos.z) * height_scale
		var pillar = _make_pillar()
		pillar.position = pillar_pos
		add_child(pillar)
		spawned_objects.append(pillar)

	# Lanterns
	for i in range(10):
		var lantern_pos = Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		lantern_pos.y = _get_height_at(lantern_pos.x, lantern_pos.z) * height_scale + 1.5
		var lantern = _make_lantern()
		lantern.position = lantern_pos
		add_child(lantern)
		spawned_objects.append(lantern)


func _make_grand_clocktower() -> Node3D:
	var tower = Node3D.new()

	# Multi-tier base
	var tiers = [
		{"size": Vector3(5, 1.5, 5), "y": 0.75, "color": Color(0.5, 0.45, 0.4)},
		{"size": Vector3(4, 2.5, 4), "y": 2.75, "color": Color(0.55, 0.5, 0.45)},
		{"size": Vector3(3.5, 3, 3.5), "y": 5.5, "color": Color(0.6, 0.55, 0.5)},
		{"size": Vector3(3, 2.5, 3), "y": 8.25, "color": Color(0.55, 0.5, 0.45)},
	]

	for tier in tiers:
		var block = CSGBox3D.new()
		block.size = tier.size
		block.position.y = tier.y
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tier.color
		mat.roughness = 0.85
		block.material = mat
		tower.add_child(block)

	# Clock face
	var clock = CSGCylinder3D.new()
	clock.radius = 1.0
	clock.height = 0.15
	clock.position = Vector3(2.05, 8.25, 0)
	clock.rotation_degrees = Vector3(0, 0, 90)
	var clock_mat = StandardMaterial3D.new()
	clock_mat.albedo_color = Color(0.95, 0.9, 0.75)
	clock_mat.emission_enabled = true
	clock_mat.emission = Color(1, 0.95, 0.7)
	clock_mat.emission_energy_multiplier = 0.7
	clock.material = clock_mat
	tower.add_child(clock)

	# Hour and minute hands
	var hour = CSGBox3D.new()
	hour.size = Vector3(0.06, 0.55, 0.06)
	hour.position = Vector3(2.13, 8.25, 0)
	hour.material = clock_mat
	tower.add_child(hour)

	var minute = CSGBox3D.new()
	minute.size = Vector3(0.06, 0.8, 0.06)
	minute.position = Vector3(2.13, 8.25, 0)
	minute.rotation_degrees = Vector3(0, 0, 45)
	minute.material = clock_mat
	tower.add_child(minute)

	# Roof - cone
	var roof = CSGCylinder3D.new()
	roof.radius = 2.5
	roof.cone = true
	roof.height = 3.0
	roof.position.y = 11.0
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.4, 0.2, 0.15)
	roof_mat.metallic = 0.3
	roof.material = roof_mat
	tower.add_child(roof)

	# Spire
	var spire = CSGCylinder3D.new()
	spire.radius = 0.15
	spire.cone = true
	spire.height = 1.5
	spire.position.y = 13.25
	var spire_mat = StandardMaterial3D.new()
	spire_mat.albedo_color = Color(0.7, 0.6, 0.2)
	spire_mat.metallic = 0.8
	spire_mat.emission_enabled = true
	spire_mat.emission = Color(1, 0.84, 0.3)
	spire_mat.emission_energy_multiplier = 1.0
	spire.material = spire_mat
	tower.add_child(spire)

	return tower


func _make_ornate_fountain() -> Node3D:
	var fountain = Node3D.new()

	# Multiple basins
	for i in range(3):
		var basin = CSGCylinder3D.new()
		var radius = 2.0 - i * 0.5
		basin.radius = radius
		basin.height = 0.4 - i * 0.05
		basin.position.y = 0.2 - i * 0.05
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.5, 0.45)
		mat.metallic = 0.4
		mat.roughness = 0.5
		basin.material = mat
		fountain.add_child(basin)

	# Center pillar
	var pillar = CSGCylinder3D.new()
	pillar.radius = 0.3
	pillar.height = 2.0
	pillar.position.y = 1.4
	var pillar_mat = StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.6, 0.55, 0.5)
	pillar_mat.metallic = 0.5
	pillar.material = pillar_mat
	fountain.add_child(pillar)

	# Glowing water orb
	var orb = CSGSphere3D.new()
	orb.radius = 0.5
	orb.position.y = 2.6
	var orb_mat = StandardMaterial3D.new()
	orb_mat.albedo_color = Color(0.5, 0.8, 1.0, 0.6)
	orb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.4, 0.8, 1.0)
	orb_mat.emission_energy_multiplier = 2.5
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material = orb_mat
	fountain.add_child(orb)

	# Water particles
	var particles = GPUParticles3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.05
	particles.draw_pass_1 = sphere
	var pmat = StandardMaterial3D.new()
	pmat.emission_enabled = true
	pmat.emission = Color(0.5, 0.8, 1.0)
	pmat.emission_energy_multiplier = 3.0
	particles.material_override = pmat
	var proc = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 25.0
	proc.initial_velocity_min = 1.0
	proc.initial_velocity_max = 2.0
	proc.gravity = Vector3(0, -3, 0)
	proc.scale_min = 0.5
	proc.scale_max = 1.0
	particles.process_material = proc
	particles.amount = 30
	particles.lifetime = 2.0
	particles.position.y = 2.6
	fountain.add_child(particles)

	return fountain


func _make_arch() -> Node3D:
	var arch = Node3D.new()

	# Two pillars
	for side in [-1, 1]:
		var pillar = CSGBox3D.new()
		pillar.size = Vector3(0.6, 3.5, 0.6)
		pillar.position = Vector3(side * 1.2, 1.75, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.55, 0.5)
		mat.roughness = 0.8
		pillar.material = mat
		arch.add_child(pillar)

	# Top arch
	var top = CSGBox3D.new()
	top.size = Vector3(2.6, 0.5, 0.6)
	top.position = Vector3(0, 3.75, 0)
	top.rotation_degrees = Vector3(0, 0, 0)
	var top_mat = StandardMaterial3D.new()
	top_mat.albedo_color = Color(0.6, 0.55, 0.5)
	top.material = top_mat
	arch.add_child(top)

	return arch


func _make_pillar() -> Node3D:
	var pillar = Node3D.new()

	# Base
	var base = CSGBox3D.new()
	base.size = Vector3(0.8, 0.3, 0.8)
	base.position.y = 0.15
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.4)
	mat.roughness = 0.85
	base.material = mat
	pillar.add_child(base)

	# Column
	var column = CSGCylinder3D.new()
	column.radius = 0.3
	column.height = 2.5
	column.position.y = 1.55
	var col_mat = StandardMaterial3D.new()
	col_mat.albedo_color = Color(0.65, 0.6, 0.55)
	col_mat.metallic = 0.3
	column.material = col_mat
	pillar.add_child(column)

	# Top
	var top = CSGBox3D.new()
	top.size = Vector3(0.8, 0.3, 0.8)
	top.position.y = 2.95
	top.material = mat
	pillar.add_child(top)

	return pillar


func _make_lantern() -> Node3D:
	var lantern = Node3D.new()

	# Post
	var post = CSGCylinder3D.new()
	post.radius = 0.08
	post.height = 2.5
	post.position.y = -1.25
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.3, 0.25, 0.2)
	post.material = post_mat
	lantern.add_child(post)

	# Lamp housing
	var housing = CSGCylinder3D.new()
	housing.radius = 0.25
	housing.height = 0.5
	housing.position.y = 0.25
	var housing_mat = StandardMaterial3D.new()
	housing_mat.albedo_color = Color(0.4, 0.35, 0.3)
	housing_mat.metallic = 0.6
	housing.material = housing_mat
	lantern.add_child(housing)

	# Glowing core
	var core = CSGSphere3D.new()
	core.radius = 0.18
	core.position.y = 0.25
	var core_mat = StandardMaterial3D.new()
	match current_timeline:
		"past":
			core_mat.emission = Color(1, 0.7, 0.3)
		"present":
			core_mat.emission = Color(0.4, 0.8, 1)
		"future":
			core_mat.emission = Color(1, 0.5, 0.9)
	core_mat.emission_enabled = true
	core_mat.emission_energy_multiplier = 3.0
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.albedo_color = Color(1, 0.9, 0.7, 0.6)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.material = core_mat
	lantern.add_child(core)

	# Point light
	var light = OmniLight3D.new()
	light.light_color = core_mat.emission
	light.light_energy = 1.5
	light.omni_range = 6.0
	light.position.y = 0.25
	lantern.add_child(light)

	return lantern


# === DETAILS ===
func _generate_details() -> void:
	# Rocks
	for i in range(30):
		var pos = _random_world_position(3, world_size / 2 - 3)
		pos.y = _get_height_at(pos.x, pos.z) * height_scale
		var rock = _make_detailed_rock()
		rock.position = pos
		add_child(rock)
		spawned_objects.append(rock)

	# Mushrooms
	for i in range(15):
		var pos = _random_world_position(3, world_size / 2 - 3)
		pos.y = _get_height_at(pos.x, pos.z) * height_scale
		var mushroom = _make_mushroom()
		mushroom.position = pos
		add_child(mushroom)
		spawned_objects.append(mushroom)


func _make_detailed_rock() -> Node3D:
	var rock = Node3D.new()
	var main = CSGSphere3D.new()
	main.radius = 0.3 + randf() * 0.4
	main.scale = Vector3(1.2 + randf() * 0.4, 0.6 + randf() * 0.3, 0.9 + randf() * 0.3)
	main.position.y = main.radius * 0.3
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.38, 0.35)
	mat.roughness = 0.95
	main.material = mat
	rock.add_child(main)

	# Smaller rocks around
	if randf() < 0.5:
		var small = CSGSphere3D.new()
		small.radius = main.radius * 0.4
		small.position = Vector3(randf_range(-0.5, 0.5), small.radius * 0.3, randf_range(-0.5, 0.5))
		small.material = mat
		rock.add_child(small)

	return rock


func _make_mushroom() -> Node3D:
	var mush = Node3D.new()
	var stem = CSGCylinder3D.new()
	stem.radius = 0.06
	stem.height = 0.15
	stem.position.y = 0.075
	var stem_mat = StandardMaterial3D.new()
	stem_mat.albedo_color = Color(0.9, 0.85, 0.75)
	stem.material = stem_mat
	mush.add_child(stem)

	var cap = CSGSphere3D.new()
	cap.radius = 0.12
	cap.scale = Vector3(1, 0.6, 1)
	cap.position.y = 0.2
	var cap_mat = StandardMaterial3D.new()
	var colors = [Color(0.8, 0.2, 0.2), Color(0.6, 0.3, 0.8), Color(0.9, 0.6, 0.2)]
	cap_mat.albedo_color = colors[randi() % colors.size()]
	cap_mat.emission_enabled = true
	cap_mat.emission = cap_mat.albedo_color
	cap_mat.emission_energy_multiplier = 0.5
	cap.material = cap_mat
	mush.add_child(cap)

	return mush


# === ATMOSPHERE ===
func _apply_timeline_atmosphere() -> void:
	match current_timeline:
		"past":
			_warm_golden_atmosphere()
		"present":
			_cool_natural_atmosphere()
		"future":
			_cool_violet_atmosphere()


func _warm_golden_atmosphere() -> void:
	# Warm fog
	var env = get_tree().root.get_viewport().get_camera_3d().environment if get_tree().root.get_viewport().get_camera_3d() else null
	if env:
		env.fog_light_color = Color(1, 0.85, 0.6)
		env.fog_density = 0.005


func _cool_natural_atmosphere() -> void:
	pass


func _cool_violet_atmosphere() -> void:
	pass


# === Helpers ===
func _random_world_position(min_dist: float, max_dist: float) -> Vector3:
	var angle = randf() * TAU
	var dist = randf_range(min_dist, max_dist)
	return Vector3(cos(angle) * dist, 0, sin(angle) * dist)


func _get_ground_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	match current_timeline:
		"past":
			mat.albedo_color = Color(0.32, 0.26, 0.16)
		"present":
			mat.albedo_color = Color(0.28, 0.32, 0.38)
		"future":
			mat.albedo_color = Color(0.16, 0.12, 0.28)
	mat.roughness = 0.92
	return mat


func _get_water_material() -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	match current_timeline:
		"past":
			mat.albedo_color = Color(0.3, 0.5, 0.7, 0.85)
			mat.emission = Color(0.2, 0.4, 0.6)
		"present":
			mat.albedo_color = Color(0.25, 0.55, 0.8, 0.85)
			mat.emission = Color(0.15, 0.45, 0.7)
		"future":
			mat.albedo_color = Color(0.4, 0.3, 0.8, 0.85)
			mat.emission = Color(0.3, 0.2, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.4
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.5
	return mat


func _generate_lighting_decoration() -> void:
	# Stub: decorative lights are added via _generate_structures() (lanterns, etc.)
	# This function is a hook for future lighting decoration (e.g., fairy lights,
	# floating orbs per timeline). Kept as no-op so world_generator can compile.
	pass

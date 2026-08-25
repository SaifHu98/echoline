class_name CharacterFactory
extends Node3D

# ECHO//LINE — Character Factory
# Creates 3 unique characters, one per Timeline
# Each has distinctive visual design, abilities, and effects

enum TimelineCharacter {
	ARCHIVIST_PAST,      # Memory Keeper - amber/gold theme
	ENGINEER_PRESENT,    # Reality Shaper - cyan/blue theme
	ORACLE_FUTURE        # Possibility Weaver - magenta/violet theme
}

var characters: Dictionary = {}


func _ready() -> void:
	_create_archivist()
	_create_engineer()
	_create_oracle()


# === ARCHIVIST (PAST) ===
func _create_archivist() -> void:
	var archivist = Node3D.new()
	archivist.name = "ArchivistPast"

	# Body
	var body = CSGBox3D.new()
	body.size = Vector3(0.6, 1.4, 0.4)
	body.position = Vector3(0, 0.7, 0)
	body.material = _make_material(Color(0.55, 0.42, 0.2), 0.0, Color(0.83, 0.69, 0.22))
	archivist.add_child(body)

	# Head
	var head = CSGSphere3D.new()
	head.radius = 0.25
	head.position = Vector3(0, 1.7, 0)
	head.material = _make_material(Color(0.85, 0.7, 0.55), 0.0, Color(1, 0.9, 0.7))
	archivist.add_child(head)

	# Hood (cone)
	var hood = CSGCylinder3D.new()
	hood.top_radius = 0.0
	hood.bottom_radius = 0.4
	hood.height = 0.7
	hood.position = Vector3(0, 1.95, -0.05)
	hood.material = _make_material(Color(0.35, 0.25, 0.1), 0.5, Color(1, 0.85, 0.3))
	archivist.add_child(hood)

	# Robe flowing
	var robe = CSGCylinder3D.new()
	robe.top_radius = 0.35
	robe.bottom_radius = 0.7
	robe.height = 1.0
	robe.position = Vector3(0, 0.5, 0)
	robe.material = _make_material(Color(0.45, 0.32, 0.15), 0.3, Color(1, 0.84, 0.4))
	archivist.add_child(robe)

	# Scroll in hand (memory)
	var scroll = CSGBox3D.new()
	scroll.size = Vector3(0.1, 0.3, 0.3)
	scroll.position = Vector3(0.4, 1.0, 0.2)
	scroll.rotation_degrees = Vector3(-30, 30, 0)
	scroll.material = _make_material(Color(0.95, 0.85, 0.65), 0.0, Color(1, 0.95, 0.7))
	archivist.add_child(scroll)

	# Lantern (glowing orb)
	var lantern = CSGSphere3D.new()
	lantern.radius = 0.12
	lantern.position = Vector3(-0.4, 1.0, 0.2)
	var lantern_mat = StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(1, 0.85, 0.3)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(1, 0.7, 0.2)
	lantern_mat.emission_energy_multiplier = 2.5
	lantern.material = lantern_mat
	archivist.add_child(lantern)

	# Aura particles
	var aura = _create_aura(Color(1, 0.84, 0.4), 0.6)
	aura.position = Vector3(0, 1.0, 0)
	archivist.add_child(aura)

	characters[TimelineCharacter.ARCHIVIST_PAST] = archivist
	add_child(archivist)
	archivist.visible = false


# === ENGINEER (PRESENT) ===
func _create_engineer() -> void:
	var engineer = Node3D.new()
	engineer.name = "EngineerPresent"

	# Body (sleek uniform)
	var body = CSGBox3D.new()
	body.size = Vector3(0.6, 1.3, 0.4)
	body.position = Vector3(0, 0.7, 0)
	body.material = _make_material(Color(0.15, 0.3, 0.45), 0.5, Color(0, 0.7, 0.9))
	engineer.add_child(body)

	# Head
	var head = CSGSphere3D.new()
	head.radius = 0.24
	head.position = Vector3(0, 1.65, 0)
	head.material = _make_material(Color(0.8, 0.65, 0.55), 0.0, Color(0.9, 0.95, 1))
	engineer.add_child(head)

	# Helmet (visor)
	var helmet = CSGSphere3D.new()
	helmet.radius = 0.28
	helmet.position = Vector3(0, 1.7, 0)
	helmet.material = _make_material(Color(0.2, 0.4, 0.55), 0.7, Color(0, 0.9, 1))
	engineer.add_child(helmet)

	# Visor (glowing strip)
	var visor = CSGBox3D.new()
	visor.size = Vector3(0.45, 0.08, 0.05)
	visor.position = Vector3(0, 1.7, 0.22)
	var visor_mat = StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0, 0.5, 0.7)
	visor_mat.emission_enabled = true
	visor_mat.emission = Color(0, 0.95, 1)
	visor_mat.emission_energy_multiplier = 3.0
	visor.material = visor_mat
	engineer.add_child(visor)

	# Tool belt
	var belt = CSGBox3D.new()
	belt.size = Vector3(0.7, 0.1, 0.45)
	belt.position = Vector3(0, 0.85, 0)
	belt.material = _make_material(Color(0.3, 0.3, 0.35), 0.5, Color(0.5, 0.6, 0.7))
	engineer.add_child(belt)

	# Tool (wrench-like)
	var tool = CSGBox3D.new()
	tool.size = Vector3(0.08, 0.5, 0.08)
	tool.position = Vector3(0.45, 0.7, 0)
	tool.material = _make_material(Color(0.6, 0.6, 0.65), 0.7, Color(0, 0.9, 1))
	engineer.add_child(tool)

	# Backpack (energy core)
	var pack = CSGBox3D.new()
	pack.size = Vector3(0.5, 0.7, 0.25)
	pack.position = Vector3(0, 1.0, -0.32)
	var pack_mat = StandardMaterial3D.new()
	pack_mat.albedo_color = Color(0.2, 0.4, 0.55)
	pack_mat.emission_enabled = true
	pack_mat.emission = Color(0, 0.95, 1)
	pack_mat.emission_energy_multiplier = 1.5
	pack.material = pack_mat
	engineer.add_child(pack)

	# Aura
	var aura = _create_aura(Color(0, 0.95, 1), 0.6)
	aura.position = Vector3(0, 1.0, 0)
	engineer.add_child(aura)

	characters[TimelineCharacter.ENGINEER_PRESENT] = engineer
	add_child(engineer)
	engineer.visible = false


# === ORACLE (FUTURE) ===
func _create_oracle() -> void:
	var oracle = Node3D.new()
	oracle.name = "OracleFuture"

	# Floating body (no legs - hovers)
	var body = CSGSphere3D.new()
	body.radius = 0.4
	body.position = Vector3(0, 1.1, 0)
	body.material = _make_material(Color(0.4, 0.15, 0.5), 0.5, Color(1, 0.5, 0.95))
	oracle.add_child(body)

	# Head (crystalline)
	var head = CSGSphere3D.new()
	head.radius = 0.22
	head.position = Vector3(0, 1.75, 0)
	var head_mat = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.95)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1, 0.5, 0.95)
	head_mat.emission_energy_multiplier = 2.0
	head.material = head_mat
	oracle.add_child(head)

	# Crown (floating rings)
	var crown1 = TorusMesh.new()
	var crown_mesh = MeshInstance3D.new()
	crown_mesh.mesh = crown1
	crown_mesh.position = Vector3(0, 2.05, 0)
	crown_mesh.rotation_degrees = Vector3(90, 0, 0)
	crown_mesh.scale = Vector3(0.4, 0.4, 0.4)
	var crown_mat = StandardMaterial3D.new()
	crown_mat.albedo_color = Color(1, 0.5, 0.95)
	crown_mat.emission_enabled = true
	crown_mat.emission = Color(1, 0.7, 1)
	crown_mat.emission_energy_multiplier = 2.5
	crown_mesh.material_override = crown_mat
	oracle.add_child(crown_mesh)

	# Floating arms (ribbons)
	var arm1 = CSGBox3D.new()
	arm1.size = Vector3(0.1, 1.0, 0.05)
	arm1.position = Vector3(-0.6, 1.1, 0)
	arm1.rotation_degrees = Vector3(0, 0, 30)
	arm1.material = _make_material(Color(0.6, 0.3, 0.7), 0.3, Color(1, 0.6, 0.9))
	oracle.add_child(arm1)

	var arm2 = arm1.duplicate()
	arm2.position = Vector3(0.6, 1.1, 0)
	arm2.rotation_degrees = Vector3(0, 0, -30)
	oracle.add_child(arm2)

	# Floating base (energy disk)
	var disk = CSGCylinder3D.new()
	disk.top_radius = 0.3
	disk.bottom_radius = 0.5
	disk.height = 0.1
	disk.position = Vector3(0, 0.5, 0)
	var disk_mat = StandardMaterial3D.new()
	disk_mat.albedo_color = Color(0.3, 0.1, 0.4)
	disk_mat.emission_enabled = true
	disk_mat.emission = Color(1, 0.4, 0.9)
	disk_mat.emission_energy_multiplier = 1.8
	disk.material = disk_mat
	oracle.add_child(disk)

	# Orbiting particles
	var orbit = _create_orbiting_particles(Color(1, 0.5, 0.95))
	orbit.position = Vector3(0, 1.1, 0)
	oracle.add_child(orbit)

	# Aura
	var aura = _create_aura(Color(1, 0.5, 0.95), 0.7)
	aura.position = Vector3(0, 1.1, 0)
	oracle.add_child(aura)

	characters[TimelineCharacter.ORACLE_FUTURE] = oracle
	add_child(oracle)
	oracle.visible = false


# === Helper functions ===
func _make_material(color: Color, metallic: float, emission: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.5
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 0.6
	return mat


func _create_aura(color: Color, size: float) -> MeshInstance3D:
	var aura = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2
	aura.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.15)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura.material_override = mat
	return aura


func _create_orbiting_particles(color: Color) -> Node3D:
	var container = Node3D.new()
	container.name = "OrbitParticles"
	for i in range(8):
		var p = CSGSphere3D.new()
		p.radius = 0.05
		var angle = i * PI / 4
		p.position = Vector3(cos(angle) * 1.0, sin(i * 0.5) * 0.3, sin(angle) * 1.0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		p.material = mat
		container.add_child(p)
	return container


func get_character(timeline: String) -> Node3D:
	match timeline:
		"past": return characters.get(TimelineCharacter.ARCHIVIST_PAST)
		"present": return characters.get(TimelineCharacter.ENGINEER_PRESENT)
		"future": return characters.get(TimelineCharacter.ORACLE_FUTURE)
	return null


func show_character(timeline: String) -> void:
	for key in characters.keys():
		characters[key].visible = false
	var ch = get_character(timeline)
	if ch:
		ch.visible = true

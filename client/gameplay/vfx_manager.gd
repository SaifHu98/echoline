class_name VFXManager
extends Node3D

# ECHO//LINE — VFX Manager
# Spectacular visual effects: explosions, trails, impacts, beams

var active_effects: Array[Node3D] = []


# === Impact Effects ===
static func spawn_impact(parent: Node3D, position: Vector3, color: Color, scale: float = 1.0) -> void:
	var effect = Node3D.new()
	effect.position = position
	parent.add_child(effect)

	# Expanding ring
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.2 * scale
	torus.outer_radius = 0.4 * scale
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 3.0
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	effect.add_child(ring)

	# Central flash sphere
	var flash = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3 * scale
	flash.mesh = sphere
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1, 1, 1, 0.9)
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.emission_enabled = true
	flash_mat.emission = color
	flash_mat.emission_energy_multiplier = 5.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = flash_mat
	effect.add_child(flash)

	# Particle burst
	var particles = GPUParticles3D.new()
	var psphere = SphereMesh.new()
	psphere.radius = 0.05 * scale
	particles.mesh = psphere
	var pmat = StandardMaterial3D.new()
	pmat.emission_enabled = true
	pmat.emission = color
	pmat.emission_energy_multiplier = 4.0
	particles.material_override = pmat
	var proc = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.2 * scale
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = 3.0 * scale
	proc.initial_velocity_max = 7.0 * scale
	proc.gravity = Vector3(0, -5, 0)
	proc.scale_min = 0.3
	proc.scale_max = 0.8
	proc.color = color
	particles.process_material = proc
	particles.amount = int(40 * scale)
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	effect.add_child(particles)
	particles.emitting = true

	# Light flash
	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 8.0
	light.omni_range = 8.0 * scale
	effect.add_child(light)

	# Animate
	_animate_impact(effect, ring, flash, particles, light, scale)


static func _animate_impact(effect: Node3D, ring: MeshInstance3D, flash: MeshInstance3D, particles: GPUParticles3D, light: OmniLight3D, scale: float) -> void:
	var lifetime = 1.0
	var tween = effect.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 5.0 * scale, lifetime).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(ring.material_override, "albedo_color:a", 0.0, lifetime)
	tween.tween_property(flash, "scale", Vector3.ONE * 3.0 * scale, lifetime * 0.5).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(flash.material_override, "albedo_color:a", 0.0, lifetime * 0.5)
	tween.tween_property(light, "light_energy", 0.0, lifetime * 0.3)
	effect.get_tree().create_timer(lifetime + 0.2).timeout.connect(effect.queue_free)


# === Trail Effects ===
static func create_trail(parent: Node3D, color: Color, width: float = 0.3) -> MeshInstance3D:
	var trail = MeshInstance3D.new()
	var ribbon = RibbonTrailMesh.new()
	ribbon.size = 30
	ribbon.shape = RibbonTrailMesh.SHAPE_FLAT
	ribbon.curve = 0
	trail.mesh = ribbon
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail.material_override = mat
	parent.add_child(trail)
	return trail


# === Beam/Laser Effects ===
static func spawn_beam(parent: Node3D, from: Vector3, to: Vector3, color: Color, duration: float = 0.5) -> void:
	var beam = Node3D.new()
	parent.add_child(beam)

	var direction = (to - from)
	var length = direction.length()

	var cyl = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.1
	cylinder.height = length
	cyl.mesh = cylinder
	cyl.position = (from + to) / 2.0
	cyl.look_at(to)
	cyl.rotate_object_local(Vector3.RIGHT, PI / 2)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material_override = mat
	beam.add_child(cyl)

	# Impact at end
	var impact_sphere = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	impact_sphere.mesh = sphere
	impact_sphere.position = to
	var imat = StandardMaterial3D.new()
	imat.albedo_color = Color(1, 1, 1, 0.9)
	imat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	imat.emission_enabled = true
	imat.emission = color
	imat.emission_energy_multiplier = 6.0
	imat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact_sphere.material_override = imat
	beam.add_child(impact_sphere)

	# Fade out
	var tween = beam.create_tween().set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_property(imat, "albedo_color:a", 0.0, duration)
	tween.tween_property(cyl, "scale", Vector3(1.5, 0.3, 1.5), duration)
	beam.get_tree().create_timer(duration + 0.1).timeout.connect(beam.queue_free)


# === Shockwave ===
static func spawn_shockwave(parent: Node3D, position: Vector3, color: Color, max_radius: float = 10.0) -> void:
	var wave = Node3D.new()
	wave.position = position
	parent.add_child(wave)

	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.7
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90, 0, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	wave.add_child(ring)

	var tween = wave.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * max_radius, 1.0).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.0)
	wave.get_tree().create_timer(1.2).timeout.connect(wave.queue_free)


# === Echo Burst (special for ECHO//LINE) ===
static func spawn_echo_burst(parent: Node3D, position: Vector3, color: Color) -> void:
	var burst = Node3D.new()
	burst.position = position
	parent.add_child(burst)

	# Three concentric rings rotating
	for i in range(3):
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.3 + i * 0.1
		torus.outer_radius = 0.5 + i * 0.1
		ring.mesh = torus
		ring.rotation_degrees = Vector3(randf() * 90, randf() * 90, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		burst.add_child(ring)

		var tween = burst.create_tween().set_parallel(true)
		tween.tween_property(ring, "scale", Vector3.ONE * 4.0, 1.5 + i * 0.3).set_trans(Tween.TRANS_EXPO)
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.5 + i * 0.3)
		tween.tween_property(ring, "rotation_degrees:x", ring.rotation_degrees.x + 360.0, 1.5 + i * 0.3)

	# Central pillar of light
	var pillar = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.2
	cylinder.height = 8.0
	pillar.mesh = cylinder
	pillar.position.y = 4.0
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.emission_enabled = true
	pmat.emission = color
	pmat.emission_energy_multiplier = 5.0
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = pmat
	burst.add_child(pillar)

	var pt = burst.create_tween().set_parallel(true)
	pt.tween_property(pmat, "albedo_color:a", 0.0, 1.5)
	pt.tween_property(pillar, "scale:y", 0.0, 1.5)

	burst.get_tree().create_timer(2.0).timeout.connect(burst.queue_free)


class_name EchoVisualizer
extends Node3D

# ECHO//LINE — Echo Propagation Visualizer
# Renders spectacular visual effects when echoes propagate across timelines

@export var lifetime: float = 2.5
@export var ring_count: int = 5

var ripple_rings: Array[MeshInstance3D] = []
var particles: GPUParticles3D = null
var light: OmniLight3D = null


func _ready() -> void:
	# Create expanding ring ripples
	for i in range(ring_count):
		var ring = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.5
		torus.outer_radius = 0.7
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90, 0, 0)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1, 0.9, 0.5)
		mat.emission_energy_multiplier = 2.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		ring.scale = Vector3.ONE * (0.5 + i * 0.3)
		add_child(ring)
		ripple_rings.append(ring)

	# Create omni light for glow
	light = OmniLight3D.new()
	light.light_color = Color(1, 0.9, 0.5)
	light.light_energy = 3.0
	light.omni_range = 8.0
	add_child(light)

	# GPU particles for sparkles
	particles = GPUParticles3D.new()
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_mesh.height = 0.1
	particles.mesh = particle_mesh

	var particle_mat = StandardMaterial3D.new()
	particle_mat.emission_enabled = true
	particle_mat.emission = Color(1, 0.9, 0.5)
	particle_mat.emission_energy_multiplier = 3.0
	particles.material_override = particle_mat

	var particle_process = ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_process.emission_sphere_radius = 1.0
	particle_process.direction = Vector3(0, 1, 0)
	particle_process.spread = 180.0
	particle_process.initial_velocity_min = 2.0
	particle_process.initial_velocity_max = 5.0
	particle_process.gravity = Vector3(0, -2, 0)
	particle_process.scale_min = 0.3
	particle_process.scale_max = 0.8
	particle_process.color = Color(1, 0.9, 0.5, 1)
	particles.process_material = particle_process
	particles.amount = 30
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.explosiveness = 1.0
	add_child(particles)
	particles.emitting = true


func play(color: Color, intensity: float = 1.0) -> void:
	# Apply color theme
	for ring in ripple_rings:
		if ring.material_override:
			ring.material_override.albedo_color = Color(color.r, color.g, color.b, 0.6)
			ring.material_override.emission = color

	if light:
		light.light_color = color
		light.light_energy = 3.0 * intensity

	if particles and particles.material_override:
		particles.material_override.emission = color

	_animate_ripples(intensity)


func _animate_ripples(intensity: float) -> void:
	var t = create_tween().set_parallel(true)
	for i in range(ripple_rings.size()):
		var ring = ripple_rings[i]
		var delay = i * 0.1
		var target_scale = (3.0 + i * 0.5) * intensity
		t.tween_property(ring, "scale", Vector3.ONE * target_scale, lifetime).set_delay(delay).set_trans(Tween.TRANS_EXPO)
		var mat_tween = create_tween()
		mat_tween.tween_property(ring.material_override, "albedo_color:a", 0.0, lifetime).set_delay(delay + 0.2)

	if light:
		t.tween_property(light, "light_energy", 0.0, lifetime)

	# Auto-cleanup
	get_tree().create_timer(lifetime + 0.5).timeout.connect(queue_free)


static func spawn(parent: Node3D, position: Vector3, color: Color, intensity: float = 1.0) -> void:
	var echo = EchoVisualizer.new()
	echo.position = position
	parent.add_child(echo)
	echo.play(color, intensity)

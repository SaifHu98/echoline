class_name SkySystem
extends Node3D

# ECHO//LINE — Advanced Sky System
# Day/night cycle, weather, clouds, atmospheric effects

@export var day_length_seconds: float = 120.0  # 2 minutes per day
@export var auto_cycle: bool = true

var current_time_of_day: float = 0.3  # 0-1 (0 = midnight, 0.5 = noon)
var weather_type: String = "clear"  # clear, cloudy, rain, fog
var weather_intensity: float = 0.0

# Sibling lookups (Sun and WorldEnvironment live next to this node
# under World3D). Resolved in _ready() because @onready cannot use
# ternary expressions with $path.
var sun: DirectionalLight3D = null
var sky: Sky = null
var sky_material: ProceduralSkyMaterial
var clouds: Array[MeshInstance3D] = []
var rain_particles: GPUParticles3D
var fog_volume: WorldEnvironment = null


func _ready() -> void:
	# Resolve sibling nodes that live next to us under World3D.
	var parent := get_parent()
	if parent:
		sun = parent.get_node_or_null("Sun") as DirectionalLight3D
		var we := parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
		fog_volume = we
		if we and we.environment:
			sky = we.environment.sky
	sky_material = ProceduralSkyMaterial.new()
	if sky:
		sky.sky_material = sky_material

	_setup_clouds()
	_setup_rain()


func _process(delta: float) -> void:
	if auto_cycle:
		current_time_of_day += delta / day_length_seconds
		if current_time_of_day > 1.0:
			current_time_of_day -= 1.0

	_update_sun()
	_update_sky()
	_update_clouds(delta)
	_update_weather(delta)


func set_time_of_day(time: float) -> void:
	current_time_of_day = clamp(time, 0.0, 1.0)
	_update_sun()
	_update_sky()


func set_weather(type: String, intensity: float = 1.0) -> void:
	weather_type = type
	weather_intensity = intensity
	_update_weather(0.0)


# === SUN ===
func _update_sun() -> void:
	if not sun:
		return
	# Sun rises in east, sets in west
	var angle = current_time_of_day * TAU - PI / 2  # Start at sunrise
	sun.rotation = Vector3(angle, -PI / 4, 0)

	var sun_height = sin(angle)
	var sun_horizontal = cos(angle)

	# Sun visibility based on height
	sun.visible = sun_height > -0.2

	# Sun color based on time
	if current_time_of_day < 0.25:  # Night to dawn
		sun.light_color = Color(0.4, 0.5, 0.8)
		sun.light_energy = 0.3
	elif current_time_of_day < 0.35:  # Dawn
		sun.light_color = Color(1, 0.7, 0.5)
		sun.light_energy = 0.8 + (current_time_of_day - 0.25) * 4
	elif current_time_of_day < 0.65:  # Day
		sun.light_color = Color(1, 0.95, 0.85)
		sun.light_energy = 1.4
	elif current_time_of_day < 0.75:  # Dusk
		sun.light_color = Color(1, 0.5, 0.3)
		sun.light_energy = 1.2 - (current_time_of_day - 0.65) * 4
	else:  # Night
		sun.light_color = Color(0.3, 0.4, 0.7)
		sun.light_energy = 0.2


# === SKY ===
func _update_sky() -> void:
	if not sky_material:
		return

	# Dynamic sky colors based on time
	if current_time_of_day < 0.2 or current_time_of_day > 0.8:
		# Night
		sky_material.sky_top_color = Color(0.02, 0.03, 0.1)
		sky_material.sky_horizon_color = Color(0.05, 0.08, 0.15)
		sky_material.ground_horizon_color = Color(0.02, 0.05, 0.1)
		sky_material.ground_bottom_color = Color(0.01, 0.02, 0.05)
	elif current_time_of_day < 0.3:
		# Dawn - orange/pink
		var t = (current_time_of_day - 0.2) / 0.1
		sky_material.sky_top_color = Color(0.1, 0.15, 0.4).lerp(Color(0.4, 0.5, 0.85), t)
		sky_material.sky_horizon_color = Color(0.4, 0.3, 0.5).lerp(Color(1, 0.6, 0.4), t)
		sky_material.ground_horizon_color = Color(0.2, 0.15, 0.2).lerp(Color(0.6, 0.4, 0.3), t)
		sky_material.ground_bottom_color = Color(0.1, 0.08, 0.1).lerp(Color(0.3, 0.2, 0.15), t)
	elif current_time_of_day < 0.7:
		# Day - blue
		sky_material.sky_top_color = Color(0.3, 0.5, 0.85)
		sky_material.sky_horizon_color = Color(0.7, 0.8, 0.95)
		sky_material.ground_horizon_color = Color(0.5, 0.5, 0.5)
		sky_material.ground_bottom_color = Color(0.2, 0.2, 0.2)
	else:
		# Dusk - red/orange
		var t = (current_time_of_day - 0.7) / 0.1
		sky_material.sky_top_color = Color(0.4, 0.5, 0.85).lerp(Color(0.3, 0.15, 0.4), t)
		sky_material.sky_horizon_color = Color(1, 0.6, 0.4).lerp(Color(0.5, 0.15, 0.3), t)
		sky_material.ground_horizon_color = Color(0.6, 0.4, 0.3).lerp(Color(0.2, 0.1, 0.15), t)
		sky_material.ground_bottom_color = Color(0.3, 0.2, 0.15).lerp(Color(0.1, 0.05, 0.08), t)

	# Sun angle for sky shader
	sky_material.sun_angle_max = 30.0
	sky_material.use_debanding = true


# === CLOUDS ===
func _setup_clouds() -> void:
	# Create multiple cloud planes at different heights
	for i in range(8):
		var cloud = MeshInstance3D.new()
		var plane = QuadMesh.new()
		plane.size = Vector2(30 + randf() * 40, 15 + randf() * 25)
		cloud.mesh = plane

		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.7)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.9, 0.95)
		mat.emission_energy_multiplier = 0.3
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		cloud.material_override = mat

		var angle = randf() * TAU
		var dist = randf_range(20, 40)
		cloud.position = Vector3(cos(angle) * dist, 25 + randf() * 15, sin(angle) * dist)
		cloud.rotation_degrees = Vector3(0, randf() * 360, 0)
		# Make clouds face the camera (billboard mode is a BaseMaterial3D feature)
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(cloud)
		clouds.append(cloud)


func _update_clouds(delta: float) -> void:
	for cloud in clouds:
		# Slow drift
		cloud.rotation.y += delta * 0.5
		# Adjust alpha based on time of day
		var mat = cloud.material_override
		if mat and mat is StandardMaterial3D:
			var alpha = 0.7
			if current_time_of_day < 0.2 or current_time_of_day > 0.8:
				alpha = 0.3  # Less visible at night
			mat.albedo_color.a = alpha


# === WEATHER ===
func _setup_rain() -> void:
	rain_particles = GPUParticles3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.01
	cylinder.bottom_radius = 0.01
	cylinder.height = 0.3
	# In Godot 4 the mesh is set via draw_pass_1 (not .mesh).
	rain_particles.draw_pass_1 = cylinder

	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.6, 0.9)
	mat.emission_energy_multiplier = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_particles.material_override = mat

	var proc = ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	proc.emission_box_extents = Vector3(40, 0, 40)
	proc.direction = Vector3(0, -1, 0)
	proc.spread = 5.0
	proc.initial_velocity_min = 15.0
	proc.initial_velocity_max = 20.0
	proc.gravity = Vector3(0, -10, 0)
	proc.scale_min = 0.5
	proc.scale_max = 1.0
	proc.color = Color(0.7, 0.8, 1.0, 0.6)
	rain_particles.process_material = proc
	rain_particles.amount = 1000
	rain_particles.lifetime = 1.5
	rain_particles.position.y = 30
	rain_particles.emitting = false
	add_child(rain_particles)


func _update_weather(_delta: float) -> void:
	var env = get_viewport().get_camera_3d().environment if get_viewport().get_camera_3d() else null

	match weather_type:
		"clear":
			if rain_particles:
				rain_particles.emitting = false
			if env:
				env.fog_density = 0.002
				env.fog_light_color = Color(0.8, 0.85, 0.9)
		"cloudy":
			if rain_particles:
				rain_particles.emitting = false
			if env:
				env.fog_density = 0.008
				env.fog_light_color = Color(0.6, 0.65, 0.7)
		"rain":
			if rain_particles:
				rain_particles.emitting = true
				rain_particles.amount = int(1000 * weather_intensity)
			if env:
				env.fog_density = 0.012
				env.fog_light_color = Color(0.4, 0.45, 0.55)
		"fog":
			if rain_particles:
				rain_particles.emitting = false
			if env:
				env.fog_density = 0.025 * weather_intensity
				env.fog_light_color = Color(0.7, 0.7, 0.75)

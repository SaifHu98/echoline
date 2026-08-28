extends Node3D

# ECHO//LINE — Echo Ripple (timeline-shaped poolable VFX)
# Past: arc-opening
# Present: square pulse
# Future: hex frame

@export var timeline: String = "past"
@export var max_radius: float = 4.0
@export var lifetime: float = 1.5

var elapsed: float = 0.0
var active: bool = false


func reset() -> void:
	elapsed = 0.0
	active = false
	for child in get_children():
		child.queue_free()


func play(color: Color = Color("#FFFFFF")) -> void:
	reset()
	active = true
	_build_visual(color)


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	var t = clamp(elapsed / lifetime, 0.0, 1.0)
	# Ease-out exponential
	var eased = 1.0 - exp(-elapsed * 5.0)
	var current_radius = max_radius * eased
	# Update visual
	for child in get_children():
		if child.has_meta("is_ripple_layer"):
			child.scale = Vector3.ONE * (current_radius / max_radius)
			var mat = child.material_override
			if mat is StandardMaterial3D:
				var alpha = 1.0 - t
				mat.albedo_color.a = alpha * 0.85
				mat.emission_energy_multiplier = 3.0 * (1.0 - t * 0.7)
	if elapsed >= lifetime:
		_release()


func _release() -> void:
	active = false
	visible = false
	var pool = get_tree().get_first_node_in_group("vfx_pool")
	if pool and pool.has_method("release"):
		pool.release("ripple_" + timeline, self)


func _build_visual(color: Color) -> void:
	match timeline:
		"past":
			_build_arc(color)
		"present":
			_build_square_pulse(color)
		"future":
			_build_hex_frame(color)


# === Past: arc-opening (half-circle) ===
func _build_arc(color: Color) -> void:
	var arc = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.8
	arc.mesh = torus
	arc.rotation_degrees = Vector3(90, 0, 0)
	arc.scale = Vector3(1.0, 1.0, 0.4)  # half-circle illusion
	arc.set_meta("is_ripple_layer", true)
	var mat = make_standard_material(color, true)
	arc.material_override = mat
	add_child(arc)


# === Present: concentric square pulse ===
func _build_square_pulse(color: Color) -> void:
	for i in range(3):
		var sq = MeshInstance3D.new()
		var plane = QuadMesh.new()
		plane.size = Vector2(1.0, 1.0)
		sq.mesh = plane
		sq.rotation_degrees = Vector3(90, 0, 0)
		sq.scale = Vector3(0.3 + i * 0.3, 0.3 + i * 0.3, 1.0)
		sq.set_meta("is_ripple_layer", true)
		var mat = make_standard_material(color, true)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sq.material_override = mat
		add_child(sq)


# === Future: hex frame ===
func _build_hex_frame(color: Color) -> void:
	var frame = MeshInstance3D.new()
	# Use a 6-sided prism hollowed out
	var prism = CylinderMesh.new()
	prism.top_radius = 0.8
	prism.bottom_radius = 0.8
	prism.height = 0.1
	prism.radial_segments = 6
	frame.mesh = prism
	frame.rotation_degrees = Vector3(90, 0, 30)
	frame.set_meta("is_ripple_layer", true)
	var mat = make_standard_material(color, true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frame.material_override = mat
	add_child(frame)


func make_standard_material(color: Color, emissive: bool) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
	return mat

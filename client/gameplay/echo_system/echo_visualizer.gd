class_name EchoVisualizer
extends Node3D

# Spatial Temporal Ripple Visualizer & Feedback System

func _ready() -> void:
	EventBus.echo_propagated.connect(_on_echo_propagated)

func _on_echo_propagated(echo_id: String, loc_key: String, audio_cue: String, visual_ripple: String, deltas: Array) -> void:
	if Accessibility.reduced_motion:
		# Simple static flash without motion
		return

	spawn_ripple_effect(visual_ripple)

func spawn_ripple_effect(ripple_type: String) -> void:
	# Instantiates timeline distortion ripple mesh & tween scale
	var ripple_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	ripple_mesh.mesh = sphere

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = _get_ripple_color(ripple_type)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	ripple_mesh.material_override = mat

	add_child(ripple_mesh)

	var tween = create_tween()
	tween.tween_property(ripple_mesh, "scale", Vector3(10, 10, 10), 0.8)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(ripple_mesh.queue_free)

func _get_ripple_color(ripple_type: String) -> Color:
	match ripple_type:
		"temporal_wave_amber": return Color(0.83, 0.68, 0.21, 0.6)
		"temporal_wave_cyan": return Color(0.0, 0.9, 1.0, 0.6)
		"temporal_wave_green": return Color(0.2, 0.8, 0.2, 0.6)
		"temporal_wave_copper": return Color(0.72, 0.45, 0.2, 0.6)
		"temporal_wave_violet": return Color(0.56, 0.07, 0.99, 0.6)
		"temporal_wave_gold": return Color(1.0, 0.84, 0.0, 0.7)
		_: return Color(1, 1, 1, 0.5)

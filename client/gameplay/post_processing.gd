extends Node

# ECHO//LINE — Post-Processing Manager
# Color grading, bloom, DOF, vignette per timeline

@export var timeline: String = "past"
var environment: Environment


func _ready() -> void:
	_setup_environment()


func _setup_environment() -> void:
	environment = Environment.new()

	# Background
	environment.background_mode = Environment.BG_MODE_SKY

	# Ambient
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.4

	# Tonemap (Filmic for AAA look)
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.tonemap_white = 6.0

	# Glow/Bloom
	environment.glow_enabled = true
	environment.glow_intensity = 1.2
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.4
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.glow_hdr_threshold = 0.85
	environment.glow_hdr_scale = 2.0
	environment.glow_luminance_cap = 8.0

	# SSAO
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.0
	environment.ssao_radius = 1.0
	environment.ssao_power = 1.5

	# Fog
	environment.fog_enabled = true
	environment.fog_density = 0.005
	environment.fog_light_color = Color(0.7, 0.75, 0.8)
	environment.fog_sun_scatter = 0.3

	# SSR (screen-space reflections for water)
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	environment.ssr_fade_in = 0.3
	environment.ssr_fade_out = 2.0
	environment.ssr_depth_tolerance = 0.2

	# Sub-scattering
	environment.sss_enabled = false

	# Adjustments
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.05
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.2

	# Apply timeline-specific
	_apply_timeline_grading()


func _apply_timeline_grading() -> void:
	match timeline:
		"past":
			# Warm golden grading
			environment.adjustment_color_correction = _make_warm_grading()
			environment.fog_light_color = Color(1.0, 0.85, 0.65)
			environment.glow_hdr_threshold = 0.8
		"present":
			# Neutral realistic grading
			environment.adjustment_color_correction = _make_neutral_grading()
			environment.fog_light_color = Color(0.7, 0.8, 0.9)
		"future":
			# Cool violet/magenta grading
			environment.adjustment_color_correction = _make_cool_grading()
			environment.fog_light_color = Color(0.7, 0.6, 0.95)
			environment.glow_hdr_threshold = 0.7
			environment.glow_intensity = 1.5


func _make_warm_grading() -> Texture:
	# In production, create a 4x4 color matrix or use a TextureGradient
	return null  # Placeholder


func _make_neutral_grading() -> Texture:
	return null


func _make_cool_grading() -> Texture:
	return null


func set_timeline(new_timeline: String) -> void:
	timeline = new_timeline
	_apply_timeline_grading()


func update_for_event(event_type: String) -> void:
	match event_type:
		"catastrophe_warning":
			environment.glow_intensity = 2.0
			environment.adjustment_saturation = 1.5
		"harmony":
			environment.glow_intensity = 1.5
			environment.adjustment_brightness = 1.2
		"danger":
			environment.adjustment_contrast = 1.3
			environment.glow_hdr_threshold = 0.6


func get_environment() -> Environment:
	return environment

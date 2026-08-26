extends Node

# ECHO//LINE — Vertical Slice Scene Controller
# Showcases all 3 timelines in a curated camera path
# Demonstrates: lighting, materials, VFX, UI, Echo trail, audio reactivity

@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var camera_rig: Node3D = $CameraRig
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
@onready var vfx_pool: VFXPool = $VFXPool
@onready var echo_trail: EchoTrailRenderer = $EchoTrailRenderer
@onready var hud_label: Label = $UI/HUD/InfoLabel
@onready var quality_label: Label = $UI/HUD/QualityLabel

var camera_targets: Array = []
var current_target_index: int = 0
var current_segment_time: float = 0.0
var segment_duration: float = 6.0
var auto_advance: bool = true
var demo_echo_timer: float = 0.0
var demo_echo_interval: float = 8.0
var elapsed: float = 0.0


func _ready() -> void:
	_setup_quality()
	_setup_camera_targets()
	_register_vfx_templates()
	_setup_lighting()
	_show_hud()


func _setup_quality() -> void:
	QualityProfile.load_from_disk()
	if QualityProfile.auto_detect:
		var detected = QualityProfile.detect_tier()
		QualityProfile.set_tier(detected)
	QualityProfile.apply_tier_to_scene_tree(get_tree(), QualityProfile.current_tier)
	if quality_label:
		quality_label.text = QualityProfile.get_summary()


func _register_vfx_templates() -> void:
	var ripple_past = preload("res://gameplay/vfx/echo_ripple_past.tscn")
	var ripple_present = preload("res://gameplay/vfx/echo_ripple_present.tscn")
	var ripple_future = preload("res://gameplay/vfx/echo_ripple_future.tscn")

	vfx_pool.register_pool("ripple_past", ripple_past, 8)
	vfx_pool.register_pool("ripple_present", ripple_present, 8)
	vfx_pool.register_pool("ripple_future", ripple_future, 8)

	if echo_trail:
		echo_trail.ripple_template_past = ripple_past
		echo_trail.ripple_template_present = ripple_present
		echo_trail.ripple_template_future = ripple_future


func _setup_camera_targets() -> void:
	# Cinematic dolly path: Past plaza → Present courtyard → Future spire
	camera_targets = [
		{
			"position": Vector3(0, 4, -10),
			"look_at": Vector3(0, 1, 0),
			"timeline": "past",
			"label": "PAST — Heritage Plaza",
		},
		{
			"position": Vector3(8, 4, 4),
			"look_at": Vector3(6, 1, 3),
			"timeline": "present",
			"label": "PRESENT — Courtyard",
		},
		{
			"position": Vector3(-6, 5, 8),
			"look_at": Vector3(0, 2, 12),
			"timeline": "future",
			"label": "FUTURE — Temporal Spire",
		},
	]


func _setup_lighting() -> void:
	if sun:
		match QualityProfile.current_tier:
			QualityProfile.Tier.LOW_30FPS:
				sun.light_energy = 0.8
				sun.shadow_enabled = false
			QualityProfile.Tier.MEDIUM_60FPS:
				sun.light_energy = 1.0
				sun.shadow_enabled = true
			QualityProfile.Tier.HIGH_60FPS_PREMIUM:
				sun.light_energy = 1.2
				sun.shadow_enabled = true


func _process(delta: float) -> void:
	elapsed += delta

	if auto_advance:
		_update_camera_dolly(delta)

	demo_echo_timer += delta
	if demo_echo_timer >= demo_echo_interval:
		demo_echo_timer = 0.0
		_trigger_demo_echo()


func _update_camera_dolly(delta: float) -> void:
	if camera_targets.is_empty():
		return

	current_segment_time += delta
	var t = clamp(current_segment_time / segment_duration, 0.0, 1.0)

	var target = camera_targets[current_target_index]
	var start_pos = target.position + Vector3(2, 0, 2)
	var end_pos = target.position

	# Smooth ease
	var eased = 1.0 - pow(1.0 - t, 3.0)
	camera_rig.global_position = start_pos.lerp(end_pos, eased)
	camera.look_at(target.look_at, Vector3.UP)

	if hud_label:
		hud_label.text = target.label + " — " + str(int(current_segment_time)) + "s"

	if t >= 1.0:
		current_segment_time = 0.0
		current_target_index = (current_target_index + 1) % camera_targets.size()
		_show_target_change()


func _show_target_change() -> void:
	var target = camera_targets[current_target_index]
	if sun:
		match target.timeline:
			"past":
				sun.light_color = Color("#FFD086")
			"present":
				sun.light_color = Color("#FFFFFF")
			"future":
				sun.light_color = Color("#A0E5FF")
	# Apply post-processing color grade per timeline
	if world_environment and world_environment.environment:
		match target.timeline:
			"past":
				world_environment.environment.background_mode = Environment.BG_COLOR
				world_environment.environment.background_color = Color("#3A2E1A")
			"present":
				world_environment.environment.background_mode = Environment.BG_COLOR
				world_environment.environment.background_color = Color("#1E2429")
			"future":
				world_environment.environment.background_mode = Environment.BG_COLOR
				world_environment.environment.background_color = Color("#1A1530")


func _trigger_demo_echo() -> void:
	var timeline = camera_targets[current_target_index].timeline
	var pos = camera_targets[current_target_index].look_at

	if echo_trail and echo_trail.has_method("play_echo_chain"):
		var target_pos = pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		var target_timeline = ["past", "present", "future"][randi() % 3]
		echo_trail.play_echo_chain(pos, target_pos, timeline, target_timeline, 600)


func _show_hud() -> void:
	pass


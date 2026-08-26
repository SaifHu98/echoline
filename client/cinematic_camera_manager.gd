extends Node

# ECHO//LINE — Cinematic Camera Manager
# Uses Phantom Camera for smooth timeline transitions.
# Install: AssetStore → Search "Phantom Camera" by Ramokz

const PHANTOM_CAMERA_PATH := "res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd"

var phantom_camera: Node = null
var camera_presets: Dictionary = {}

func _ready() -> void:
	# Auto-load PhantomCamera2D if available
	if ResourceLoader.exists(PHANTOM_CAMERA_PATH):
		var pc_class = load(PHANTOM_CAMERA_PATH)
		if pc_class:
			print("[CinematicCameraManager] PhantomCamera2D available")


# === Timeline Camera Presets ===

func setup_timeline_cameras() -> void:
	# Add 3 PhantomCamera2D nodes to your scene for each timeline
	# Each has its own follow target and zoom level
	pass


func transition_to_timeline(timeline: String, duration: float = 2.0) -> void:
	# Uses PhantomCamera2D's tween API for smooth transitions
	if not phantom_camera:
		push_warning("[CinematicCameraManager] Phantom Camera not installed — falling back to direct camera control")
		_fallback_transition(timeline)
		return

	match timeline:
		"past":
			_tween_phantom_camera(_get_past_preset(), duration)
		"present":
			_tween_phantom_camera(_get_present_preset(), duration)
		"future":
			_tween_phantom_camera(_get_future_preset(), duration)


func _tween_phantom_camera(preset: Dictionary, duration: float) -> void:
	# Example using Phantom Camera API:
	# phantom_camera.tween_to_position(preset.position, duration)
	# phantom_camera.tween_to_zoom(preset.zoom, duration)
	pass


# === Camera Presets ===

func _get_past_preset() -> Dictionary:
	return {
		"position": Vector2(200, 100),
		"zoom": Vector2(0.8, 0.8),
		"rotation": 0.0,
		"follow_speed": 0.1
	}


func _get_present_preset() -> Dictionary:
	return {
		"position": Vector2(640, 360),
		"zoom": Vector2(1.0, 1.0),
		"rotation": 0.0,
		"follow_speed": 0.15
	}


func _get_future_preset() -> Dictionary:
	return {
		"position": Vector2(1100, 600),
		"zoom": Vector2(1.2, 1.2),
		"rotation": 0.0,
		"follow_speed": 0.05
	}


func _fallback_transition(timeline: String) -> void:
	# Use plain Camera2D if Phantom Camera not available
	pass


# === Cinematic Sequences ===

func play_intro_cinematic() -> void:
	# Used in client/scenes/intro.gd
	transition_to_timeline("past", 3.0)
	await get_tree().create_timer(3.5).timeout
	transition_to_timeline("present", 2.0)
	await get_tree().create_timer(2.5).timeout
	transition_to_timeline("future", 2.0)
	await get_tree().create_timer(2.5).timeout


func play_match_intro(timeline: String) -> void:
	# Used when player starts a match
	transition_to_timeline(timeline, 1.5)


func play_causal_recap_camera_shots(events: Array) -> void:
	# Used in client/ui/recap/causal_recap_view.gd
	for event in events:
		# PhantomCamera tween to event location
		await get_tree().create_timer(1.5).timeout

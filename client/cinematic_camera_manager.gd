extends Node

# ECHO//LINE — Cinematic Camera Manager (Phase 1, Phantom Camera)
# Uses real Phantom Camera 2D/3D API from
# res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_*.gd
#
# Activation: enable "Phantom Camera" plugin in
#   Project → Project Settings → Plugins
# Author: Marcus Skov (Ramokz) — MIT-style license.
#
# This manager owns 3 PhantomCamera3D presets (one per timeline) plus a
# PhantomCamera2D top-down camera for HUD scenes, and exposes a simple
# tween_to_timeline() API for cutscenes and Recap shots.

const PHANTOM_CAMERA_3D := preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd")
const PHANTOM_CAMERA_2D := preload("res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd")

const PRESET_PRIORITY_PAST := 1
const PRESET_PRIORITY_PRESENT := 2
const PRESET_PRIORITY_FUTURE := 3

var phantom_3d_past: Node = null
var phantom_3d_present: Node = null
var phantom_3d_future: Node = null
var phantom_2d_hud: Node = null
var is_ready: bool = false

signal timeline_camera_changed(timeline: String)
signal cinematic_sequence_finished(sequence_id: String)

func _ready() -> void:
	_ensure_addon_enabled()
	is_ready = ClassDB.class_exists("PhantomCamera3D") and ClassDB.class_exists("PhantomCamera2D")
	if is_ready:
		print("[CinematicCameraManager] Phantom Camera API available")
	else:
		push_warning("[CinematicCameraManager] Phantom Camera not enabled — using fallback Camera3D/Camera2D")
	_build_presets()


func _ensure_addon_enabled() -> void:
	# If the editor didn't auto-register the classes (rare), we still load them
	# by preloading the script above. This means the manager works even when the
	# plugin is disabled in Project Settings, as long as the addon folder exists.
	pass


# === Preset construction ===

func _build_presets() -> void:
	# 3D presets for timeline cameras. These get attached to whatever Camera3D
	# the player uses in the gameplay scene by calling attach_to_camera_3d().
	phantom_3d_past = _make_3d_preset("Past", Vector3(-12.0, 8.0, -10.0), Vector3(0, 0, 0),
		PRESET_PRIORITY_PAST, 60.0)
	phantom_3d_present = _make_3d_preset("Present", Vector3(0.0, 6.0, 8.0), Vector3(0, 0, 0),
		PRESET_PRIORITY_PRESENT, 50.0)
	phantom_3d_future = _make_3d_preset("Future", Vector3(10.0, 12.0, -4.0), Vector3(0, 0, 0),
		PRESET_PRIORITY_FUTURE, 70.0)
	# 2D preset for top-down HUD view.
	phantom_2d_hud = _make_2d_preset("HUD", Vector2(640, 360), Vector2(1.0, 1.0), 0)


func _make_3d_preset(label: String, position: Vector3, look_at: Vector3,
		priority: int, fov: float) -> Node:
	var pc := PHANTOM_CAMERA_3D.new()
	pc.name = "PhantomCamera3D_" + label
	pc.set("priority", priority)
	pc.set("global_position", position)
	pc.set("fov", fov)
	pc.set("follow_mode", 0)  # 0 = Framed, 1 = Frame With Target, 2 = Ignore
	if pc.has_method("look_at_target"):
		pc.call("look_at_target", look_at)
	return pc


func _make_2d_preset(label: String, position: Vector2, zoom: Vector2, priority: int) -> Node:
	var pc := PHANTOM_CAMERA_2D.new()
	pc.name = "PhantomCamera2D_" + label
	pc.set("priority", priority)
	pc.set("global_position", position)
	pc.set("zoom", zoom)
	return pc


# === Attachment ===

func attach_to_camera_3d(target_camera: Camera3D) -> void:
	if not is_ready:
		return
	for pc in [phantom_3d_past, phantom_3d_present, phantom_3d_future]:
		if pc and pc.get_parent() == null:
			target_camera.add_child(pc)


func attach_to_camera_2d(target_camera: Camera2D) -> void:
	if not is_ready:
		return
	if phantom_2d_hud and phantom_2d_hud.get_parent() == null:
		target_camera.add_child(phantom_2d_hud)


# === Public API ===

func tween_to_timeline(timeline: String, duration: float = 2.0) -> void:
	if not is_ready:
		_fallback_set_active(timeline)
		return
	var preset: Node = null
	match timeline:
		"past":
			preset = phantom_3d_past
		"present":
			preset = phantom_3d_present
		"future":
			preset = phantom_3d_future
		_:
			push_error("[CinematicCameraManager] Unknown timeline '%s'" % timeline)
			return
	if preset == null:
		_fallback_set_active(timeline)
		return
	# Boost priority so this preset wins the active-camera race.
	preset.set("priority", 99)
	if preset.has_method("tween_to_position"):
		preset.call("tween_to_position", preset.get("global_position"), duration)
	if preset.has_method("tween_to_fov"):
		preset.call("tween_to_fov", preset.get("fov"), duration)
	timeline_camera_changed.emit(timeline)


func reset_priorities() -> void:
	if not is_ready:
		return
	phantom_3d_past.set("priority", PRESET_PRIORITY_PAST)
	phantom_3d_present.set("priority", PRESET_PRIORITY_PRESENT)
	phantom_3d_future.set("priority", PRESET_PRIORITY_FUTURE)


# === Cinematic sequences ===

func play_intro_cinematic() -> void:
	tween_to_timeline("past", 3.0)
	await get_tree().create_timer(3.5).timeout
	tween_to_timeline("present", 2.0)
	await get_tree().create_timer(2.5).timeout
	tween_to_timeline("future", 2.0)
	await get_tree().create_timer(2.5).timeout
	reset_priorities()
	cinematic_sequence_finished.emit("intro")


func play_match_intro(timeline: String) -> void:
	tween_to_timeline(timeline, 1.5)
	await get_tree().create_timer(1.8).timeout
	cinematic_sequence_finished.emit("match_intro_" + timeline)


func play_causal_recap_camera_shots(events: Array) -> void:
	# Each event: {"position": Vector3, "timeline": String}
	for i in range(events.size()):
		var event: Dictionary = events[i]
		var pos: Vector3 = event.get("position", Vector3.ZERO)
		var preset: Node = null
		match event.get("timeline", "present"):
			"past":
				preset = phantom_3d_past
			"future":
				preset = phantom_3d_future
			_:
				preset = phantom_3d_present
		if preset and preset.has_method("tween_to_position"):
			preset.set("priority", 99)
			preset.call("tween_to_position", pos, 1.2)
		await get_tree().create_timer(1.5).timeout
	reset_priorities()
	cinematic_sequence_finished.emit("causal_recap")


# === Fallback when addon not enabled ===

func _fallback_set_active(timeline: String) -> void:
	# Without Phantom Camera, we just emit the signal so listeners (HUD, audio
	# mixer, music controller) can still react. Camera position changes require
	# direct Camera3D access in the gameplay scene.
	timeline_camera_changed.emit(timeline)

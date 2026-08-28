extends Node3D

# ECHO//LINE — Runtime Gizmo (Phase 3, Gizmo3DScript)
# Wraps the Gizmo3D Node3D added by Gizmo3DScript (Chris Charbonneau, MIT).
# Gizmo3DSharp is the C# variant — same node name; we use the GDScript version
# to avoid mixing language runtimes.
#
# Activation: enable "Gizmo3DScript" in Project Settings → Plugins (DO NOT
# enable both Gizmo3DScript AND Gizmo3DSharp — they register the same node
# name and will collide).
#
# ECHO//LINE use cases:
#   - Show a moveable/scalable gizmo around the active Timeline Anchor in
#     the building editor.
#   - Allow players to rotate Memory Shards in their inventory preview.
#   - Mark objective waypoints with a pulse gizmo.

var _Gizmo3DScript: GDScript = load("res://addons/Gizmo3DScript/gizmo3D.gd")

var gizmo: Node3D = null
var is_ready: bool = false

signal gizmo_moved(new_position: Vector3)
signal gizmo_rotated(new_rotation: Vector3)
signal gizmo_scaled(new_scale: Vector3)


func _ready() -> void:
	is_ready = ClassDB.class_exists("Gizmo3D")
	if not is_ready:
		push_warning("[RuntimeGizmo] Gizmo3DScript not enabled")
		return
	if _Gizmo3DScript == null:
		push_warning("[RuntimeGizmo] gizmo3D.gd not found")
		is_ready = false
		return
	gizmo = _Gizmo3DScript.new()
	gizmo.name = "AnchorGizmo"
	add_child(gizmo)


func attach(target: Node3D) -> void:
	if not is_ready or gizmo == null or target == null:
		return
	gizmo.global_transform = target.global_transform


func set_mode(mode: String) -> void:
	if not is_ready or gizmo == null:
		return
	# Gizmo3D supports: "Move", "Rotate", "Scale", "All"
	if gizmo.has_method("set_mode"):
		gizmo.call("set_mode", mode)


func set_size(size: float) -> void:
	if not is_ready or gizmo == null:
		return
	if gizmo.has_method("set_size"):
		gizmo.call("set_size", size)


func hide_gizmo() -> void:
	if gizmo:
		gizmo.visible = false


func show_gizmo() -> void:
	if gizmo:
		gizmo.visible = true

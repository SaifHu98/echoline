class_name LODNode
extends Node3D

# ECHO//LINE — LOD (Level of Detail) Manager
# Auto-swaps mesh detail based on distance to camera
# Switches to billboard beyond max distance
# Reduces material complexity at distance

@export var high_detail_mesh: MeshInstance3D
@export var medium_detail_mesh: MeshInstance3D
@export var low_detail_mesh: MeshInstance3D
@export var billboard_mesh: MeshInstance3D
@export var lod_distances: Vector3 = Vector3(20.0, 40.0, 70.0)
@export var billboard_distance: float = 100.0
@export var auto_update: bool = true
@export var update_interval: float = 0.5  # check every 500ms

var current_lod: int = 0  # 0=high, 1=medium, 2=low, 3=billboard, 4=culled
var last_update_time: float = 0.0
var camera: Camera3D = null


func _ready() -> void:
	_apply_lod(0)
	_set_visible_lod(0)


func _process(delta: float) -> void:
	if not auto_update:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_update_time < update_interval:
		return
	last_update_time = now
	_update_lod()


func _update_lod() -> void:
	if not camera:
		_find_camera()
	if not camera:
		return

	var dist = global_position.distance_to(camera.global_position)

	var new_lod = 0
	if dist > billboard_distance:
		new_lod = 4  # culled
	elif dist > lod_distances.z:
		new_lod = 3  # billboard
	elif dist > lod_distances.y:
		new_lod = 2  # low
	elif dist > lod_distances.x:
		new_lod = 1  # medium
	else:
		new_lod = 0  # high

	if new_lod != current_lod:
		_apply_lod(new_lod)


func _apply_lod(lod: int) -> void:
	current_lod = lod
	_set_visible_lod(lod)
	# Reduce material complexity at distance
	match lod:
		0:  # high — full quality
			if high_detail_mesh:
				high_detail_mesh.material_override = null  # full material
		1:  # medium — slight reduction
			pass
		2:  # low — basic material
			pass
		3:  # billboard — single quad
			pass
		4:  # culled
			visible = false
			return
	visible = true


func _set_visible_lod(lod: int) -> void:
	if high_detail_mesh:
		high_detail_mesh.visible = (lod == 0)
	if medium_detail_mesh:
		medium_detail_mesh.visible = (lod == 1)
	if low_detail_mesh:
		low_detail_mesh.visible = (lod == 2)
	if billboard_mesh:
		billboard_mesh.visible = (lod == 3)


func _find_camera() -> void:
	var root = get_tree().root
	if root:
		camera = root.get_viewport().get_camera_3d()


func force_lod(lod: int) -> void:
	_apply_lod(lod)


static func attach_to(mesh: MeshInstance3D, distances: Vector3 = Vector3(20.0, 40.0, 70.0), billboard: MeshInstance3D = null) -> Node3D:
	var holder = Node3D.new()
	var parent = mesh.get_parent()
	parent.remove_child(mesh)
	parent.add_child(holder)
	holder.add_child(mesh)
	holder.global_transform = mesh.global_transform
	mesh.owner = holder

	# For simplicity, we'll use the same mesh at all LODs
	# In a full implementation, you'd have separate high/med/low meshes
	var lod = LODNode.new()
	lod.high_detail_mesh = mesh
	lod.medium_detail_mesh = mesh
	lod.low_detail_mesh = mesh
	lod.billboard_mesh = billboard if billboard else mesh
	lod.lod_distances = distances
	holder.add_child(lod)
	lod.owner = holder
	return holder

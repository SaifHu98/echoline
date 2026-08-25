class_name SnapGrid
extends Node3D

const DEFAULT_GRID_SIZE := 1.0

@export var grid_size: float = DEFAULT_GRID_SIZE
@export var snap_rotation_deg: float = 90.0
@export var allow_negative: bool = true

func snap_position(world_pos: Vector3) -> Vector3:
	var g: float = max(0.1, grid_size)
	var x: float = round(world_pos.x / g) * g
	var y: float = round(world_pos.y / g) * g
	var z: float = round(world_pos.z / g) * g
	if not allow_negative:
		x = max(0.0, x)
		y = max(0.0, y)
		z = max(0.0, z)
	return Vector3(x, y, z)

func snap_rotation(world_rot_deg: Vector3) -> Vector3:
	var s: float = max(0.0001, snap_rotation_deg)
	return Vector3(
		round(world_rot_deg.x / s) * s,
		round(world_rot_deg.y / s) * s,
		round(world_rot_deg.z / s) * s
	)

func to_grid_cell(world_pos: Vector3) -> Vector3i:
	var g: float = max(0.1, grid_size)
	return Vector3i(
		int(round(world_pos.x / g)),
		int(round(world_pos.y / g)),
		int(round(world_pos.z / g))
	)

func from_grid_cell(cell: Vector3i) -> Vector3:
	var g: float = max(0.1, grid_size)
	return Vector3(cell.x * g, cell.y * g, cell.z * g)

func is_cell_within(cells: Vector3i, bounds_cells: Vector3i) -> bool:
	if not allow_negative and (cells.x < 0 or cells.y < 0 or cells.z < 0):
		return false
	return cells.x < bounds_cells.x and cells.y < bounds_cells.y and cells.z < bounds_cells.z
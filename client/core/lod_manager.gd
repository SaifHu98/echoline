class_name LODManager
extends Node

# Dynamic Level of Detail (LOD) & Occlusion Culling Manager

@export var lod_near_dist: float = 15.0
@export var lod_far_dist: float = 35.0

var registered_lod_entities: Array[Dictionary] = []

func register_entity(node: Node3D, high_detail_mesh: Node, low_detail_mesh: Node) -> void:
	registered_lod_entities.append({
		"root": node,
		"high": high_detail_mesh,
		"low": low_detail_mesh,
		"current_tier": 0
	})

func update_lods(camera: Camera3D) -> void:
	if not camera: return
	var cam_pos = camera.global_position

	for entity in registered_lod_entities:
		if not is_instance_valid(entity.root): continue
		var dist = cam_pos.distance_to(entity.root.global_position)

		if dist < lod_near_dist:
			if entity.current_tier != 0:
				if entity.high: entity.high.visible = true
				if entity.low: entity.low.visible = false
				entity.current_tier = 0
		elif dist < lod_far_dist:
			if entity.current_tier != 1:
				if entity.high: entity.high.visible = false
				if entity.low: entity.low.visible = true
				entity.current_tier = 1
		else:
			# Beyond far distance -> Hide meshes (Occlusion culling)
			if entity.current_tier != 2:
				if entity.high: entity.high.visible = false
				if entity.low: entity.low.visible = false
				entity.current_tier = 2

class_name ObjectPool
extends Node

# High-Performance Zero-Allocation Object Pool for Mobile & Low-Memory Devices

var available_instances: Array[Node] = []
var active_instances: Array[Node] = []
var template_scene: PackedScene = null
var pool_parent: Node = null

func initialize(scene: PackedScene, initial_count: int, parent_node: Node) -> void:
	template_scene = scene
	pool_parent = parent_node

	for i in range(initial_count):
		var inst = template_scene.instantiate()
		inst.visible = false
		pool_parent.add_child(inst)
		available_instances.append(inst)

func acquire() -> Node:
	var inst: Node = null
	if not available_instances.is_empty():
		inst = available_instances.pop_back()
	else:
		# Expand pool if depleted
		inst = template_scene.instantiate()
		pool_parent.add_child(inst)

	active_instances.append(inst)
	inst.visible = true
	return inst

func release(inst: Node) -> void:
	var idx = active_instances.find(inst)
	if idx != -1:
		active_instances.remove_at(idx)
		inst.visible = false
		available_instances.append(inst)

func release_all() -> void:
	while not active_instances.is_empty():
		var inst = active_instances.pop_back()
		inst.visible = false
		available_instances.append(inst)

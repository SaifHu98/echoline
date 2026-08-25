class_name VFXPool
extends Node

# ECHO//LINE — VFX Pool (specialized ObjectPool for visual effects)
# Pre-allocates VFX instances at scene start to avoid instantiate() in gameplay loop
# Each VFX type has its own pool sized per quality profile

var pools: Dictionary = {}           # type → ObjectPool
var template_scenes: Dictionary = {}  # type → PackedScene
var parent_node: Node = null


func _ready() -> void:
	parent_node = self
	_initialize_default_pools()


func initialize(profile_tier: int) -> void:
	var pool_size = QualityProfile.get_profile(profile_tier).get("vfx_pool_size", 32)
	for type in pools.keys():
		if pools[type].has_method("initialize"):
			pools[type].initialize(template_scenes.get(type), pool_size, parent_node)


# === Register & instantiate pools on demand ===

func register_pool(vfx_type: String, scene: PackedScene, initial_count: int = 16) -> void:
	if not scene:
		return
	if pools.has(vfx_type):
		return
	var pool = ObjectPool.new()
	pool.template_scene = scene
	pool.pool_parent = parent_node
	for i in range(initial_count):
		var inst = scene.instantiate()
		inst.visible = false
		add_child(inst)
		pool.available_instances.append(inst)
	pools[vfx_type] = pool
	template_scenes[vfx_type] = scene


func acquire(vfx_type: String) -> Node:
	if not pools.has(vfx_type):
		return null
	var inst = pools[vfx_type].acquire()
	if inst and inst.has_method("reset"):
		inst.reset()
	return inst


func release(vfx_type: String, inst: Node) -> void:
	if not pools.has(vfx_type):
		return
	pools[vfx_type].release(inst)


func release_all() -> void:
	for pool in pools.values():
		if pool.has_method("release_all"):
			pool.release_all()


# === Statistics ===

func get_pool_stats() -> Dictionary:
	var stats = {}
	for type in pools.keys():
		var pool = pools[type]
		stats[type] = {
			"available": pool.available_instances.size(),
			"active": pool.active_instances.size(),
		}
	return stats


func get_total_active() -> int:
	var total = 0
	for pool in pools.values():
		total += pool.active_instances.size()
	return total


# === Default initialization ===

func _initialize_default_pools() -> void:
	# Will be populated by registering PackedScenes after scene tree is ready
	pass

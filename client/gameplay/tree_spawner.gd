extends Node

# ECHO//LINE — Tree Spawner (Phase 2, Tree3D)
# IMPORTANT: Tree3D v0.91 (Artyom Bozhko) is a GDExtension that ships ONLY
# Windows / macOS / Linux binaries. There are NO Android .so libraries
# bundled, so the class will not register on Android devices.
#
# Activation: Tree3D loads automatically because its gdextension file
# (Tree3D.gdextension) declares compatibility_minimum = 4.5. The class
# `Tree3D` becomes available wherever a desktop binary exists.
#
# ECHO//LINE recommendation:
#   - For DESKTOP builds (future Steam / web export): enable this addon.
#   - For ANDROID (current target): SKIP it. Use lowpolyterrain +
#     hand-placed MeshInstance3D trees instead.

const TREE3D_GDEXTENSION := "res://addons/Tree3D/Tree3D.gdextension"

const TREE_PROFILES := {
	"past": {
		"trunk_color": Color(0.32, 0.20, 0.10),
		"leaves_color": Color(0.40, 0.55, 0.30),
		"tree_archetype": "ancient_oak",
		"height_range": Vector2(8.0, 14.0),
	},
	"present": {
		"trunk_color": Color(0.28, 0.18, 0.10),
		"leaves_color": Color(0.50, 0.55, 0.45),
		"tree_archetype": "modern_birch",
		"height_range": Vector2(6.0, 10.0),
	},
	"future": {
		"trunk_color": Color(0.10, 0.12, 0.18),
		"leaves_color": Color(0.55, 0.78, 1.00),
		"tree_archetype": "crystal_geode",
		"height_range": Vector2(4.0, 7.0),
	},
}

var is_desktop_ready: bool = false
var is_android_skipped: bool = false


func _ready() -> void:
	if not ResourceLoader.exists(TREE3D_GDEXTENSION):
		push_warning("[TreeSpawner] Tree3D gdextension file missing")
		return
	var ext: Resource = load(TREE3D_GDEXTENSION)
	if ext == null:
		return
	is_desktop_ready = ClassDB.class_exists("Tree3D")
	is_android_skipped = OS.get_name() == "Android"
	if is_android_skipped:
		push_warning("[TreeSpawner] Tree3D has no Android binary — using MeshInstance3D fallback")
	elif is_desktop_ready:
		print("[TreeSpawner] Tree3D API available (desktop)")
	else:
		push_warning("[TreeSpawner] Tree3D binary missing for current OS")


func spawn_tree(world_pos: Vector3, timeline: String) -> Node3D:
	var profile: Dictionary = TREE_PROFILES.get(timeline, TREE_PROFILES["present"])
	if is_desktop_ready and not is_android_skipped:
		return _spawn_tree3d(world_pos, profile)
	return _spawn_fallback(world_pos, profile)


func _spawn_tree3d(world_pos: Vector3, profile: Dictionary) -> Node3D:
	var Tree3DClass := ClassDB.instantiate("Tree3D")
	if Tree3DClass == null:
		return _spawn_fallback(world_pos, profile)
	var tree: Node3D = Tree3DClass
	tree.name = "Tree3D_%s_%d" % [profile.tree_archetype, randi() % 1000]
	tree.global_position = world_pos
	tree.set("max_height", profile.height_range.y)
	tree.set("min_height", profile.height_range.x)
	if tree.has_method("generate"):
		tree.call("generate")
	return tree


func _spawn_fallback(world_pos: Vector3, profile: Dictionary) -> Node3D:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.3
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = profile.height_range.x
	trunk.mesh = trunk_mesh
	trunk.position = world_pos + Vector3(0, profile.height_range.x / 2.0, 0)
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = profile.trunk_color
	trunk.material_override = trunk_mat

	var leaves := MeshInstance3D.new()
	var leaves_mesh := SphereMesh.new()
	leaves_mesh.radius = 1.6
	leaves_mesh.height = 3.2
	leaves.mesh = leaves_mesh
	leaves.position = world_pos + Vector3(0, profile.height_range.x + 1.6, 0)
	var leaves_mat := StandardMaterial3D.new()
	leaves_mat.albedo_color = profile.leaves_color
	leaves.material_override = leaves_mat

	var group := Node3D.new()
	group.name = "FallbackTree_%d" % randi() % 1000
	group.add_child(trunk)
	group.add_child(leaves)
	return group

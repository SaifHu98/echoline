extends Node3D

# ECHO//LINE — Foliage Painter (Phase 2, FoliageFlow)
# Wraps the "FoliageFlow" custom Node3D added by the plugin.
# Activation: enable "FoliageFlow" in Project Settings → Plugins.
#
# In editor: paint foliage onto any terrain mesh (works with both
# Terrain3D and LowPolyTerrain).
# At runtime: use the API below to spawn foliage instances via the
# MultiMesh that the plugin manages internally.

const FoliageFlowScript := preload("res://addons/FoliageFlow/FoliageFlow.gd")

const TIMELINE_FOLIAGE := {
	"past": {
		"meshes": [
			"res://meshes/foliage/past_grass.tres",
			"res://meshes/foliage/past_bush.tres",
			"res://meshes/foliage/past_tree.tres",
		],
		"density": 0.6,
		"scale_range": Vector2(0.8, 1.2),
		"color_tint": Color(0.45, 0.55, 0.35),
	},
	"present": {
		"meshes": [
			"res://meshes/foliage/present_potted.tres",
		],
		"density": 0.2,
		"scale_range": Vector2(0.9, 1.0),
		"color_tint": Color(0.50, 0.55, 0.50),
	},
	"future": {
		"meshes": [
			"res://meshes/foliage/future_crystal_grass.tres",
		],
		"density": 0.3,
		"scale_range": Vector2(0.7, 1.3),
		"color_tint": Color(0.55, 0.78, 1.00),
	},
}

var foliage_node: Node3D = null
var current_timeline: String = ""
var is_ready: bool = false

signal foliage_ready(timeline: String)


func _ready() -> void:
	is_ready = ClassDB.class_exists("FoliageFlow")
	if not is_ready:
		push_warning("[FoliagePainter] FoliageFlow plugin not enabled")


func attach_to_terrain(terrain_node: Node3D, timeline: String) -> void:
	if not TIMELINE_FOLIAGE.has(timeline):
		return
	if not is_ready:
		return
	current_timeline = timeline
	if foliage_node and is_instance_valid(foliage_node):
		foliage_node.queue_free()
	foliage_node = FoliageFlowScript.new()
	foliage_node.name = "Foliage_" + timeline.capitalize()
	if terrain_node:
		terrain_node.add_child(foliage_node)
	else:
		add_child(foliage_node)
	_apply_profile(TIMELINE_FOLIAGE[timeline])
	foliage_ready.emit(timeline)


func _apply_profile(profile: Dictionary) -> void:
	if foliage_node == null:
		return
	var valid_meshes: Array = []
	for path in profile.meshes:
		if ResourceLoader.exists(path):
			valid_meshes.append(load(path))
	if foliage_node.has_method("set_density"):
		foliage_node.call("set_density", profile.density)
	if foliage_node.has_method("set_scale_range"):
		foliage_node.call("set_scale_range", profile.scale_range)
	if foliage_node.has_method("set_color_tint"):
		foliage_node.call("set_color_tint", profile.color_tint)
	if foliage_node.has_method("set_meshes") and valid_meshes.size() > 0:
		foliage_node.call("set_meshes", valid_meshes)


func get_density() -> float:
	if TIMELINE_FOLIAGE.has(current_timeline):
		return TIMELINE_FOLIAGE[current_timeline].density
	return 0.0

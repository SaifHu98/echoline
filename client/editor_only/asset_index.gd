extends Node

# ECHO//LINE — Asset Index (Phase 3, Kit Browser)
# Kit Browser (ProtoForge Systems, MIT) is an EDITOR-only asset dock.
# It scans `res://` for asset folders, generates thumbnails, and lets you
# drag them into scenes with one click.
#
# Activation: enable "ProtoForge Kit Browser" in Project Settings → Plugins.
# A new "Kits" dock appears at the bottom of the editor (next to Output,
# Debugger, etc.).
#
# This wrapper exists only as documentation + a thin runtime API that lets
# gameplay code query whether a given mesh path is "kit-tagged" (i.e., was
# imported via the Kit Browser dock and therefore has metadata).

const KitBrowserScript := preload("res://addons/kit_browser/kit_browser.gd")

var is_ready: bool = false
var _cached_tagged_paths: Dictionary = {}


func _ready() -> void:
	is_ready = FileAccess.file_exists("res://addons/kit_browser/kit_browser.gd")
	if not is_ready:
		push_warning("[AssetIndex] Kit Browser plugin folder missing")
		return
	print("[AssetIndex] Kit Browser editor dock will be available after plugin enable")


func mark_tagged(path: String, tags: Array) -> void:
	_cached_tagged_paths[path] = {
		"tags": tags,
		"indexed_at": Time.get_unix_time_from_system(),
	}


func is_tagged(path: String) -> bool:
	return _cached_tagged_paths.has(path)


func get_tags(path: String) -> Array:
	if _cached_tagged_paths.has(path):
		return _cached_tagged_paths[path].get("tags", [])
	return []


# === Convenience presets for designers ===

const TIMELINE_KIT_PRESETS := {
	"past": {
		"kit_name": "ancient_courtyard",
		"expected_assets": [
			"res://meshes/past/stone_arch.glb",
			"res://meshes/past/fountain.glb",
			"res://meshes/past/lantern.glb",
			"res://meshes/past/garden_statue.glb",
		],
	},
	"present": {
		"kit_name": "modern_clock_shop",
		"expected_assets": [
			"res://meshes/present/clockwork_gear.glb",
			"res://meshes/present/brick_wall.glb",
			"res://meshes/present/neon_sign.glb",
		],
	},
	"future": {
		"kit_name": "crystal_lab",
		"expected_assets": [
			"res://meshes/future/crystal.glb",
			"res://meshes/future/hologram_panel.glb",
			"res://meshes/future/energy_pylon.glb",
		],
	},
}


func list_expected_assets(timeline: String) -> Array:
	if TIMELINE_KIT_PRESETS.has(timeline):
		return TIMELINE_KIT_PRESETS[timeline].expected_assets
	return []


func list_missing_assets(timeline: String) -> Array:
	var expected: Array = list_expected_assets(timeline)
	var missing: Array = []
	for path in expected:
		if not ResourceLoader.exists(path):
			missing.append(path)
	return missing

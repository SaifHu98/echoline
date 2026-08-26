extends Node

# ECHO//LINE — Procedural Story Service (Autoload)
# Client-side wrapper around ProceduralStoryEngine.
# - The server generates the manifest and sends it via Socket.IO.
# - The client caches the most recent manifest per room.
# - When a player joins, they call apply_manifest(manifest_dict) which
#   populates the rest of the game (intro dialogue, mission UI, spawn points).

const EngineScript := preload("res://story/procedural_story_engine.gd")

var current_manifest: Dictionary = {}
var is_ready: bool = true

signal manifest_applied(manifest: Dictionary)
signal mission_progress(mission_index: int, progress: float)
signal mission_completed(mission_index: int)
signal all_missions_completed()


func apply_manifest(manifest: Dictionary) -> void:
	current_manifest = manifest
	manifest_applied.emit(manifest)


func get_manifest() -> Dictionary:
	return current_manifest


func get_mission(index: int) -> Dictionary:
	var missions: Array = current_manifest.get("missions", [])
	if index < 0 or index >= missions.size():
		return {}
	return missions[index]


func get_mission_count() -> int:
	return current_manifest.get("missions", []).size()


func report_mission_progress(index: int, progress: float) -> void:
	mission_progress.emit(index, progress)


func report_mission_complete(index: int) -> void:
	mission_completed.emit(index)
	if index == get_mission_count() - 1:
		all_missions_completed.emit()


# Generate locally (for offline / single-player / testing).
func generate_locally(timeline: String, difficulty: int,
		player_count: int, locale: String = "en") -> Dictionary:
	var engine: RefCounted = EngineScript.new()
	var manifest: Dictionary = engine.generate(timeline, difficulty, player_count, locale)
	apply_manifest(manifest)
	return manifest


# Deserialize a JSON manifest from the server.
func apply_manifest_json(json_text: String) -> Dictionary:
	var engine_script: GDScript = EngineScript
	var parsed: Dictionary = engine_script.from_json(json_text)
	if not parsed.is_empty():
		apply_manifest(parsed)
	return parsed

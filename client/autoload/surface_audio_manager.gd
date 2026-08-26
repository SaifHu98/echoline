extends Node

# ECHO//LINE — Surface Audio Manager (Phase 2, Surfaces by Evan Todd)
# Activates the "Surfaces" plugin in Project Settings → Plugins.
# The plugin exposes a static helper `Surfaces.detect(collider) -> String`
# which we feed into audio_manager.gd to play different footstep sounds per
# material (dirt, stone, water, crystal).

const SURFACES_SCRIPT := preload("res://addons/Surfaces/surfaces.gd")

const SURFACE_FOOTSTEP_BANK := {
	"": ["res://audio/footsteps/generic_1.ogg"],
	"stone": ["res://audio/footsteps/stone_1.ogg", "res://audio/footsteps/stone_2.ogg"],
	"dirt": ["res://audio/footsteps/dirt_1.ogg", "res://audio/footsteps/dirt_2.ogg"],
	"grass": ["res://audio/footsteps/grass_1.ogg", "res://audio/footsteps/grass_2.ogg"],
	"water": ["res://audio/footsteps/water_1.ogg", "res://audio/footsteps/water_2.ogg"],
	"crystal": ["res://audio/footsteps/crystal_1.ogg", "res://audio/footsteps/crystal_2.ogg"],
	"metal": ["res://audio/footsteps/metal_1.ogg", "res://audio/footsteps/metal_2.ogg"],
	"sand": ["res://audio/footsteps/sand_1.ogg", "res://audio/footsteps/sand_2.ogg"],
	"wood": ["res://audio/footsteps/wood_1.ogg", "res://audio/footsteps/wood_2.ogg"],
}

var is_ready: bool = false
var last_surface: String = ""

signal surface_changed(surface_name: String)
signal footstep_should_play(surface_name: String, bank: Array)


func _ready() -> void:
	is_ready = ClassDB.class_exists("Surfaces")
	if is_ready:
		print("[SurfaceAudioManager] Surfaces API available")
	else:
		push_warning("[SurfaceAudioManager] Surfaces plugin not enabled — footstep bank will be generic")


func detect_under_player(player: CollisionObject3D) -> String:
	if not is_ready or player == null:
		return ""
	var detected: String = SURFACES_SCRIPT.detect(player)
	if detected != last_surface:
		last_surface = detected
		surface_changed.emit(detected)
	return detected


func play_footstep(player: CollisionObject3D) -> void:
	var surface: String = detect_under_player(player)
	var bank: Array = SURFACE_FOOTSTEP_BANK.get(surface, SURFACE_FOOTSTEP_BANK[""])
	var first_existing: String = ""
	for path in bank:
		if ResourceLoader.exists(path):
			first_existing = path
			break
	if first_existing == "":
		# Fallback to first declared path so audio_manager can synthesize
		first_existing = bank[0]
	footstep_should_play.emit(surface, bank)
	if Engine.has_singleton("AudioManager") or autoload_exists("AudioManager"):
		# Hand off to existing audio autoload
		var am := get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.call("play_sfx", surface + "_footstep", bank)


func autoload_exists(name: String) -> bool:
	var tree_root := get_tree().root if get_tree() else null
	return tree_root != null and tree_root.has_node(name)

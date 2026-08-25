extends Node

# ECHO//LINE — Audio Manager (Enhanced)
# Music layers, ambient sounds, spatial audio

var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var ambient_volume: float = 0.5

var music_layers: Dictionary = {}  # name → AudioStreamPlayer
var ambient_players: Array[AudioStreamPlayer3D] = []
var sfx_pool: Array[AudioStreamPlayer] = []

var timeline_music: String = "past"
var harmony_level: float = 0.0


func _ready() -> void:
	_setup_audio_bus()
	EventBus.echo_propagated.connect(_on_echo_propagated)
	EventBus.match_started.connect(_on_match_started)


func _setup_audio_bus() -> void:
	# Audio bus setup (if available)
	pass


func _on_echo_propagated(echo_id: String, _loc_key: String, audio_cue: String, _visual: String, _deltas: Array) -> void:
	play_sfx(audio_cue)
	harmony_level = clamp(harmony_level + 0.1, 0.0, 1.0)
	_update_music_layers()


func _on_match_started(_id: String, _state: Dictionary) -> void:
	harmony_level = 0.0
	_update_music_layers()


func _update_music_layers() -> void:
	# In full build, blend music layers based on harmony_level
	# and timeline
	pass


func play_sfx(cue_name: String) -> void:
	# In full build, route to AudioStreamPlayer pool
	# For now, just log
	print("[Audio] SFX: ", cue_name)


func play_music(timeline: String) -> void:
	timeline_music = timeline


func set_master_volume(vol: float) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)


func linear_to_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return 20.0 * log(linear) / log(10.0)

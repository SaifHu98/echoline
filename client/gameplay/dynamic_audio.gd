extends Node

# ECHO//LINE — Dynamic Audio System
# Music layers that respond to game state, ambient sounds, spatial audio

@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 1.0
@export var ambient_volume: float = 0.5

var current_timeline_music: String = "present"
var harmony_level: float = 0.0  # 0-1, increases as team cooperates
var tension_level: float = 0.0  # 0-1, increases as catastrophe approaches
var music_layers: Dictionary = {}  # name → AudioStreamPlayer
var ambient_players: Array = []
var sfx_players_pool: Array = []
var current_audio_streams: Dictionary = {}


func _ready() -> void:
	_setup_audio_buses()
	_setup_music_layers()
	_setup_ambient_sounds()

	# Listen to game events
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)
	if EventBus.has_signal("catastrophe_updated"):
		EventBus.catastrophe_updated.connect(_on_catastrophe_updated)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("match_concluded"):
		EventBus.match_concluded.connect(_on_match_concluded)


func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	if AudioServer.get_bus_count() < 4:
		# Master
		AudioServer.add_bus(1)
		AudioServer.set_bus_name(1, "Music")
		AudioServer.add_bus(2)
		AudioServer.set_bus_name(2, "SFX")
		AudioServer.add_bus(3)
		AudioServer.set_bus_name(3, "Ambient")


func _setup_music_layers() -> void:
	# In production, load actual music files
	# For now, use placeholders
	pass


func _setup_ambient_sounds() -> void:
	# Ambient sounds: wind, water, birds, etc.
	pass


func _process(_delta: float) -> void:
	# Smoothly transition harmony/tension
	harmony_level = move_toward(harmony_level, 0.5, 0.01)
	tension_level = move_toward(tension_level, 0.0, 0.02)


# === Event Handlers ===
func _on_echo_propagated(echo_id: String, _loc_key: String, audio_cue: String, _visual: String, _deltas: Array) -> void:
	# Play echo sound
	play_sfx(audio_cue)
	# Increase harmony
	harmony_level = clamp(harmony_level + 0.15, 0.0, 1.0)


func _on_catastrophe_updated(remaining_ms: int, stability_pct: float, _stage: String) -> void:
	# Update tension based on time/stability
	var time_pressure = 1.0 - (float(remaining_ms) / 600000.0)
	var stability_pressure = 1.0 - (stability_pct / 100.0)
	tension_level = (time_pressure + stability_pressure) / 2.0
	tension_level = clamp(tension_level, 0.0, 1.0)


func _on_match_started(_id: String, _state: Dictionary) -> void:
	harmony_level = 0.0
	tension_level = 0.0


func _on_match_concluded(_recap: Dictionary) -> void:
	play_sfx("victory_fanfare" if tension_level < 0.7 else "tense_resolution")


# === Music Control ===
func set_timeline_music(timeline: String) -> void:
	current_timeline_music = timeline


func update_music() -> void:
	# Mix music layers based on harmony/tension
	# Higher harmony = fuller, warmer music
	# Higher tension = more intense, faster music
	pass


func play_music(name: String, fade_in: float = 2.0) -> void:
	pass


func stop_music(name: String, fade_out: float = 2.0) -> void:
	pass


# === SFX ===
func play_sfx(name: String, position: Vector3 = Vector3.ZERO, pitch: float = 1.0) -> void:
	# Spatial 3D if position given
	if position != Vector3.ZERO:
		_play_spatial_sfx(name, position, pitch)
	else:
		_play_2d_sfx(name, pitch)


func _play_2d_sfx(name: String, pitch: float) -> void:
	# Placeholder
	print("[Audio] 2D SFX: ", name, " (pitch: ", pitch, ")")
	# In production: AudioStreamPlayer.stream = load_audio(name), play()


func _play_spatial_sfx(name: String, position: Vector3, pitch: float) -> void:
	# Placeholder
	print("[Audio] 3D SFX: ", name, " at ", position, " (pitch: ", pitch, ")")
	# In production: spawn AudioStreamPlayer3D at position


# === Ambient ===
func set_ambient_volume(vol: float) -> void:
	ambient_volume = clamp(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(3, linear_to_db(ambient_volume))


# === Volume Controls ===
func set_master_volume(vol: float) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


func set_music_volume(vol: float) -> void:
	music_volume = clamp(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(1, linear_to_db(music_volume))


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clamp(vol, 0.0, 1.0)
	AudioServer.set_bus_volume_db(2, linear_to_db(sfx_volume))


func linear_to_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


# === Adaptive Sounds ===
func play_interaction_sound(success: bool) -> void:
	if success:
		play_sfx("interact_success", Vector3.ZERO, 1.0)
	else:
		play_sfx("interact_fail", Vector3.ZERO, 0.8)


func play_timeline_shift(from: String, to: String) -> void:
	play_sfx("timeline_shift_" + to, Vector3.ZERO, 1.0)


func play_warning() -> void:
	play_sfx("warning_beep", Vector3.ZERO, 1.2)

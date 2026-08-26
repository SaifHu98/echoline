extends Node

# ECHO//LINE — Sound FX Placeholder System
# Use this until you install Sound FX Starter Pack from AssetStore.
# After installing, place .ogg files in `client/audio/sfx/` and this script
# will auto-detect them.

const SFX_PATHS := {
	# UI
	"button_click": "res://audio/sfx/ui/button_click.ogg",
	"button_hover": "res://audio/sfx/ui/button_hover.ogg",
	"menu_open": "res://audio/sfx/ui/menu_open.ogg",
	"menu_close": "res://audio/sfx/ui/menu_close.ogg",
	"dialogue_advance": "res://audio/sfx/ui/dialogue_advance.ogg",

	# Echo / Gameplay
	"echo_pulse": "res://audio/sfx/gameplay/echo_pulse.ogg",
	"echo_resolve": "res://audio/sfx/gameplay/echo_resolve.ogg",
	"echo_ripple": "res://audio/sfx/gameplay/echo_ripple.ogg",
	"shard_collect": "res://audio/sfx/gameplay/shard_collect.ogg",
	"shard_place": "res://audio/sfx/gameplay/shard_place.ogg",
	"anchor_complete": "res://audio/sfx/gameplay/anchor_complete.ogg",
	"timeline_swap": "res://audio/sfx/gameplay/timeline_swap.ogg",

	# Catastrophe
	"catastrophe_warning": "res://audio/sfx/catastrophe/warning.ogg",
	"catastrophe_critical": "res://audio/sfx/catastrophe/critical.ogg",
	"catastrophe_end": "res://audio/sfx/catastrophe/end.ogg",

	# Ambient
	"amb_past_wind": "res://audio/sfx/ambient/past_wind.ogg",
	"amb_past_church": "res://audio/sfx/ambient/past_church_bells.ogg",
	"amb_present_city": "res://audio/sfx/ambient/present_city.ogg",
	"amb_present_clock": "res://audio/sfx/ambient/present_clock_tick.ogg",
	"amb_future_hum": "res://audio/sfx/ambient/future_hum.ogg",
	"amb_future_energy": "res://audio/sfx/ambient/future_energy_crackle.ogg"
}

# Fallback synthesized sounds (when .ogg files missing)
var _synth_cache: Dictionary = {}

func _ready() -> void:
	print("[SFXManager] Loaded. Missing sounds will use synthesized fallbacks.")
	# Preload any existing sound files
	for key in SFX_PATHS:
		if ResourceLoader.exists(SFX_PATHS[key]):
			# Preload to cache
			pass


func play(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	# Try to play real file
	if SFX_PATHS.has(sfx_name) and ResourceLoader.exists(SFX_PATHS[sfx_name]):
		_play_file(SFX_PATHS[sfx_name], volume_db, pitch_scale)
	else:
		# Fallback to synthesized sound
		_play_synthesized(sfx_name, volume_db)


func _play_file(path: String, volume_db: float, pitch_scale: float) -> void:
	# Real file playback using AudioStreamPlayer
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _play_synthesized(sfx_name: String, volume_db: float) -> void:
	# Generate a procedural beep when .ogg file missing
	# (Helps during early development before buying Sound FX pack)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.1
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	print("[SFXManager] Synthesized fallback for: %s" % sfx_name)
	player.finished.connect(player.queue_free)


# === Predefined SFX Triggers in ECHO//LINE ===

func on_button_click() -> void:
	play("button_click", -6.0)


func on_button_hover() -> void:
	play("button_hover", -10.0)


func on_echo_pulse(timeline: String) -> void:
	match timeline:
		"past": play("amb_past_wind", -8.0)
		"present": play("amb_present_clock", -8.0)
		"future": play("amb_future_energy", -8.0)
		_: play("echo_pulse", -4.0)


func on_shard_collected() -> void:
	play("shard_collect", -3.0)


func on_anchor_completed() -> void:
	play("anchor_complete", -2.0)


func on_catastrophe_stage(stage: String) -> void:
	match stage:
		"destabilizing": play("catastrophe_warning", -3.0)
		"critical": play("catastrophe_critical", -2.0)
		"imminent": play("catastrophe_critical", 0.0)
		"stable": play("echo_resolve", -4.0)

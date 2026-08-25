extends Node

# Layered Timeline Audio Orchestrator & Visual Caption Provider

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 0.9

var active_timeline: String = "past"
var harmony_level: float = 0.0 # Gradually blends other timeline stems as players cooperate

func _ready() -> void:
	EventBus.echo_propagated.connect(_on_echo_propagated)

func play_sfx(cue_name: String, caption_loc_key: String = "") -> void:
	# In full Godot build, routes to AudioStreamPlayer pool with pitch variation
	if Accessibility.subtitles_enabled and caption_loc_key != "":
		var text = Localization.tr_key(caption_loc_key)
		EventBus.subtitle_requested.emit("[♪ " + text + "]", 2.5)

func play_echo(timeline: String) -> void:
	# Play an echo SFX for the given timeline
	var cue_map = {"past": "echo_past", "present": "echo_present", "future": "echo_future"}
	play_sfx(cue_map.get(timeline, "echo_default"), "echo." + timeline)

func _on_echo_propagated(echo_id: String, loc_key: String, audio_cue: String, visual_ripple: String, deltas: Array) -> void:
	play_sfx(audio_cue, loc_key)
	harmony_level = clampf(harmony_level + 0.15, 0.0, 1.0)

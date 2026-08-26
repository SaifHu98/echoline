extends Node

# ECHO//LINE — Resonance Audio Setup (Phase 3, Nexus Resonance)
# Nexus Resonance (Michael Kulzer, MIT) is the Steam Audio GDExtension for
# Godot. It provides raytracing-based spatial audio with probe volumes,
# HRTF, occlusion, and reverb baking.
#
# Activation: enable "Nexus Resonance" in Project Settings → Plugins.
# Two requirements:
#   1. Steamworks SDK must be linked (only relevant if you publish on Steam).
#      For non-Steam builds, Resonance still works — it just doesn't need
#      Steam authentication.
#   2. The .gdextension auto-registers native classes like ResonanceProbeVolume,
#      ResonancePlayer, ResonanceAudioEffect.
#
# ECHO//LINE scope: WRAPPER ONLY. The actual audio probe baking, HRTF
# convolution, and Steam Audio geometry import require SOFA files and a
# substantial audio budget. This wrapper exposes the bootstrap so future
# audio designers can add resonance to a scene without learning the API.

const NEXUS_BASE := "res://addons/nexus_resonance"
const RESONANCE_AUDIO_EFFECT_SCRIPT := "res://addons/nexus_resonance/scripts/resonance_audio_effect.gd"

var is_ready: bool = false
var is_steam_linked: bool = false

signal resonance_bake_complete(quality: int)


func _ready() -> void:
	is_ready = ClassDB.class_exists("ResonanceProbeVolume") or FileAccess.file_exists(
		"res://addons/nexus_resonance/nexus_resonance.gdextension")
	if not is_ready:
		push_warning("[ResonanceAudio] Nexus Resonance GDExtension not loaded")
		return
	is_steam_linked = FileAccess.file_exists("user://steam_appid.txt") \
		or OS.has_feature("steam")
	print("[ResonanceAudio] Resonance API available (steam_linked=%s)" % is_steam_linked)


func apply_to_audio_bus(bus_name: String) -> bool:
	if not is_ready:
		return false
	if not ClassDB.class_exists("ResonanceAudioEffect"):
		return false
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_error("[ResonanceAudio] Bus '%s' not found" % bus_name)
		return false
	# Insert the resonance effect at the start of the bus chain.
	var effect_count: int = AudioServer.get_bus_effect_count(bus_idx)
	var effect_script: Script = load(RESONANCE_AUDIO_EFFECT_SCRIPT) if FileAccess.file_exists(
		RESONANCE_AUDIO_EFFECT_SCRIPT) else null
	if effect_script == null:
		# Native class — instantiate via ClassDB.
		var effect: AudioEffect = ClassDB.instantiate("ResonanceAudioEffect")
		if effect:
			AudioServer.add_bus_effect(bus_idx, effect)
			return true
	return false


func bake_probe_volume(_volume_path: String, quality: int = 2) -> void:
	# The actual bake requires the editor running. This is a stub for
	# designers — call from an editor script or via a menu shortcut.
	if not is_ready:
		push_warning("[ResonanceAudio] Cannot bake; addon not enabled")
		return
	# Real implementation would call:
	#   ResonanceBakeRunner.bake(volume_path, quality)
	# This stub emits the signal so listeners (e.g., a progress bar in the
	# main menu) can react.
	resonance_bake_complete.emit(quality)


func get_supported_features() -> Array:
	# Steam Audio features supported in this build.
	return [
		"HRTF",
		"Probe-based reverb",
		"Pathing simulation",
		"Material-based occlusion",
		"Dynamic obstruction",
	]

extends Node

# ECHO//LINE — Reactive UI State (Phase 3, Reactive Signal)
# Wraps Reactive Signal v1.0 (iamyoki, MIT) — a SolidJS-like reactive primitive
# for GDScript. Activation: enable "Reactive Signal" in Project Settings →
# Plugins (registers the global class_name "ReactiveSignal" + SignalContext,
# SignalEffect, SignalBinder nodes).
#
# Use case: a reactive player_state signal that the HUD automatically re-binds
# to (without manually disconnecting/reconnecting Godot signals).

const ReactiveSignalScript := preload("res://addons/reactive_signal/reactive_signal.gd")
const SignalContextScript := preload("res://addons/reactive_signal/signal_context.gd")
const SignalEffectScript := preload("res://addons/reactive_signal/signal_effect.gd")
const SignalBinderScript := preload("res://addons/reactive_signal/signal_binder.gd")

var is_ready: bool = false
var context: Node = null

# Reactive signals exposed to the rest of the game.
var player_state: ReactiveSignal
var connection_state: ReactiveSignal
var match_phase: ReactiveSignal
var locale: ReactiveSignal


func _ready() -> void:
	is_ready = ClassDB.class_exists("ReactiveSignal")
	if not is_ready:
		push_warning("[ReactiveUIState] Reactive Signal plugin not enabled — falling back to EventBus")
		return
	context = SignalContextScript.new()
	context.name = "EchoUIContext"
	context.set("signals", {
		"player_state": {"hp": 100, "max_hp": 100, "shards": 0, "timeline": "present"},
		"connection_state": "disconnected",
		"match_phase": "lobby",
		"locale": "en",
	})
	add_child(context)
	player_state = context.get_signal("player_state")
	connection_state = context.get_signal("connection_state")
	match_phase = context.get_signal("match_phase")
	locale = context.get_signal("locale")
	print("[ReactiveUIState] Reactive Signal context active")


# === Convenience setters (auto-emit effects) ===

func set_player_hp(hp: int, max_hp: int) -> void:
	if not is_ready or player_state == null:
		return
	var dict: Dictionary = player_state.value
	dict["hp"] = hp
	dict["max_hp"] = max_hp
	player_state.value = dict


func set_shards(count: int) -> void:
	if not is_ready or player_state == null:
		return
	var dict: Dictionary = player_state.value
	dict["shards"] = count
	player_state.value = dict


func set_connection_state(state: String) -> void:
	if not is_ready or connection_state == null:
		return
	connection_state.value = state


func set_match_phase(phase: String) -> void:
	if not is_ready or match_phase == null:
		return
	match_phase.value = phase


func set_locale_signal(loc: String) -> void:
	if not is_ready or locale == null:
		return
	locale.value = loc

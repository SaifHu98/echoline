extends Node

# Local Game State Manager & Reconciler

var world_state: Dictionary = {}
var catastrophe_stability: float = 100.0
var catastrophe_stage: String = "stable"
var catastrophe_timer_seconds: int = 600

func _ready() -> void:
	EventBus.match_started.connect(_on_match_started)
	EventBus.echo_propagated.connect(_on_echo_propagated)
	EventBus.catastrophe_updated.connect(_on_catastrophe_updated)

func _on_match_started(_match_id: String, initial_state: Dictionary) -> void:
	world_state = initial_state.duplicate(true)

func _on_echo_propagated(_echo_id: String, _loc_key: String, _audio_cue: String, _visual_ripple: String, deltas: Array) -> void:
	for delta in deltas:
		var tl = delta.get("timeline", "")
		var ent = delta.get("entity", "")
		var prop = delta.get("property", "")
		var val = delta.get("value")

		if not world_state.has(tl):
			world_state[tl] = {}
		if not world_state[tl].has(ent):
			world_state[tl][ent] = {}

		world_state[tl][ent][prop] = val
		EventBus.state_delta_received.emit(delta)

func _on_catastrophe_updated(remaining_ms: int, stability_pct: float, stage: String) -> void:
	catastrophe_timer_seconds = int(remaining_ms / 1000.0)
	catastrophe_stability = stability_pct
	catastrophe_stage = stage

func get_entity_property(timeline: String, entity: String, prop: String, default_val = null):
	if world_state.has(timeline) and world_state[timeline].has(entity) and world_state[timeline][entity].has(prop):
		return world_state[timeline][entity][prop]
	return default_val


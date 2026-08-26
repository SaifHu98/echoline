extends Node

# ECHO//LINE — HUD State Chart (Phase 2, Godot State Charts)
# Replaces the existing if/else HUD mode logic with a real state chart.
# Activation: enable "Godot State Charts" in Project Settings → Plugins.
# Adds the "StateChart" node type, usable as @tool or runtime.
#
# The chart drives HUD behavior through 4 states:
#   - HIDDEN (before match)
#   - MATCHING (match in progress)
#   - CAUSAL_RECAP (post-match recap)
#   - DISCONNECTED (server unreachable)
#
# Transitions:
#   HIDDEN → MATCHING on "match_started"
#   MATCHING → CAUSAL_RECAP on "match_ended"
#   * → DISCONNECTED on "server_disconnected"
#   DISCONNECTED → HIDDEN on "server_reconnected"

const StateChartScript := preload("res://addons/godot_state_charts/state_chart.gd")
const AtomicStateScript := preload("res://addons/godot_state_charts/atomic_state.gd")
const CompoundStateScript := preload("res://addons/godot_state_charts/compound_state.gd")
const TransitionScript := preload("res://addons/godot_state_charts/transition.gd")

enum HudState { HIDDEN, MATCHING, CAUSAL_RECAP, DISCONNECTED }

var chart: Node = null
var is_ready: bool = false
var _current_state: int = HudState.HIDDEN

signal hud_state_changed(new_state: int)


func _ready() -> void:
	is_ready = ClassDB.class_exists("StateChart")
	if not is_ready:
		push_warning("[HudStateChart] Godot State Charts not enabled — falling back to if/else")
		return
	_build_chart()
	_bind_signals()


func _build_chart() -> void:
	chart = StateChartScript.new()
	chart.name = "HUDChart"
	add_child(chart)
	# Root state: compound
	var root: Node = CompoundStateScript.new()
	root.name = "Root"
	chart.add_child(root)
	# Atomic sub-states
	for st_name in ["Hidden", "Matching", "CausalRecap", "Disconnected"]:
		var st: Node = AtomicStateScript.new()
		st.name = st_name
		root.add_child(st)
	# Transitions
	_add_transition(root, "Hidden", "match_started", "Matching")
	_add_transition(root, "Matching", "match_ended", "CausalRecap")
	_add_transition(root, "Hidden", "server_disconnected", "Disconnected")
	_add_transition(root, "Matching", "server_disconnected", "Disconnected")
	_add_transition(root, "CausalRecap", "server_disconnected", "Disconnected")
	_add_transition(root, "Disconnected", "server_reconnected", "Hidden")
	_add_transition(root, "CausalRecap", "player_dismissed", "Hidden")


func _add_transition(parent: Node, from_state: String, event: String, to_state: String) -> void:
	var from: Node = parent.get_node_or_null(from_state)
	if from == null:
		return
	var t: Node = TransitionScript.new()
	t.event = event
	t.to = "Root/" + to_state
	from.add_child(t)


func _bind_signals() -> void:
	# StateChart emits "state_entered" / "state_exited" via the chart itself.
	if chart and chart.has_signal("event_received"):
		chart.event_received.connect(_on_event_received)
	# Each AtomicState can have a "state_entered" signal in v0.22+; if not,
	# polling via set_process(true) reads chart.active_state_name.
	set_process(true)


func _process(_dt: float) -> void:
	if chart == null:
		return
	var active: String = ""
	if chart.has_method("get_active_state_name"):
		active = chart.call("get_active_state_name")
	var parsed: int = HudState.HIDDEN
	match active:
		"Root/Matching":
			parsed = HudState.MATCHING
		"Root/CausalRecap":
			parsed = HudState.CAUSAL_RECAP
		"Root/Disconnected":
			parsed = HudState.DISCONNECTED
		_:
			parsed = HudState.HIDDEN
	if parsed != _current_state:
		_current_state = parsed
		hud_state_changed.emit(parsed)


func _on_event_received(event: StringName) -> void:
	pass


# === Public API ===

func send_event(event_name: String) -> void:
	if chart and chart.has_method("send_event"):
		chart.call("send_event", event_name)


func get_current_state() -> int:
	return _current_state

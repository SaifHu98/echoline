class_name InteractiveProp
extends Node3D

# ECHO//LINE — Interactive Prop Base Class
# All interactive objects in the world inherit from this

signal interacted(player: Node3D, prop_id: String, action: String)
signal focused_changed(focused: bool)

@export var prop_id: String = ""
@export var display_name: String = ""
@export var action_name: String = "Interact"
@export var interaction_text: String = ""
@export var requires_timeline: String = ""  # "past" | "present" | "future" | ""
@export var cooldown: float = 1.0
@export var one_time_use: bool = false

var is_focused: bool = false
var is_used: bool = false
var last_used_time: float = 0.0
var outline_mesh: MeshInstance3D = null


func _ready() -> void:
	add_to_group("interactable")
	_create_outline()


func _create_outline() -> void:
	# Outline effect when focused
	pass


func interact(player: Node3D) -> void:
	if not _can_interact(player):
		return
	last_used_time = Time.get_ticks_msec()
	if one_time_use:
		is_used = true
	interacted.emit(player, prop_id, action_name)
	_on_interact(player)


func _can_interact(player: Node3D) -> bool:
	if is_used and one_time_use:
		return false
	if Time.get_ticks_msec() - last_used_time < cooldown * 1000:
		return false
	if requires_timeline != "" and NetworkClient.my_timeline != requires_timeline:
		return false
	return true


func set_focused(focused: bool) -> void:
	if is_focused == focused:
		return
	is_focused = focused
	focused_changed.emit(focused)
	_on_focus_changed(focused)


func get_interaction_text() -> String:
	if is_used and one_time_use:
		return display_name + " (Used)"
	if requires_timeline != "" and NetworkClient.my_timeline != requires_timeline:
		return display_name + " (" + requires_timeline.to_upper() + " Only)"
	return action_name + " " + display_name


# Override these in subclasses
func _on_interact(_player: Node3D) -> void:
	pass


func _on_focus_changed(_focused: bool) -> void:
	pass

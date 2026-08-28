extends Node3D

# ECHO//LINE — Base Interactive Prop
# ===================================
# All timeline-specific interactive objects (debris, soil, mechanisms) extend
# this. Provides common fields + interaction signal plumbing.

signal interacted(player: Node3D)
signal focused(focused: bool)

var prop_id: String = ""
var display_name: String = ""
var action_name: String = "Interact"
var requires_timeline: String = ""  # "past" | "present" | "future" | "" = any


func _ready() -> void:
	# Subclasses override this to do their specific setup; we just announce
	# availability to the building system.
	if prop_id != "":
		print("[InteractiveProp] ready: %s (%s)" % [prop_id, requires_timeline])


func interact(player: Node3D) -> void:
	if not _can_interact(player):
		return
	_on_interact(player)
	interacted.emit(player)


func _on_interact(_player: Node3D) -> void:
	# Override in subclasses.
	pass


func _on_focus_changed(focused: bool) -> void:
	# Override in subclasses to react to focus.
	emit_signal("focused", focused)


func _can_interact(player: Node3D) -> bool:
	if requires_timeline == "":
		return true
	if player == null:
		return false
	if not "timeline" in player:
		return true
	return player.timeline == requires_timeline

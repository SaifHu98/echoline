extends Node

# ECHO//LINE — Dialogue Service (Phase 1, real Dialogue Manager)
# Wraps Dialogue Manager v4.0.3 (Nathan Hoad, MIT).
# Activation: enable "Dialogue Manager" plugin in
#   Project → Project Settings → Plugins
#
# Public API:
#   dialogue_service.play("intro_echo")
#   dialogue_service.play_label("Clockmaker Greeting")
#   dialogue_service.on_line(display_who, display_text)
#   dialogue_service.on_choice(index, text)

const DialogueManagerScript := preload("res://addons/dialogue_manager/dialogue_manager.gd")

const ECHO_GREETINGS := "res://data/dialogues/echo_greetings.dialogue"

signal line_spoken(who: String, text: String)
signal choice_offered(choices: Array)
signal dialogue_finished(label: String)
signal dialogue_started(label: String)

var is_ready: bool = false
var _current_label: String = ""


func _ready() -> void:
	is_ready = ClassDB.class_exists("DialogueManager")
	if not is_ready:
		push_warning("[DialogueService] Dialogue Manager not enabled — dialogue lines print to console only")
		return
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	if not DialogueManager.got_dialogue.is_connected(_on_got_dialogue):
		DialogueManager.got_dialogue.connect(_on_got_dialogue)
	print("[DialogueService] Dialogue Manager API available")


# === Public play API ===

func play(label: String) -> void:
	if not is_ready:
		print("[DialogueService] (no DialogueManager) %s" % label)
		dialogue_finished.emit(label)
		return
	if not ResourceLoader.exists(ECHO_GREETINGS):
		push_error("[DialogueService] Dialogue file missing: %s" % ECHO_GREETINGS)
		return
	_current_label = label
	dialogue_started.emit(label)
	# show_dialogue_balloon_scene signature:
	#   (balloon_scene: Variant, resource: DialogueResource, cue: String, extra_game_states: Array)
	# balloon_scene=null uses the default balloon; resource must be loaded.
	var resource: Resource = load(ECHO_GREETINGS)
	if resource == null:
		push_error("[DialogueService] Could not load dialogue resource: " + ECHO_GREETINGS)
		return
	DialogueManager.show_dialogue_balloon_scene(null, resource, label)


func play_with_balloon(label: String, balloon_scene: PackedScene) -> void:
	if not is_ready:
		dialogue_finished.emit(label)
		return
	var resource: Resource = load(ECHO_GREETINGS)
	if resource == null:
		push_error("[DialogueService] Could not load dialogue resource: " + ECHO_GREETINGS)
		return
	DialogueManager.show_dialogue_balloon_scene(balloon_scene, resource, label)


func play_raw(title: String, lines: Array) -> void:
	# Fallback: show a simple custom balloon built in Godot.
	# Used when the dialogue file isn't authored yet but we still want
	# players to see the line.
	for entry in lines:
		var who: String = entry.get("who", "Echo")
		var text: String = entry.get("text", "")
		line_spoken.emit(who, text)
		await get_tree().create_timer(2.5).timeout
	dialogue_finished.emit(title)


# === Signal handlers ===

func _on_got_dialogue(resource: DialogueResource) -> void:
	# Hook for analytics: track which dialogue resource was opened.
	pass


func _on_dialogue_ended(resource: DialogueResource) -> void:
	dialogue_finished.emit(_current_label)
	_current_label = ""


# === Convenience for intro cinematic ===

func play_intro_echo() -> void:
	play("intro_echo")


func play_clockmaker_greeting() -> void:
	play("clockmaker_greeting")


func play_tutorial_intro() -> void:
	play("tutorial_intro")

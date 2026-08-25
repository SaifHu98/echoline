class_name BranchingDialogueController
extends RTLPanel

# Dynamic Branching Dialogue Engine for Mode D (Two-Player Story Mode)

signal dialogue_choice_selected(choice_id: String, echo_trigger: String)
signal dialogue_completed(node_id: String)

@onready var speaker_label: Label = $VBox/SpeakerLabel
@onready var dialogue_text: Label = $VBox/DialogueText
@onready var choices_container: VBoxContainer = $VBox/ChoicesContainer

var dialogue_graph: Dictionary = {}
var current_node_id: String = ""

func load_story_dialogue(graph_data: Dictionary) -> void:
	dialogue_graph = graph_data

func display_node(node_id: String) -> void:
	current_node_id = node_id
	if not dialogue_graph.has(node_id):
		visible = false
		dialogue_completed.emit(node_id)
		return

	var node = dialogue_graph[node_id]
	speaker_label.text = Localization.tr_key(node.get("speaker_loc_key", ""))
	dialogue_text.text = Localization.tr_key(node.get("text_loc_key", ""))

	for child in choices_container.get_children():
		child.queue_free()

	var choices = node.get("choices", [])
	if choices.is_empty():
		var continue_btn = RTLButton.new()
		continue_btn.set_loc_key("menu.play")
		continue_btn.pressed.connect(func(): display_node(node.get("next_node_id", "")))
		choices_container.add_child(continue_btn)
	else:
		for choice in choices:
			var btn = RTLButton.new()
			btn.set_loc_key(choice.get("loc_key", ""))
			btn.pressed.connect(func():
				var echo_id = choice.get("echo_trigger", "")
				if echo_id != "":
					NetworkClient.send_intent(echo_id)
				dialogue_choice_selected.emit(choice.get("id", ""), echo_id)
				display_node(choice.get("next_node_id", ""))
			)
			choices_container.add_child(btn)

	visible = true

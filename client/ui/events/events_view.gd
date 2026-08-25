class_name LiveOpsEventsView
extends Control

# LiveOps Tournament Rankings & Quests View

@onready var event_title: Label = $Panel/VBox/EventTitle
@onready var event_desc: Label = $Panel/VBox/EventDesc
@onready var quests_container: VBoxContainer = $Panel/VBox/QuestsList
@onready var leaderboard_container: VBoxContainer = $Panel/VBox/LeaderboardList
@onready var close_btn: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)
	visible = false

func render_event(event_data: Dictionary, rankings: Array) -> void:
	event_title.text = Localization.tr_key(event_data.get("title_key", ""))
	event_desc.text = Localization.tr_key(event_data.get("description_key", ""))

	for child in quests_container.get_children():
		child.queue_free()
	for child in leaderboard_container.get_children():
		child.queue_free()

	# Render Quests
	for quest in event_data.get("quests", []):
		var q_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		var q_title = Label.new()
		q_title.text = Localization.tr_key(quest.get("title_key", ""))
		q_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(q_title)

		var claim_btn = RTLButton.new()
		claim_btn.text = "Claim"
		hbox.add_child(claim_btn)

		q_panel.add_child(hbox)
		quests_container.add_child(q_panel)

	# Render Rankings
	for entry in rankings:
		var r_label = Label.new()
		r_label.text = "#" + str(entry.get("rank", 1)) + " " + entry.get("displayName", "Player") + " — " + str(entry.get("score", 0)) + "s"
		leaderboard_container.add_child(r_label)

	visible = true

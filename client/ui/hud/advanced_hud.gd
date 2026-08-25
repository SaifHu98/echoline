extends Control

# ECHO//LINE — Advanced HUD
# Mini-map, Quest tracker, Inventory, Action bar

@onready var minimap: Control = $RightPanel/Minimap
@onready var minimap_bg: ColorRect = $RightPanel/Minimap/MinimapBG
@onready var minimap_player: ColorRect = $RightPanel/Minimap/PlayerDot
@onready var quest_panel: PanelContainer = $LeftPanel/QuestTracker
@onready var quest_list: VBoxContainer = $LeftPanel/QuestTracker/VBox/QuestList
@onready var inventory_panel: PanelContainer = $BottomRight/Inventory
@onready var inventory_slots: Array[ColorRect] = []
@onready var action_bar: HBoxContainer = $BottomBar/ActionBar
@onready var hint_label: Label = $BottomBar/HintLabel
@onready var interaction_prompt: Control = $InteractionPrompt
@onready var prompt_label: Label = $InteractionPrompt/PromptLabel

var quests: Array = []
var inventory: Array = []
var hint_timer: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	# Fade in
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

	# Setup inventory slots
	for i in range(8):
		var slot_path = "BottomRight/Inventory/Slot" + str(i)
		if has_node(slot_path):
			inventory_slots.append(get_node(slot_path))

	# Subscribe to events
	if EventBus.has_signal("quest_updated"):
		EventBus.quest_updated.connect(_on_quest_updated)
	if EventBus.has_signal("inventory_changed"):
		EventBus.inventory_changed.connect(_on_inventory_changed)
	if EventBus.has_signal("interact_requested"):
		EventBus.interact_requested.connect(_on_interact_prompt)
	if EventBus.has_signal("subtitle_requested"):
		EventBus.subtitle_requested.connect(_on_subtitle)


func _process(delta: float) -> void:
	_update_minimap()

	if hint_timer > 0:
		hint_timer -= delta
		if hint_timer <= 0:
			$BottomBar/HintLabel.visible = false


func _update_minimap() -> void:
	# Get player position
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var pos = player.global_position
	# Map world coordinates to minimap
	# World: -25 to 25 → minimap 0 to 180
	var map_size = 180.0
	var world_range = 30.0
	var mx = (pos.x / world_range + 0.5) * map_size
	var mz = (pos.z / world_range + 0.5) * map_size
	minimap_player.position = Vector2(mx - 5, mz - 5)


func _on_quest_updated(quest_data: Dictionary) -> void:
	quests = quest_data.get("quests", [])
	_refresh_quests()


func _refresh_quests() -> void:
	for child in quest_list.get_children():
		child.queue_free()

	for quest in quests:
		var label = Label.new()
		label.text = "• " + quest.get("title", "Unknown")
		if quest.get("completed", false):
			label.modulate = Color(0.5, 1.0, 0.5, 0.6)
			label.text = "✓ " + quest.get("title", "")
		else:
			var progress = quest.get("progress", 0)
			var total = quest.get("total", 1)
			label.text = "• " + quest.get("title", "") + " (" + str(progress) + "/" + str(total) + ")"
		label.add_theme_font_size_override("font_size", 16)
		quest_list.add_child(label)


func _on_inventory_changed(items: Array) -> void:
	inventory = items
	_refresh_inventory()


func _refresh_inventory() -> void:
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		if i < inventory.size():
			var item = inventory[i]
			slot.color = item.get("color", Color.GRAY)
			slot.modulate = Color.WHITE
		else:
			slot.color = Color(0.15, 0.15, 0.2, 0.7)
			slot.modulate = Color(0.7, 0.7, 0.7, 0.5)


func _on_interact_prompt(text: String) -> void:
	prompt_label.text = text
	interaction_prompt.visible = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if prompt_label.text == text:
			interaction_prompt.visible = false
	)


func _on_subtitle(text: String, duration: float) -> void:
	hint_label.text = text
	hint_label.visible = true
	hint_timer = duration


func show_hint(text: String, duration: float = 3.0) -> void:
	hint_label.text = text
	hint_label.visible = true
	hint_timer = duration

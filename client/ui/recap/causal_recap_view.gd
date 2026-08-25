class_name CausalRecapView
extends Control

# End-of-Match Causal Timeline Tree Visualizer

@onready var outcome_title: Label = $Panel/VBox/OutcomeTitle
@onready var outcome_desc: Label = $Panel/VBox/OutcomeDesc
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var tree_container: VBoxContainer = $Panel/VBox/Scroll/TreeContainer
@onready var return_btn: Button = $Panel/VBox/ReturnButton

func _ready() -> void:
	EventBus.match_concluded.connect(_on_match_concluded)
	if return_btn:
		return_btn.pressed.connect(func(): visible = false)
	visible = false

func _on_match_concluded(recap: Dictionary) -> void:
	visible = true
	_render_recap(recap)

func _render_recap(recap: Dictionary) -> void:
	var outcome_key = recap.get("outcome_key", "outcome.city_saved")
	var grade = recap.get("outcome_grade", "major_success")
	var duration = recap.get("duration_seconds", 0)
	var total = recap.get("total_echoes", 0)

	outcome_title.text = Localization.tr_key("recap.title")
	outcome_desc.text = Localization.tr_key(outcome_key)
	
	match grade:
		"perfect": outcome_desc.modulate = Color.GOLD
		"major_success": outcome_desc.modulate = Color("#00E5FF")
		"partial_success": outcome_desc.modulate = Color.ORANGE
		_: outcome_desc.modulate = Color.RED

	stats_label.text = Localization.tr_key("recap.branch_count", { "count": total }) + " | " + Localization.tr_key("recap.time_elapsed", { "seconds": duration })
	if return_btn:
		return_btn.text = Localization.tr_key("recap.back_to_menu")

	for child in tree_container.get_children():
		child.queue_free()

	var nodes = recap.get("nodes", [])
	for node_data in nodes:
		var item_panel = PanelContainer.new()
		var hbox = HBoxContainer.new()
		var tl = node_data.get("source_timeline", "past")
		var tl_type = Types.string_to_timeline(tl)
		
		var icon_lbl = Label.new()
		icon_lbl.text = Types.get_timeline_symbol(tl_type)
		icon_lbl.modulate = Types.get_timeline_color(tl_type)
		hbox.add_child(icon_lbl)

		var time_lbl = Label.new()
		time_lbl.text = "[" + str(node_data.get("timestamp_relative_sec", 0)) + "s] "
		time_lbl.modulate = Color.GRAY
		hbox.add_child(time_lbl)

		var desc_lbl = Label.new()
		var loc_k = node_data.get("loc_key", "")
		desc_lbl.text = Localization.tr_key(loc_k)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(desc_lbl)

		item_panel.add_child(hbox)
		tree_container.add_child(item_panel)

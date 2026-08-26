extends Control

# ECHO//LINE — Causal Timeline Recap (End-of-Match)
# Shown after match concludes

@onready var outcome_title: Label = $Panel/VBox/OutcomeTitle
@onready var outcome_desc: Label = $Panel/VBox/OutcomeDesc
@onready var stats_label: Label = $Panel/VBox/StatsLabel
@onready var return_btn: Button = $Panel/VBox/ReturnButton
@onready var tree_container: VBoxContainer = $Panel/VBox/Scroll/TreeContainer
@onready var panel: PanelContainer = $Panel

var current_locale: String = "en"

func _ready() -> void:
	modulate.a = 1.0
	if panel:
		panel.modulate.a = 1.0

	# Apply current locale
	_apply_current_locale()

	# Connect to match conclusion
	if EventBus.has_signal("match_concluded"):
		EventBus.match_concluded.connect(_on_match_concluded)
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	if return_btn:
		_connect_button_safely(return_btn, _on_return_pressed)


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
	btn.pressed.connect(callback)


func _apply_current_locale() -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		current_locale = loc.get_current_locale()


func _on_locale_changed(new_locale: String, _is_rtl: bool) -> void:
	current_locale = new_locale


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


func _on_match_concluded(recap: Dictionary) -> void:
	visible = true
	_populate(recap)


func _populate(recap: Dictionary) -> void:
	var outcome = recap.get("outcome", "harmony")
	var total = recap.get("branchesResolved", 0)
	var duration = recap.get("durationSeconds", 0)

	if outcome_title:
		match outcome:
			"perfect_harmony":
				outcome_title.text = _tr("outcome.perfect_restoration", "✨ Perfect Harmony ✨")
				outcome_title.modulate = Color(1, 0.95, 0.4, 1)
			"good":
				outcome_title.text = _tr("outcome.city_saved", "✓ Timeline Stabilized")
				outcome_title.modulate = Color(0.5, 1, 0.5, 1)
			"partial":
				outcome_title.text = "⚠ Partial Recovery"
				outcome_title.modulate = Color(1, 0.85, 0.3, 1)
			"failure":
				outcome_title.text = _tr("outcome.temporal_erasure", "✗ Catastrophe")
				outcome_title.modulate = Color(1, 0.4, 0.4, 1)
			_:
				outcome_title.text = "Match Complete"

	if outcome_desc:
		outcome_desc.text = recap.get("description", "Echoes have been resolved across timelines.")

	if stats_label:
		stats_label.text = _tr("recap.branch_count", "Branches resolved: {count}").replace("{count}", str(total)) + "  •  " + _tr("recap.time_elapsed", "Time: {seconds}s").replace("{seconds}", str(duration))

	# Populate tree
	if tree_container:
		for child in tree_container.get_children():
			child.queue_free()
		var branches = recap.get("branches", [])
		for branch in branches:
			var lbl = Label.new()
			lbl.text = "  →  " + str(branch.get("label", "Echo"))
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.modulate = Color(0.8, 0.85, 0.95, 1)
			tree_container.add_child(lbl)


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
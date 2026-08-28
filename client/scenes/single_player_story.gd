extends Control

const ModernTheme := preload("res://ui/modern_theme.gd")

var locale := "en"
var campaign: Node = null
var chapters_box: VBoxContainer
var detail_box: VBoxContainer
var selected_index := 0
var title_label: Label
var subtitle_label: Label


func _ready() -> void:
	campaign = get_node_or_null("/root/SinglePlayerCampaign")
	var loc := get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		locale = loc.get_current_locale()
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)
	_build_page()


func _tr(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Localization")
	if loc and loc.has_method("tr_key"):
		var translated: String = loc.tr_key(key)
		return fallback if translated == "[" + key + "]" else translated
	return fallback


func _localized(value: Variant) -> String:
	if value is Dictionary:
		return str(value.get(locale, value.get("en", "")))
	return str(value)


func _build_page() -> void:
	for child in get_children():
		child.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = ModernTheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var accent := ColorRect.new()
	accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent.offset_bottom = 210
	accent.color = Color(0.16, 0.08, 0.25, 0.34)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 16)
	safe.add_theme_constant_override("margin_right", 16)
	safe.add_theme_constant_override("margin_top", 14)
	safe.add_theme_constant_override("margin_bottom", 14)
	add_child(safe)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	safe.add_child(page)

	var topbar := HBoxContainer.new()
	topbar.custom_minimum_size.y = 60
	topbar.add_theme_constant_override("separation", 10)
	page.add_child(topbar)
	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(58, 56)
	ModernTheme.style_button(back, ModernTheme.PINK)
	back.pressed.connect(_go_back)
	topbar.add_child(back)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(heading)
	title_label = ModernTheme.label(_tr("story.title", "THE LAST CHIME"), 25, ModernTheme.TEXT)
	heading.add_child(title_label)
	subtitle_label = ModernTheme.label(_tr("story.subtitle", "A long-form journey across twelve fractured chapters"), 12, ModernTheme.MUTED)
	heading.add_child(subtitle_label)
	var chapter_count: int = campaign.get_chapter_count() if campaign else 0
	var count: Label = ModernTheme.label("%d CHAPTERS" % chapter_count, 12, ModernTheme.GOLD)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topbar.add_child(count)

	var scroll := ScrollContainer.new()
	ModernTheme.configure_scroll(scroll)
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var intro := PanelContainer.new()
	intro.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.07, 0.11, 0.2, 0.98), 20, Color(0.48, 0.33, 0.73, 0.8)))
	content.add_child(intro)
	var intro_margin := MarginContainer.new()
	intro_margin.add_theme_constant_override("margin_left", 20)
	intro_margin.add_theme_constant_override("margin_right", 20)
	intro_margin.add_theme_constant_override("margin_top", 16)
	intro_margin.add_theme_constant_override("margin_bottom", 16)
	intro.add_child(intro_margin)
	var intro_copy := ModernTheme.label(_tr("story.intro", "A city is losing its memories. Walk through the fracture, solve its mysteries, and decide what deserves to survive."), 15, ModernTheme.TEXT)
	intro_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_margin.add_child(intro_copy)

	content.add_child(ModernTheme.section_title(_tr("story.chapters", "CHAPTER SELECT")))
	chapters_box = VBoxContainer.new()
	chapters_box.add_theme_constant_override("separation", 8)
	content.add_child(chapters_box)
	content.add_child(ModernTheme.section_title(_tr("story.journal", "ACTIVE CHAPTER JOURNAL")))
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 8)
	content.add_child(detail_box)
	_refresh_chapters()


func _refresh_chapters() -> void:
	if not chapters_box or not is_instance_valid(chapters_box):
		return
	for child in chapters_box.get_children():
		child.queue_free()
	var count: int = campaign.get_chapter_count() if campaign else 0
	for index in range(count):
		var chapter: Dictionary = campaign.get_chapter(index)
		var progress: Dictionary = campaign.get_chapter_progress(index)
		var unlocked: bool = campaign.is_chapter_unlocked(index)
		var button := Button.new()
		button.custom_minimum_size.y = 76
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var marker := "◆" if unlocked else "◇"
		var progress_text := "%d/%d" % [int(progress.get("completed", 0)), int(progress.get("total", 0))]
		button.text = "%s  %02d  %s\n      %s   ·   %s" % [marker, index + 1, _localized(chapter.get("title", {})), _localized(chapter.get("subtitle", {})), progress_text]
		button.disabled = not unlocked
		ModernTheme.style_button(button, ModernTheme.GOLD if index == selected_index else ModernTheme.CYAN, index == selected_index)
		button.pressed.connect(_select_chapter.bind(index))
		chapters_box.add_child(button)
	if count > 0:
		selected_index = clamp(selected_index, 0, count - 1)
		_refresh_details()


func _select_chapter(index: int) -> void:
	selected_index = index
	_refresh_chapters()


func _refresh_details() -> void:
	if not detail_box or not campaign:
		return
	for child in detail_box.get_children():
		child.queue_free()
	var chapter: Dictionary = campaign.get_chapter(selected_index)
	var progress: Dictionary = campaign.get_chapter_progress(selected_index)
	var header := ModernTheme.label("%02d  %s" % [selected_index + 1, _localized(chapter.get("title", {}))], 22, ModernTheme.TEXT)
	detail_box.add_child(header)
	detail_box.add_child(ModernTheme.label(_localized(chapter.get("subtitle", {})), 14, ModernTheme.MUTED))
	var missions: Array = chapter.get("missions", [])
	for mission_index in range(missions.size()):
		var mission = missions[mission_index]
		if not mission is Dictionary:
			continue
		var mission_id: String = campaign.get_mission_id(mission, mission_index)
		var done: bool = campaign.is_mission_complete(selected_index, mission_id)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.06, 0.12, 0.2, 0.96), 14, ModernTheme.SUCCESS if done else Color("294361")))
		detail_box.add_child(row)
		var text := ModernTheme.label(("✓  " if done else "○  ") + _localized(mission.get("title", {})) + "\n    " + _localized(mission.get("task", {})), 14, ModernTheme.SUCCESS if done else ModernTheme.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(text)
	var start := Button.new()
	start.custom_minimum_size.y = 64
	start.text = _tr("story.begin", "BEGIN CHAPTER")
	start.disabled = not campaign.is_chapter_unlocked(selected_index)
	ModernTheme.style_button(start, ModernTheme.GOLD, true)
	start.pressed.connect(_begin_selected)
	detail_box.add_child(start)
	detail_box.add_child(ModernTheme.label(_tr("story.progress", "Progress: {done}/{total}").format({"done": progress.get("completed", 0), "total": progress.get("total", 0)}), 13, ModernTheme.CYAN))


func _begin_selected() -> void:
	if campaign and campaign.begin_chapter(selected_index):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_locale_changed(new_locale: String, _is_rtl: bool) -> void:
	locale = new_locale
	_build_page()

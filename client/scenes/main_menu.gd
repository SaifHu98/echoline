extends Control

# ECHO//LINE — Modern responsive main menu.
# The legacy nodes remain in main_menu.tscn for backwards-compatible smoke tests;
# the visible shell is built here so every viewport gets the same clean layout.

const ModernTheme := preload("res://ui/modern_theme.gd")
const STORY_SCENE := "res://scenes/single_player_story.tscn"

@onready var play_btn: Button = $SplitContainer/LeftPanel/LeftScroll/LeftVBox/PlayButton
@onready var tutorial_btn: Button = $SplitContainer/LeftPanel/LeftScroll/LeftVBox/TutorialButton
@onready var settings_btn: Button = $SplitContainer/RightPanel/RightScroll/RightVBox/SettingsButton
@onready var language_btn: Button = $SplitContainer/RightPanel/RightScroll/RightVBox/LanguageButton
@onready var credits_btn: Button = $SplitContainer/RightPanel/RightScroll/RightVBox/CreditsButton
@onready var status_label: Label = $StatusLabel
@onready var server_indicator: ColorRect = $ServerIndicator
@onready var title_label: Label = $Header/HeaderHBox/TitleVBox/Title
@onready var subtitle_label: Label = $Header/HeaderHBox/TitleVBox/Subtitle
@onready var arabic_subtitle_label: Label = $Header/HeaderHBox/TitleVBox/ArabicSubtitle
@onready var left_header: Label = $SplitContainer/LeftPanel/LeftHeader
@onready var right_header: Label = $SplitContainer/RightPanel/RightHeader

var settings_panel: AcceptDialog = null
var tutorial_panel: AcceptDialog = null
var credits_panel: AcceptDialog = null
var current_locale: String = "en"
# P3-AUDIT: single timer instance for offline-state checks so we
# don't accumulate orphan timers across reconnect cycles.
var _offline_check_timer: Timer = null
# P3-AUDIT: store the active indicator tween so we can kill it before
# starting a new one (otherwise .set_loops() leaks tweens on each call).
var _indicator_tween: Tween = null
# P3-AUDIT: prevent re-entrant play button presses during the
# 0.15s pre-transition animation.
var _is_playing: bool = false
var modern_root: Control = null
var modern_title: Label = null
var modern_subtitle: Label = null
var modern_status: Label = null
var modern_story_btn: Button = null
var modern_multiplayer_btn: Button = null
var modern_tutorial_btn: Button = null
var modern_settings_btn: Button = null
var modern_language_btn: Button = null
var modern_credits_btn: Button = null
var _modern_overlay: Control = null

func _ready() -> void:
	print("[MainMenu] _ready() called")
	_log_scene_entered("main_menu")

	# First time the menu loads, emit app_start so the server gets a
	# single high-signal event marking the run began.
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_app_start") and not Engine.has_singleton("__app_start_emitted__"):
		Engine.set_meta("__app_start_emitted__", true)
		tc.event_app_start()

	var bg := get_node_or_null("Background")
	if bg:
		bg.visible = true
		bg.modulate.a = 1.0
		if bg is ColorRect:
			(bg as ColorRect).color = Color(0.025, 0.035, 0.06, 1.0)

	var bg_gradient := get_node_or_null("BgGradient")
	if bg_gradient:
		bg_gradient.visible = true
		bg_gradient.modulate.a = 1.0

	modulate.a = 1.0

	_connect_button_safely(play_btn, _on_play)
	_connect_button_safely(tutorial_btn, _on_tutorial)
	_connect_button_safely(settings_btn, _on_settings)
	_connect_button_safely(language_btn, _on_language)
	_connect_button_safely(credits_btn, _on_credits)
	_build_modern_shell()

	_connect_event_bus_safely()
	_apply_current_locale()
	_animate_entrance()
	# P0-4: Defer connection so EventBus / NetworkClient are fully ready
	# before we try to fire network_status_changed.
	call_deferred("_attempt_connect_safe")
	print("[MainMenu] _ready() complete")


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	# Only disconnect existing connections on the script-side (not the
	# scene-side ones from main_menu.tscn), to avoid silent failures.
	# Try to connect; if it's already connected to the same callback, skip.
	if not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)


func _connect_event_bus_safely() -> void:
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	if event_bus.has_signal("network_connected") and not event_bus.network_connected.is_connected(_on_server_connected):
		event_bus.network_connected.connect(_on_server_connected)
	if event_bus.has_signal("network_error") and not event_bus.network_error.is_connected(_on_server_error):
		event_bus.network_error.connect(_on_server_error)
	if event_bus.has_signal("locale_changed") and not event_bus.locale_changed.is_connected(_on_locale_changed):
		event_bus.locale_changed.connect(_on_locale_changed)
	# P2-12: react to live network status changes (connecting/connected/error).
	if event_bus.has_signal("network_status_changed") and not event_bus.network_status_changed.is_connected(_on_network_status_changed):
		event_bus.network_status_changed.connect(_on_network_status_changed)


func _on_network_status_changed(state: String, detail: String) -> void:
	match state:
		"connecting", "handshaking":
			if status_label:
				status_label.text = "Connecting to server..."
			if modern_status: modern_status.text = _tr("menu.connecting", "Connecting to the Echo network…")
		"connected":
			_on_server_connected()
		"error":
			_on_server_error(detail if detail != "" else "Connection error")
		"disconnected":
			_on_server_error("Disconnected")


func _apply_current_locale() -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		current_locale = loc.get_current_locale()
	else:
		current_locale = "en"
	_update_localized_texts()


func _on_locale_changed(new_locale: String, _is_rtl: bool) -> void:
	current_locale = new_locale
	_update_localized_texts()


func _attempt_connect_safe() -> void:
	if status_label:
		status_label.text = "Connecting to server..."
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc and nc.has_method("is_socket_connected") and nc.has_method("connect_to_server"):
			print("[MainMenu] NetworkClient found, connecting...")
			nc.connect_to_server("")
		else:
			push_warning("[MainMenu] NetworkClient missing connect_to_server()")
			_show_offline_state()
	else:
		_show_offline_state()


func _show_offline_state() -> void:
	if status_label:
		status_label.text = "⚠ Offline mode"
	if server_indicator:
		server_indicator.color = Color(1.0, 0.7, 0.2, 1)
	print("[MainMenu] Offline mode (no NetworkClient autoload)")
	# P3-AUDIT: reuse a single Timer instance to avoid orphan timers
	if _offline_check_timer == null:
		_offline_check_timer = Timer.new()
		_offline_check_timer.wait_time = 5.0
		_offline_check_timer.one_shot = true
		_offline_check_timer.timeout.connect(_check_connection_status)
		add_child(_offline_check_timer)
	_offline_check_timer.start()


func _animate_entrance() -> void:
	var logo = get_node_or_null("Header/HeaderHBox/Logo")
	if logo:
		logo.modulate.a = 0.0
		logo.scale = Vector2(0.85, 0.85)
		var t = create_tween().set_parallel(true)
		t.tween_property(logo, "modulate:a", 1.0, 0.6)
		t.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_BACK)

	var buttons = [play_btn, tutorial_btn, settings_btn, language_btn, credits_btn]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn and is_instance_valid(btn):
			btn.modulate.a = 1.0
			btn.scale = Vector2(0.95, 0.95)
			var bt = create_tween()
			bt.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.2 + i * 0.06)


func _check_connection_status() -> void:
	if has_node("/root/NetworkClient"):
		var nc2 = get_node("/root/NetworkClient")
		if nc2 and nc2.has_method("is_socket_connected") and nc2.is_socket_connected():
			_on_server_connected()
			return
	_on_server_error("Offline mode")


func _on_server_connected() -> void:
	if status_label:
		status_label.text = "✓ Online — Ready to Play"
	if modern_status:
		modern_status.text = "● " + _tr("menu.online", "Online · Ready to play")
		modern_status.add_theme_color_override("font_color", ModernTheme.SUCCESS)
	if server_indicator:
		_flash_indicator(Color(0.3, 1.0, 0.4, 1))


func _on_server_error(reason: String) -> void:
	if status_label:
		status_label.text = "⚠ " + reason + " — Limited features"
	if modern_status:
		modern_status.text = "○ " + _tr("menu.offline", "Offline mode · Solo story available")
		modern_status.add_theme_color_override("font_color", ModernTheme.GOLD)
	if server_indicator:
		_flash_indicator(Color(1.0, 0.7, 0.2, 1))


func _flash_indicator(color: Color) -> void:
	if not server_indicator:
		return
	server_indicator.color = color
	# P3-AUDIT: kill any in-flight tween first to avoid accumulating
	# infinite-loop tweens across reconnect cycles.
	if _indicator_tween and _indicator_tween.is_valid():
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(server_indicator, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	_indicator_tween.tween_property(server_indicator, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


func _update_localized_texts() -> void:
	if current_locale == "ar":
		if subtitle_label: subtitle_label.visible = false
		if arabic_subtitle_label: arabic_subtitle_label.visible = true
		if title_label: title_label.text = "أصداء"
	else:
		if subtitle_label: subtitle_label.visible = true
		if arabic_subtitle_label: arabic_subtitle_label.visible = false
		if title_label: title_label.text = "ECHO//LINE"

	if left_header:
		left_header.text = _tr("menu.section_play", "🎮 PLAY") if current_locale == "en" else "🎮 ابدأ"
	if right_header:
		right_header.text = _tr("menu.section_options", "⚙ OPTIONS") if current_locale == "en" else "⚙ خيارات"

	if play_btn: play_btn.text = "▶  " + _tr("menu.play", "PLAY")
	if tutorial_btn: tutorial_btn.text = "📖  " + _tr("menu.tutorial", "HOW TO PLAY")
	if settings_btn: settings_btn.text = "⚙  " + _tr("menu.settings", "SETTINGS")
	if language_btn:
		language_btn.text = "🌐  " + ("English" if current_locale == "ar" else "العربية")
	if credits_btn: credits_btn.text = "⭐  " + _tr("menu.credits", "CREDITS")
	_update_modern_texts()


func _animate_button_press(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)


# === Button handlers ===

func _on_play() -> void:
	if _is_playing:
		return
	print("[MainMenu] _on_play() called")
	_is_playing = true
	if play_btn:
		_animate_button_press(play_btn)
	const PLAY_SCENE := "res://scenes/main.tscn"
	if not ResourceLoader.exists(PLAY_SCENE):
		push_error("[MainMenu] Play scene not found: %s" % PLAY_SCENE)
		_is_playing = false
		return
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	fade_tween.tween_callback(func():
		var err = get_tree().change_scene_to_file(PLAY_SCENE)
		if err != OK:
			push_error("[MainMenu] change_scene_to_file failed: %d" % err)
			modulate.a = 1.0
			_is_playing = false
	)


func _on_story_mode() -> void:
	_log_button("story_mode")
	if not ResourceLoader.exists(STORY_SCENE):
		_show_info_dialog(&"story_panel", "Story unavailable", "The story chapter archive is missing.")
		return
	get_tree().change_scene_to_file(STORY_SCENE)


func _on_tutorial() -> void:
	print("[MainMenu] _on_tutorial() called")
	_log_button("tutorial")
	if tutorial_btn:
		_animate_button_press(tutorial_btn)
	_show_tutorial()


func _on_settings() -> void:
	print("[MainMenu] _on_settings() called")
	_log_button("settings")
	if settings_btn:
		_animate_button_press(settings_btn)
	_show_simple_settings()


func _on_language() -> void:
	print("[MainMenu] _on_language() called")
	_log_button("language")
	if language_btn:
		_animate_button_press(language_btn)
	var new_locale = "en" if current_locale == "ar" else "ar"
	current_locale = new_locale
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("set_locale"):
		loc.set_locale(new_locale)
	# P5-AUDIT: also update our own UI labels to reflect the locale
	_update_localized_texts()


func _on_credits() -> void:
	print("[MainMenu] _on_credits() called")
	_log_button("credits")
	if credits_btn:
		_animate_button_press(credits_btn)
	_show_credits()


func _show_tutorial() -> void:
	if modern_root:
		_show_how_to_play_screen()
		return
	_show_info_dialog(&"tutorial_panel", "📖  How to Play", """ECHO//LINE is a cooperative cross-timeline puzzle game.

🎯 OBJECTIVE
Each player occupies a different timeline:
  ◆ PAST — Memory & Heritage
  ▲ PRESENT — Reality & Action
  ● FUTURE — Possibility & Hope

⚡ HOW IT WORKS
Your actions create ECHOES that ripple across
other timelines. Coordinate with teammates to
prevent the catastrophe before time runs out.

🏗️ BUILDING ANCHORS
Collect Memory Shards from resolved Echoes.
Place them in Timeline Anchors together.

💬 COMMUNICATION
Use quick messages to coordinate with players worldwide.

✨ TIPS
• Listen to your teammates
• Some consequences are delayed
• Multiple solutions exist

Good luck, time traveler!""")


func _show_simple_settings() -> void:
	if modern_root:
		_show_settings_screen()
		return
	_show_info_dialog(&"settings_panel", "⚙  Settings", """ECHO//LINE — Settings

🌐 Language
   Arabic / English (auto-detect)

🔊 Sound
   Uses device volume

📳 Vibration
   On by default

💬 Subtitles
   Enabled

🌍 Server
   wss://echoline-game-server.onrender.com

📦 Version
   0.1.0 (Early Access)

Full settings panel coming in next build.""")


func _show_credits() -> void:
	_show_info_dialog(&"credits_panel", "⭐  Credits", """ECHO//LINE (أَصْدَاء)

A Cooperative Cross-Timeline
Multiplayer Social Puzzle Game

━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎨  Design & Engineering
    Saif

🖥️  Game Server
    Node.js + Socket.IO
    Hosted on Render

🌐  Admin Panel
    PHP + MySQL
    Hosted on Hostinger

🎮  Game Engine
    Godot Engine 4.7.2

━━━━━━━━━━━━━━━━━━━━━━━━━━━

Version 0.1.0
© 2026 Saif
Made with ❤️ in Iraq""")


# P5-AUDIT: Helper that builds a robust popup dialog using PopupPanel +
# RichTextLabel inside a Control container. AcceptDialog has issues on
# Android touch focus (the dialog itself blocks touches). PopupPanel as a
# direct child of the menu lets us position and dismiss it reliably.
func _show_info_dialog(slot: StringName, title: String, body: String) -> void:
	# slot is unused now (we're using one shared popup container),
	# but kept for backwards compat with the old AcceptDialog approach.
	var existing := get_node_or_null("InfoDialog")
	if existing and is_instance_valid(existing):
		existing.queue_free()

	# Compute target size based on viewport
	var vp := get_viewport_rect().size
	var dialog_size := Vector2(min(620.0, vp.x - 80.0), min(720.0, vp.y - 140.0))
	var popup := PopupPanel.new()
	popup.name = "InfoDialog"
	# PopupPanel already has a StyleBox — keep its default theme background

	# Build the content tree BEFORE sizing so layout math is correct.
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Title bar (Label + close button in HBox)
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 8)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_bar.add_child(title_label)
	# Close (X) button
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(60, 60)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	)
	title_bar.add_child(close_btn)
	vbox.add_child(title_bar)

	# Separator
	vbox.add_child(HSeparator.new())

	# ScrollContainer that fills remaining space; RichTextLabel inside
	# expands to fill the scroll area and grows with its content.
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var rich := RichTextLabel.new()
	rich.name = "Body"
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = true
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.custom_minimum_size = Vector2(dialog_size.x - 80, 0)
	# Use BBCode formatting for nicer typography (preserves emoji + newlines).
	rich.text = _format_dialog_body(body)
	rich.add_theme_font_size_override("normal_font_size", 16)
	rich.add_theme_color_override("default_color", Color(0.92, 0.94, 0.98, 1.0))
	scroll.add_child(rich)

	# OK button row
	var ok_btn := Button.new()
	ok_btn.text = "✓  OK"
	ok_btn.custom_minimum_size = Vector2(0, 56)
	ok_btn.add_theme_font_size_override("font_size", 18)
	ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok_btn.pressed.connect(func() -> void:
		if is_instance_valid(popup):
			popup.hide()
			popup.queue_free()
	)
	vbox.add_child(ok_btn)

	# Add to scene then size + position
	add_child(popup)
	popup.reset_size()
	popup.size = dialog_size
	popup.popup(Rect2i(Vector2i.ZERO, Vector2i(dialog_size)))

	# Center the popup on the viewport.
	popup.position = Vector2((vp.x - dialog_size.x) * 0.5, (vp.y - dialog_size.y) * 0.5)


# Convert a plain-text body into BBCode so the RichTextLabel renders the
# original line breaks + emoji + indentation faithfully. Without BBCode the
# RichTextLabel collapses all whitespace and the dialog appears empty.
func _format_dialog_body(body: String) -> String:
	var lines: PackedStringArray = body.split("\n")
	var out: PackedStringArray = []
	for raw in lines:
		var line := raw
		# Indentation: convert runs of leading spaces to nbsp so they survive.
		var leading := ""
		var i := 0
		while i < line.length() and line[i] == " ":
			leading += " "
			i += 1
		var rest := line.substr(leading.length() if false else 0)  # keep raw spaces, BBCode handles them
		rest = line
		if rest.strip_edges() == "":
			out.append("[br][/br]")
		else:
			out.append(leading + rest)
	return "[left]" + "\n".join(out) + "[/left]"


func _input(event: InputEvent) -> void:
	# P3-AUDIT: only handle ESC key — defer every other event to its target.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


# =============================================================================
# Telemetry helpers (Phase 7: client logs shipped to server)
# =============================================================================

func _log_button(name: String) -> void:
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_button_pressed"):
		tc.event_button_pressed(name, "main_menu")


func _log_scene_entered(name: String) -> void:
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_scene_changed"):
		tc.event_scene_changed("", name)


# =============================================================================
# Modern responsive shell
# =============================================================================

func _build_modern_shell() -> void:
	if modern_root and is_instance_valid(modern_root):
		return
	for node_name in ["Background", "BgGradient", "Header", "SplitContainer", "StatusLabel", "ServerIndicator", "Footer"]:
		var legacy_node := get_node_or_null(node_name)
		if legacy_node:
			legacy_node.visible = false

	modern_root = Control.new()
	modern_root.name = "ModernShell"
	modern_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modern_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modern_root.z_index = 20
	add_child(modern_root)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = ModernTheme.BG
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modern_root.add_child(backdrop)
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = 260
	glow.color = Color(0.03, 0.16, 0.24, 0.45)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modern_root.add_child(glow)
	var corner_mark := ModernTheme.label("⌬", 180, Color(0.2, 0.8, 1.0, 0.04))
	corner_mark.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	corner_mark.position = Vector2(-170, -90)
	corner_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modern_root.add_child(corner_mark)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 18)
	safe.add_theme_constant_override("margin_right", 18)
	safe.add_theme_constant_override("margin_top", 16)
	safe.add_theme_constant_override("margin_bottom", 14)
	modern_root.add_child(safe)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	safe.add_child(page)

	var topbar := HBoxContainer.new()
	topbar.custom_minimum_size.y = 68
	topbar.add_theme_constant_override("separation", 10)
	page.add_child(topbar)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_theme_constant_override("separation", 0)
	topbar.add_child(brand)
	modern_title = ModernTheme.label("ECHO//LINE", 30, ModernTheme.TEXT)
	modern_title.add_theme_color_override("font_shadow_color", Color(0.2, 0.8, 1.0, 0.35))
	modern_title.add_theme_constant_override("shadow_offset_x", 2)
	modern_title.add_theme_constant_override("shadow_offset_y", 2)
	brand.add_child(modern_title)
	modern_subtitle = ModernTheme.label("Echoes across time", 13, ModernTheme.MUTED)
	brand.add_child(modern_subtitle)
	var top_actions := HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 8)
	topbar.add_child(top_actions)
	modern_language_btn = Button.new()
	modern_language_btn.custom_minimum_size = Vector2(58, 56)
	modern_language_btn.text = "ع"
	ModernTheme.style_button(modern_language_btn, ModernTheme.GOLD)
	modern_language_btn.pressed.connect(_on_language)
	top_actions.add_child(modern_language_btn)
	modern_settings_btn = Button.new()
	modern_settings_btn.custom_minimum_size = Vector2(58, 56)
	modern_settings_btn.text = "⚙"
	ModernTheme.style_button(modern_settings_btn, ModernTheme.CYAN)
	modern_settings_btn.pressed.connect(_on_settings)
	top_actions.add_child(modern_settings_btn)

	var status_panel := PanelContainer.new()
	status_panel.custom_minimum_size.y = 34
	status_panel.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.04, 0.1, 0.17, 0.86), 10, Color(0.12, 0.3, 0.42, 0.7)))
	page.add_child(status_panel)
	modern_status = ModernTheme.label("○ " + _tr("menu.offline", "Offline mode · Solo story available"), 13, ModernTheme.GOLD)
	modern_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modern_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_panel.add_child(modern_status)

	var scroll := ScrollContainer.new()
	ModernTheme.configure_scroll(scroll)
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	var hero := PanelContainer.new()
	hero.custom_minimum_size.y = 154
	hero.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.06, 0.14, 0.23, 0.96), 22, Color(0.14, 0.52, 0.67, 0.8), 1))
	content.add_child(hero)
	var hero_margin := MarginContainer.new()
	hero.add_child(hero_margin)
	hero_margin.add_theme_constant_override("margin_left", 22)
	hero_margin.add_theme_constant_override("margin_right", 22)
	hero_margin.add_theme_constant_override("margin_top", 18)
	hero_margin.add_theme_constant_override("margin_bottom", 18)
	var hero_box := VBoxContainer.new()
	hero_margin.add_child(hero_box)
	var eyebrow := ModernTheme.label(_tr("menu.eyebrow", "THE FRACTURE IS WAKING"), 12, ModernTheme.CYAN)
	eyebrow.add_theme_constant_override("outline_size", 4)
	hero_box.add_child(eyebrow)
	var hero_title := ModernTheme.label(_tr("menu.hero_title", "Your choices echo through every timeline."), 24, ModernTheme.TEXT)
	hero_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_box.add_child(hero_title)
	var hero_copy := ModernTheme.label(_tr("menu.hero_copy", "Play alone with your Echo companions or invite friends into a living mystery."), 14, ModernTheme.MUTED)
	hero_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_box.add_child(hero_copy)

	var section := ModernTheme.section_title(_tr("menu.play_section", "CHOOSE YOUR JOURNEY"))
	content.add_child(section)
	modern_story_btn = Button.new()
	modern_story_btn.custom_minimum_size.y = 78
	modern_story_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	modern_story_btn.text = "◈  " + _tr("menu.story", "STORY MODE")
	ModernTheme.style_button(modern_story_btn, ModernTheme.GOLD, true)
	modern_story_btn.pressed.connect(_on_story_mode)
	content.add_child(modern_story_btn)
	modern_multiplayer_btn = Button.new()
	modern_multiplayer_btn.custom_minimum_size.y = 70
	modern_multiplayer_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	modern_multiplayer_btn.text = "◉  " + _tr("menu.multiplayer", "MULTIPLAYER LOBBY")
	ModernTheme.style_button(modern_multiplayer_btn, ModernTheme.CYAN, false)
	modern_multiplayer_btn.pressed.connect(_on_play)
	content.add_child(modern_multiplayer_btn)

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", 10)
	content.add_child(utility_row)
	modern_tutorial_btn = Button.new()
	modern_tutorial_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modern_tutorial_btn.text = "?  " + _tr("menu.tutorial", "HOW TO PLAY")
	ModernTheme.style_button(modern_tutorial_btn, ModernTheme.PINK)
	modern_tutorial_btn.pressed.connect(_on_tutorial)
	utility_row.add_child(modern_tutorial_btn)
	modern_credits_btn = Button.new()
	modern_credits_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modern_credits_btn.text = "✦  " + _tr("menu.credits", "CREDITS")
	ModernTheme.style_button(modern_credits_btn, ModernTheme.GOLD)
	modern_credits_btn.pressed.connect(_on_credits)
	utility_row.add_child(modern_credits_btn)

	var footer := ModernTheme.label("v0.1.0 · Build 17  •  Early Access", 11, Color(0.55, 0.65, 0.78, 0.9))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(footer)

	_update_modern_texts()
	_animate_modern_entrance()


func _update_modern_texts() -> void:
	if not modern_root or not is_instance_valid(modern_root):
		return
	if modern_title:
		modern_title.text = "أصداء" if current_locale == "ar" else "ECHO//LINE"
	if modern_subtitle:
		modern_subtitle.text = _tr("app.subtitle", "Echoes across time")
	if modern_story_btn:
		modern_story_btn.text = "◈  " + _tr("menu.story", "STORY MODE")
	if modern_multiplayer_btn:
		modern_multiplayer_btn.text = "◉  " + _tr("menu.multiplayer", "MULTIPLAYER LOBBY")
	if modern_tutorial_btn:
		modern_tutorial_btn.text = "?  " + _tr("menu.tutorial", "HOW TO PLAY")
	if modern_credits_btn:
		modern_credits_btn.text = "✦  " + _tr("menu.credits", "CREDITS")
	if modern_language_btn:
		modern_language_btn.text = "EN" if current_locale == "ar" else "ع"


func _animate_modern_entrance() -> void:
	if not modern_root:
		return
	modern_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(modern_root, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC)


func _make_modal(title_text: String) -> Dictionary:
	if _modern_overlay and is_instance_valid(_modern_overlay):
		_modern_overlay.queue_free()
	_modern_overlay = Control.new()
	_modern_overlay.name = "ModernOverlay"
	_modern_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modern_overlay.z_index = 100
	modern_root.add_child(_modern_overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.05, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modern_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modern_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(max(280.0, min(720.0, get_viewport_rect().size.x - 28.0)), max(300.0, min(650.0, get_viewport_rect().size.y - 32.0)))
	panel.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.055, 0.1, 0.18, 0.99), 24, Color(0.2, 0.55, 0.68, 0.9), 1))
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := ModernTheme.label(title_text, 24, ModernTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(56, 56)
	ModernTheme.style_button(close, ModernTheme.PINK)
	close.pressed.connect(_close_modern_overlay)
	header.add_child(close)
	stack.add_child(HSeparator.new())
	return {"stack": stack, "panel": panel}


func _close_modern_overlay() -> void:
	if _modern_overlay and is_instance_valid(_modern_overlay):
		_modern_overlay.queue_free()
	_modern_overlay = null


func _show_how_to_play_screen() -> void:
	var modal := _make_modal(_tr("tutorial.title", "HOW TO PLAY"))
	var stack: VBoxContainer = modal.stack
	var scroll := ScrollContainer.new()
	ModernTheme.configure_scroll(scroll)
	stack.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var intro := ModernTheme.label(_tr("tutorial.intro", "Every action creates an Echo. Work together across Past, Present, and Future before stability reaches zero."), 16, ModernTheme.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var steps := [
		["01", _tr("tutorial.step1.title", "Choose a timeline"), _tr("tutorial.step1.body", "Past remembers, Present repairs, and Future predicts. Each path reveals a different clue.")],
		["02", _tr("tutorial.step2.title", "Follow the Echo"), _tr("tutorial.step2.body", "Look for a glowing interaction, read its consequence, and communicate what changed.")],
		["03", _tr("tutorial.step3.title", "Collect the shard"), _tr("tutorial.step3.body", "Resolved Echoes reveal Memory Shards. Keep the right shard for the right Anchor slot.")],
		["04", _tr("tutorial.step4.title", "Build the Anchor"), _tr("tutorial.step4.body", "Place compatible shards in order. Late actions can change another timeline several moments later.")],
		["05", _tr("tutorial.step5.title", "Protect stability"), _tr("tutorial.step5.body", "Use hints, quick chat, and pings when the catastrophe meter turns critical.")]
	]
	for step in steps:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.08, 0.15, 0.24, 0.95), 16, Color(0.15, 0.3, 0.45, 0.8)))
		body.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var number := ModernTheme.label(step[0], 22, ModernTheme.GOLD)
		number.custom_minimum_size.x = 38
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(copy)
		copy.add_child(ModernTheme.label(step[1], 17, ModernTheme.TEXT))
		copy.add_child(ModernTheme.label(step[2], 13, ModernTheme.MUTED))
	var done := Button.new()
	done.text = _tr("common.got_it", "I'M READY")
	ModernTheme.style_button(done, ModernTheme.CYAN, true)
	done.pressed.connect(_close_modern_overlay)
	stack.add_child(done)


func _show_settings_screen() -> void:
	var modal := _make_modal(_tr("settings.title", "SETTINGS"))
	var stack: VBoxContainer = modal.stack
	var scroll := ScrollContainer.new()
	ModernTheme.configure_scroll(scroll)
	stack.add_child(scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_add_settings_section(body, _tr("settings.audio", "AUDIO"))
	_add_audio_slider(body, "master", _tr("settings.master", "Master volume"), 1.0)
	_add_audio_slider(body, "music", _tr("settings.music", "Music"), 0.7)
	_add_audio_slider(body, "sfx", _tr("settings.sfx", "Sound effects"), 1.0)
	_add_audio_slider(body, "ambient", _tr("settings.ambient", "Ambient"), 0.5)
	_add_settings_section(body, _tr("settings.gameplay", "GAMEPLAY & ACCESSIBILITY"))
	_add_toggle(body, _tr("settings.vibration", "Vibration feedback"), _accessibility_value("haptic_enabled", true), func(value: bool) -> void:
		var access = get_node_or_null("/root/Accessibility")
		if access and access.has_method("set_haptic"): access.set_haptic(value)
	)
	_add_toggle(body, _tr("settings.screen_shake", "Screen shake"), _accessibility_value("screen_shake_enabled", true), func(value: bool) -> void:
		var access = get_node_or_null("/root/Accessibility")
		if access and access.has_method("set_screen_shake"): access.set_screen_shake(value)
	)
	_add_toggle(body, _tr("settings.reduced_motion", "Reduced motion"), _accessibility_value("reduced_motion", false), func(value: bool) -> void:
		var access = get_node_or_null("/root/Accessibility")
		if access and access.has_method("set_reduced_motion"): access.set_reduced_motion(value)
	)
	_add_toggle(body, _tr("settings.subtitles", "Subtitles"), _accessibility_value("subtitles_enabled", true), func(value: bool) -> void:
		var access = get_node_or_null("/root/Accessibility")
		if access and access.has_method("set_subtitles_enabled"): access.set_subtitles_enabled(value)
	)
	_add_settings_section(body, _tr("settings.visuals", "VISUALS"))
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 10)
	body.add_child(quality_row)
	var quality_label := ModernTheme.label(_tr("settings.quality", "Visual quality"), 15, ModernTheme.TEXT)
	quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_label)
	var quality := OptionButton.new()
	quality.custom_minimum_size = Vector2(160, 56)
	for item in [_tr("settings.low", "Low"), _tr("settings.medium", "Medium"), _tr("settings.high", "High"), _tr("settings.ultra", "Ultra")]: quality.add_item(item)
	var gm = get_node_or_null("/root/GraphicsManager")
	if gm: quality.select(clamp(int(gm.current_quality), 0, 3))
	quality.item_selected.connect(func(index: int) -> void:
		var manager = get_node_or_null("/root/GraphicsManager")
		if manager and manager.has_method("set_quality"): manager.set_quality(index)
	)
	ModernTheme.style_button(quality, ModernTheme.CYAN)
	quality_row.add_child(quality)
	_add_toggle(body, _tr("settings.fullscreen", "Fullscreen"), _graphics_value("fullscreen", false), func(value: bool) -> void:
		var manager = get_node_or_null("/root/GraphicsManager")
		if manager and manager.has_method("set_fullscreen"): manager.set_fullscreen(value)
	)
	_add_settings_section(body, _tr("settings.language_section", "LANGUAGE"))
	var language_row := HBoxContainer.new()
	language_row.add_theme_constant_override("separation", 10)
	body.add_child(language_row)
	var language_label := ModernTheme.label(_tr("menu.language", "Language"), 15, ModernTheme.TEXT)
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_row.add_child(language_label)
	var language := OptionButton.new()
	language.custom_minimum_size = Vector2(180, 56)
	language.add_item("English", 0)
	language.add_item("العربية", 1)
	language.select(1 if current_locale == "ar" else 0)
	language.item_selected.connect(_on_settings_language_selected)
	ModernTheme.style_button(language, ModernTheme.GOLD)
	language_row.add_child(language)
	var reset := Button.new()
	reset.text = _tr("settings.reset", "RESET TO DEFAULTS")
	ModernTheme.style_button(reset, ModernTheme.PINK)
	reset.pressed.connect(_reset_settings)
	stack.add_child(reset)


func _add_settings_section(parent: VBoxContainer, text_value: String) -> void:
	parent.add_child(ModernTheme.section_title(text_value))


func _add_audio_slider(parent: VBoxContainer, channel: String, label_text: String, fallback: float) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var header := HBoxContainer.new()
	row.add_child(header)
	var title := ModernTheme.label(label_text, 14, ModernTheme.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var value_label := ModernTheme.label("", 13, ModernTheme.CYAN)
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size.y = 42
	var mixer = get_node_or_null("/root/AudioMixer")
	var value := float(mixer.get_level(channel) if mixer and mixer.has_method("get_level") else fallback)
	slider.value = value
	value_label.text = "%d%%" % int(value * 100.0)
	slider.value_changed.connect(func(next_value: float) -> void:
		value_label.text = "%d%%" % int(next_value * 100.0)
		var service = get_node_or_null("/root/AudioMixer")
		if service and service.has_method("set_channel"): service.set_channel(channel, next_value)
	)
	row.add_child(slider)


func _add_toggle(parent: VBoxContainer, label_text: String, initial: bool, callback: Callable) -> void:
	var check := CheckButton.new()
	check.text = label_text
	check.button_pressed = initial
	check.custom_minimum_size.y = 56
	check.add_theme_font_size_override("font_size", 15)
	check.add_theme_color_override("font_color", ModernTheme.TEXT)
	check.toggled.connect(callback)
	parent.add_child(check)


func _accessibility_value(property_name: String, fallback: Variant) -> Variant:
	var access = get_node_or_null("/root/Accessibility")
	if access:
		var value = access.get(property_name)
		return value if value != null else fallback
	return fallback


func _graphics_value(property_name: String, fallback: Variant) -> Variant:
	var manager = get_node_or_null("/root/GraphicsManager")
	if manager:
		var value = manager.get(property_name)
		return value if value != null else fallback
	return fallback


func _on_settings_language_selected(index: int) -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("set_locale"):
		loc.set_locale("ar" if index == 1 else "en")
	_close_modern_overlay()


func _reset_settings() -> void:
	var access = get_node_or_null("/root/Accessibility")
	if access and access.has_method("reset_to_defaults"): access.reset_to_defaults()
	var mixer = get_node_or_null("/root/AudioMixer")
	if mixer and mixer.has_method("reset_to_defaults"): mixer.reset_to_defaults()
	var graphics = get_node_or_null("/root/GraphicsManager")
	if graphics and graphics.has_method("reset_to_defaults"): graphics.reset_to_defaults()
	_show_settings_screen()

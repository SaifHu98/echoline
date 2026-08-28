extends Control

# ECHO//LINE — Main Menu (Split Layout + Logo)
# Left panel: PRIMARY actions (Play, Tutorial)
# Right panel: SECONDARY actions (Settings, Language, Credits)

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
		if nc and nc.has_method("connect_to_server"):
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
	if server_indicator:
		_flash_indicator(Color(0.3, 1.0, 0.4, 1))


func _on_server_error(reason: String) -> void:
	if status_label:
		status_label.text = "⚠ " + reason + " — Limited features"
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
	get_tree().create_timer(0.15).timeout.connect(func():
		var err = get_tree().change_scene_to_file(PLAY_SCENE)
		if err != OK:
			push_error("[MainMenu] change_scene_to_file failed: %d" % err)
			modulate.a = 1.0
			_is_playing = false
	)


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
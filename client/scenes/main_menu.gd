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
	if tutorial_btn:
		_animate_button_press(tutorial_btn)
	_show_tutorial()


func _on_settings() -> void:
	print("[MainMenu] _on_settings() called")
	if settings_btn:
		_animate_button_press(settings_btn)
	_show_simple_settings()


func _on_language() -> void:
	print("[MainMenu] _on_language() called")
	if language_btn:
		_animate_button_press(language_btn)
	var new_locale = "en" if current_locale == "ar" else "ar"
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("set_locale"):
		loc.set_locale(new_locale)


func _on_credits() -> void:
	print("[MainMenu] _on_credits() called")
	if credits_btn:
		_animate_button_press(credits_btn)
	_show_credits()


func _show_tutorial() -> void:
	if tutorial_panel and is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()
	tutorial_panel = AcceptDialog.new()
	tutorial_panel.title = "📖  How to Play"
	tutorial_panel.dialog_text = """ECHO//LINE is a cooperative cross-timeline puzzle game.

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

Good luck, time traveler!"""
	tutorial_panel.popup_centered()
	add_child(tutorial_panel)


func _show_simple_settings() -> void:
	if settings_panel and is_instance_valid(settings_panel):
		settings_panel.queue_free()
	settings_panel = AcceptDialog.new()
	settings_panel.title = "⚙  Settings"
	settings_panel.dialog_text = """ECHO//LINE — Settings

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

Full settings panel coming in next build."""
	settings_panel.popup_centered()
	add_child(settings_panel)


func _show_credits() -> void:
	if credits_panel and is_instance_valid(credits_panel):
		credits_panel.queue_free()
	credits_panel = AcceptDialog.new()
	credits_panel.title = "⭐  Credits"
	credits_panel.dialog_text = """ECHO//LINE (أَصْدَاء)

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
Made with ❤️ in Iraq"""
	credits_panel.popup_centered()
	add_child(credits_panel)


func _input(event: InputEvent) -> void:
	# P3-AUDIT: only handle ESC key — defer every other event to its target.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
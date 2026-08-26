extends Control

# ECHO//LINE — Main Menu (Polished)
# Large touch-friendly buttons with smooth animations

@onready var play_btn: Button = $ScrollContainer/Buttons/PlayButton
@onready var tutorial_btn: Button = $ScrollContainer/Buttons/TutorialButton
@onready var settings_btn: Button = $ScrollContainer/Buttons/SettingsButton
@onready var language_btn: Button = $ScrollContainer/Buttons/LanguageButton
@onready var credits_btn: Button = $ScrollContainer/Buttons/CreditsButton
@onready var status_label: Label = $StatusLabel
@onready var server_indicator: ColorRect = $ServerIndicator
@onready var title_label: Label = $Header/Title

var settings_panel: AcceptDialog = null
var tutorial_panel: AcceptDialog = null
var credits_panel: AcceptDialog = null
var current_locale: String = "en"

func _ready() -> void:
	print("[MainMenu] _ready() called")

	# CRITICAL: Background must be visible from frame 1
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

	# Start visible — animation will set modulate to 1.0 in parallel
	modulate.a = 1.0

	# CRITICAL: Force-connect button signals explicitly
	# (Editor-side connections via .tscn should work, but we add runtime safety)
	_connect_button_safely(play_btn, _on_play)
	_connect_button_safely(tutorial_btn, _on_tutorial)
	_connect_button_safely(settings_btn, _on_settings)
	_connect_button_safely(language_btn, _on_language)
	_connect_button_safely(credits_btn, _on_credits)

	# Connect network status events — use defensive singleton check
	_connect_event_bus_safely()

	# Detect system locale (defensive — fails to "en" if not available)
	if OS:
		var os_locale = OS.get_locale_language()
		current_locale = "ar" if os_locale == "ar" else "en"
	else:
		current_locale = "en"

	# Try to apply localization, but don't crash if missing
	var localization_node = get_node_or_null("/root/Localization")
	if localization_node and localization_node.has_method("set_locale"):
		localization_node.set_locale(current_locale)
	_update_localized_texts()

	# Apply entrance animations (subtle — no flicker)
	_animate_entrance()

	# Try to connect to game server (non-blocking — falls back to offline mode)
	_attempt_connect_safe()

	print("[MainMenu] _ready() complete")


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	# Disconnect any existing connections to prevent double-fire
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
	btn.pressed.connect(callback)


func _connect_event_bus_safely() -> void:
	# EventBus might not be ready or might be missing
	var event_bus = get_node_or_null("/root/EventBus")
	if event_bus == null:
		print("[MainMenu] EventBus singleton not found — network events disabled")
		return
	if not event_bus.has_signal("network_connected"):
		return
	if not event_bus.network_connected.is_connected(_on_server_connected):
		event_bus.network_connected.connect(_on_server_connected)
	if event_bus.has_signal("network_error") and not event_bus.network_error.is_connected(_on_server_error):
		event_bus.network_error.connect(_on_server_error)


func _attempt_connect_safe() -> void:
	if status_label:
		status_label.text = "Connecting to server..."

	# Try to connect, but wrap in try/catch equivalent (Godot uses if-checks)
	if Engine.has_singleton("NetworkClient") or has_node("/root/NetworkClient"):
		NetworkClient.connect_to_server("")
	else:
		print("[MainMenu] NetworkClient singleton not found — offline mode")
		if status_label:
			status_label.text = "⚠ Offline mode — Limited features"
		if server_indicator:
			server_indicator.color = Color(1.0, 0.7, 0.2, 1)
		return

	# Schedule a status check after 5 seconds
	var timer = get_tree().create_timer(5.0)
	if timer:
		timer.timeout.connect(_check_connection_status)


func _animate_entrance() -> void:
	# Already at modulate.a = 1.0, but animate a slight fade-in from 0.7 for polish
	var t = create_tween()
	if t:
		t.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)

	# Stagger button entrance (subtle scale-up, no flicker)
	var buttons = [play_btn, tutorial_btn, settings_btn, language_btn, credits_btn]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn and is_instance_valid(btn):
			btn.modulate.a = 1.0  # ensure visible
			btn.scale = Vector2(0.95, 0.95)
			var bt = create_tween()
			bt.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.1 + i * 0.06)


func _check_connection_status() -> void:
	# Defensive check — NetworkClient may not have these methods in dev builds
	if has_node("/root/NetworkClient") and NetworkClient.has_method("is_socket_connected"):
		if NetworkClient.is_socket_connected():
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
	var t = create_tween().set_loops()
	t.tween_property(server_indicator, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(server_indicator, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)


func _update_localized_texts() -> void:
	if current_locale == "ar":
		if play_btn: play_btn.text = "▶  ابدأ اللعب"
		if tutorial_btn: tutorial_btn.text = "📖  كيفية اللعب"
		if settings_btn: settings_btn.text = "⚙  الإعدادات"
		if language_btn: language_btn.text = "🌐  English"
		if credits_btn: credits_btn.text = "⭐  الفضل"
	else:
		if play_btn: play_btn.text = "▶  PLAY"
		if tutorial_btn: tutorial_btn.text = "📖  HOW TO PLAY"
		if settings_btn: settings_btn.text = "⚙  SETTINGS"
		if language_btn: language_btn.text = "🌐  العربية"
		if credits_btn: credits_btn.text = "⭐  CREDITS"


func _animate_button_press(btn: Button) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)


func _on_play() -> void:
	print("[MainMenu] _on_play() called")
	if play_btn:
		_animate_button_press(play_btn)
	# Verify target scene exists
	const PLAY_SCENE := "res://scenes/main.tscn"
	if not ResourceLoader.exists(PLAY_SCENE):
		push_error("[MainMenu] Play scene not found: %s" % PLAY_SCENE)
		if status_label:
			status_label.text = "⚠ Game scene missing!"
		return
	# Fade out first, then change scene (prevents gray flash)
	var fade = create_tween()
	if fade:
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(func():
			var err = get_tree().change_scene_to_file(PLAY_SCENE)
			if err != OK:
				push_error("[MainMenu] change_scene_to_file failed: %d" % err)
				# Restore modulate so user can try again
				modulate.a = 1.0
		)
	else:
		get_tree().change_scene_to_file(PLAY_SCENE)


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
	current_locale = "ar" if current_locale == "en" else "en"
	if has_node("/root/Localization"):
		Localization.set_locale(current_locale)
	_update_localized_texts()


func _on_credits() -> void:
	print("[MainMenu] _on_credits() called")
	if credits_btn:
		_animate_button_press(credits_btn)
	_show_credits()


func _show_tutorial() -> void:
	# Clean up old panel before showing new one
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
Use quick messages (auto-translated) to coordinate
across languages with players worldwide.

✨ TIPS
• Listen to your teammates
• Some consequences are delayed
• Multiple solutions exist
• Quick messages translate automatically

Good luck, time traveler!"""
	tutorial_panel.popup_centered()
	add_child(tutorial_panel)


func _show_simple_settings() -> void:
	# Clean up old panel before showing new one
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
	# Clean up old panel before showing new one
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
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
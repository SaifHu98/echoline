extends Control

# ECHO//LINE — Main Menu (Polished)
# Large touch-friendly buttons with smooth animations

@onready var play_btn: Button = $Layout/Buttons/PlayButton
@onready var tutorial_btn: Button = $Layout/Buttons/TutorialButton
@onready var settings_btn: Button = $Layout/Buttons/SettingsButton
@onready var language_btn: Button = $Layout/Buttons/LanguageButton
@onready var credits_btn: Button = $Layout/Buttons/CreditsButton
@onready var status_label: Label = $Layout/StatusLabel
@onready var server_indicator: ColorRect = $Layout/ServerIndicator
@onready var title_label: Label = $Header/Title

var settings_panel: AcceptDialog = null
var tutorial_panel: AcceptDialog = null
var current_locale: String = "en"
var menu_loaded: bool = false

func _ready() -> void:
	print("[MainMenu] _ready() called")

	# CRITICAL FIX: Background must be visible from frame 1
	# Even if everything else fails to load, the user sees something
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

	# Connect buttons (all optional — if missing, we still proceed)
	if play_btn and not play_btn.pressed.is_connected(_on_play):
		play_btn.pressed.connect(_on_play)
	if tutorial_btn and not tutorial_btn.pressed.is_connected(_on_tutorial):
		tutorial_btn.pressed.connect(_on_tutorial)
	if settings_btn and not settings_btn.pressed.is_connected(_on_settings):
		settings_btn.pressed.connect(_on_settings)
	if language_btn and not language_btn.pressed.is_connected(_on_language):
		language_btn.pressed.connect(_on_language)
	if credits_btn and not credits_btn.pressed.is_connected(_on_credits):
		credits_btn.pressed.connect(_on_credits)

	# Connect network status events — use defensive singleton check
	_connect_event_bus_safely()

	# Detect system locale (defensive — fails to "en" if not available)
	if OS:
		var os_locale = OS.get_locale_language()
		current_locale = "ar" if os_locale == "ar" else "en"
	else:
		current_locale = "en"

	# Try to apply localization, but don't crash if missing
	if ClassDB.class_exists("Localization") or (has_node("/root/Localization")):
		Localization.set_locale(current_locale)
	_update_localized_texts()

	# Apply entrance animations
	_animate_entrance()

	# Try to connect to game server (non-blocking — falls back to offline mode)
	_attempt_connect_safe()

	print("[MainMenu] _ready() complete")


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
	# Use a Timer instead of relying on NetworkClient being available
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
	# Already at modulate.a = 1.0, but animate entrance from slight offset
	# This avoids the "flash" if modulate.a starts at 0
	var t = create_tween()
	if t:
		t.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)

	# Stagger button entrance (subtle — buttons already visible)
	var buttons = [play_btn, tutorial_btn, settings_btn, language_btn, credits_btn]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn and is_instance_valid(btn):
			# Buttons start visible with modulate 1.0 (no hide-then-show)
			# Just animate scale-up from 0.95 to 1.0 for polish
			btn.scale = Vector2(0.95, 0.95)
			var bt = create_tween()
			bt.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_delay(0.1 + i * 0.06)


func _attempt_connect() -> void:
	# Renamed to _attempt_connect_safe for clarity; kept as alias
	_attempt_connect_safe()


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
	var t = create_tween().set_parallel(true)
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)


func _on_play() -> void:
	if play_btn:
		_animate_button_press(play_btn)
	# Verify target scene exists
	const PLAY_SCENE := "res://scenes/main.tscn"
	if not ResourceLoader.exists(PLAY_SCENE):
		push_error("[MainMenu] Play scene not found: %s" % PLAY_SCENE)
		return
	# Fade out first, then change scene (prevents gray flash)
	var fade = create_tween()
	if fade:
		fade.tween_property(self, "modulate:a", 0.0, 0.3)
		fade.tween_callback(func():
			var err = get_tree().change_scene_to_file(PLAY_SCENE)
			if err != OK:
				push_error("[MainMenu] change_scene_to_file failed: %d" % err)
		)
	else:
		get_tree().change_scene_to_file(PLAY_SCENE)


func _on_tutorial() -> void:
	_animate_button_press(tutorial_btn)
	_show_tutorial()


func _on_settings() -> void:
	_animate_button_press(settings_btn)
	_show_simple_settings()


func _on_language() -> void:
	_animate_button_press(language_btn)
	current_locale = "ar" if current_locale == "en" else "en"
	Localization.set_locale(current_locale)
	_update_localized_texts()


func _on_credits() -> void:
	_animate_button_press(credits_btn)
	_show_credits()


func _show_tutorial() -> void:
	if tutorial_panel:
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
	if settings_panel:
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
	if settings_panel:
		settings_panel.queue_free()
	settings_panel = AcceptDialog.new()
	settings_panel.title = "⭐  Credits"
	settings_panel.dialog_text = """ECHO//LINE (أَصْدَاء)

A Cooperative Cross-Timeline
Multiplayer Social Puzzle Game

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

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

━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Version 0.1.0
© 2026 Saif
Made with ❤️ in Iraq"""
	settings_panel.popup_centered()
	add_child(settings_panel)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()

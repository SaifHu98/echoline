extends Control

# ECHO//LINE — Main Menu Controller
# First screen the player sees on launch

@onready var play_btn = $Center/PlayButton
@onready var tutorial_btn = $Center/TutorialButton
@onready var settings_btn = $Center/SettingsButton
@onready var language_btn = $Center/LanguageButton
@onready var status_label = $Center/StatusLabel

var settings_panel: Control = null
var current_locale: String = "en"

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	tutorial_btn.pressed.connect(_on_tutorial)
	settings_btn.pressed.connect(_on_settings)
	language_btn.pressed.connect(_on_language)

	# Detect system locale
	current_locale = OS.get_locale_language()
	if current_locale == "ar":
		current_locale = "ar"
	else:
		current_locale = "en"
	Localization.set_locale(current_locale)
	_update_localized_texts()

	# Try to connect to game server automatically
	_attempt_connect()


func _attempt_connect() -> void:
	# Connect to game server
	status_label.text = "Connecting..."
	NetworkClient.connect_to_server("")
	# Wait for connection or timeout
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(func():
		if NetworkClient.is_socket_connected():
			status_label.text = "✓ Online"
		else:
			status_label.text = "⚠ Offline — some features limited"
	)


func _update_localized_texts() -> void:
	if current_locale == "ar":
		play_btn.text = "▶ العب"
		tutorial_btn.text = "كيفية اللعب"
		settings_btn.text = "⚙ الإعدادات"
		language_btn.text = "🌐 English"
	else:
		play_btn.text = "▶ PLAY"
		tutorial_btn.text = "How to Play"
		settings_btn.text = "⚙ Settings"
		language_btn.text = "🌐 العربية"


func _on_play() -> void:
	# Switch to lobby scene
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_tutorial() -> void:
	_show_tutorial()


func _on_settings() -> void:
	_show_settings_panel()


func _on_language() -> void:
	current_locale = "ar" if current_locale == "en" else "en"
	Localization.set_locale(current_locale)
	_update_localized_texts()


func _show_tutorial() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "How to Play"
	dialog.dialog_text = """ECHO//LINE is a cooperative game across TIMELINES.

• You and your teammates each occupy a different timeline
• Each timeline has unique objects and information
• Your actions affect other timelines (called ECHOES)
• Communicate using quick messages (auto-translated)
• Prevent the catastrophe before time runs out

Tips:
- Listen to your teammates
- Some consequences are delayed
- Multiple solutions exist
- Quick messages are translated automatically

Good luck!"""
	dialog.popup_centered()
	add_child(dialog)


func _show_settings_panel() -> void:
	if settings_panel:
		settings_panel.queue_free()
	settings_panel = preload("res://ui/settings/settings_view.tscn").instantiate()
	add_child(settings_panel)
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
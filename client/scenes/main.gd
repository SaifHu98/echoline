extends Node

# ECHO//LINE — Main Controller
# Wires together: Network, UI screens, Game flow

signal screen_changed(screen_name: String)

@onready var lobby_view = $UI/LobbyView
@onready var game_hud = $UI/GameHUD
@onready var causal_recap = $UI/CausalRecapView
@onready var settings_view = $UI/SettingsView

enum Screen { MENU, LOBBY, MATCH, RECAP, SETTINGS }
var current_screen: Screen = Screen.MENU
var current_room_code: String = ""
var is_host: bool = false
var selected_timeline: String = ""
var player_uid: String = ""
var player_name: String = ""

func _ready() -> void:
	player_uid = "p_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	player_name = "Player" + str(randi() % 1000)

	# Listen to network events
	EventBus.lobby_updated.connect(_on_lobby_updated)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_state_updated.connect(_on_match_state_updated)
	EventBus.match_concluded.connect(_on_match_concluded)
	EventBus.network_error.connect(_on_network_error)
	EventBus.network_connected.connect(_on_network_connected)

	# Pre-fill UI
	if has_node("UI/LobbyView/Panel/VBox/JoinRow/RoomCodeInput"):
		$"UI/LobbyView/Panel/VBox/JoinRow/RoomCodeInput".text = ""
	if has_node("UI/LobbyView/Panel/VBox/StatusLabel"):
		$"UI/LobbyView/Panel/VBox/StatusLabel".text = ""

	# Show menu screen
	_show_screen(Screen.MENU)
	_show_lobby_input()


func _process(delta: float) -> void:
	# Refresh timer display from local cache
	pass


# === Screen management ===
func _show_screen(screen: Screen) -> void:
	current_screen = screen
	lobby_view.visible = (screen == Screen.LOBBY or screen == Screen.MENU)
	game_hud.visible = (screen == Screen.MATCH)
	causal_recap.visible = (screen == Screen.RECAP)
	settings_view.visible = (screen == Screen.SETTINGS)
	screen_changed.emit(Screen.keys()[screen])


# === Lobby UI ===
func _show_lobby_input() -> void:
	# Show the input UI for joining/creating
	if has_node("UI/LobbyView/Panel/VBox/JoinRow"):
		$"UI/LobbyView/Panel/VBox/JoinRow".visible = true
	if has_node("UI/LobbyView/Panel/VBox/CardsRow"):
		$"UI/LobbyView/Panel/VBox/CardsRow".visible = false
	if has_node("UI/LobbyView/Panel/VBox/ReadyButton"):
		$"UI/LobbyView/Panel/VBox/ReadyButton".visible = false


func _show_lobby_timeline_picker(roster: Array) -> void:
	_show_screen(Screen.LOBBY)
	if has_node("UI/LobbyView/Panel/VBox/JoinRow"):
		$"UI/LobbyView/Panel/VBox/JoinRow".visible = false
	if has_node("UI/LobbyView/Panel/VBox/CardsRow"):
		$"UI/LobbyView/Panel/VBox/CardsRow".visible = true

	# Highlight already-taken timelines
	var taken = []
	for p in roster:
		if p.get("timeline", "") != "":
			taken.append(p.timeline)

	# Make buttons reflect available timelines
	for card_name in ["PastCard", "PresentCard", "FutureCard"]:
		var btn_path = "UI/LobbyView/Panel/VBox/CardsRow/" + card_name
		if has_node(btn_path):
			var btn = get_node(btn_path)
			var tl = card_name.replace("Card", "").to_lower()
			if tl in taken:
				btn.disabled = true
				btn.modulate = Color(0.5, 0.5, 0.5)
			else:
				btn.disabled = false
				btn.modulate = Color.WHITE


# === Button handlers (connected via Godot signals in scene or programmatically) ===
func _on_join_button_pressed() -> void:
	var code_input = $"UI/LobbyView/Panel/VBox/JoinRow/RoomCodeInput"
	if not code_input or code_input.text.length() < 4:
		_show_status("أدخل رمز غرفة صحيح (4 أحرف على الأقل)")
		return
	var code = code_input.text.strip_edges().to_upper()
	_show_status("جاري الاتصال...")
	NetworkClient.join_room_with_code(code, player_name, Localization.get_locale(), _on_join_ack)


func _on_create_button_pressed() -> void:
	_show_status("جاري إنشاء غرفة...")
	NetworkClient.create_room(player_name, Localization.get_locale(), "clocktower_district", _on_create_ack)


func _on_past_card_pressed() -> void:
	selected_timeline = "past"
	NetworkClient.select_timeline("past", func(ack): _on_select_timeline_ack(ack))


func _on_present_card_pressed() -> void:
	selected_timeline = "present"
	NetworkClient.select_timeline("present", func(ack): _on_select_timeline_ack(ack))


func _on_future_card_pressed() -> void:
	selected_timeline = "future"
	NetworkClient.select_timeline("future", func(ack): _on_select_timeline_ack(ack))


func _on_ready_button_pressed() -> void:
	NetworkClient.set_ready(true, func(ack):
		if ack.get("success"):
			_show_status("أنت جاهز!")
	)


func _on_start_button_pressed() -> void:
	NetworkClient.start_match(func(ack):
		if not ack.get("success"):
			_show_status("فشل البدء: " + str(ack.get("error", "?")))
	)


func _on_fill_bots_pressed() -> void:
	NetworkClient.fill_with_bots(func(ack):
		if ack.get("success"):
			_show_status("تم ملء الغرفة بحلفاء AI")
	)


func _on_leave_button_pressed() -> void:
	NetworkClient.leave_lobby()
	_show_screen(Screen.MENU)
	_show_lobby_input()


# === Interact button (game HUD) ===
func _on_interact_button_pressed() -> void:
	# Determine which entity to interact with based on player position
	# For simplicity: cycle through interactable entities
	var entities = [
		{"id": "canal_debris", "action": "clear_debris"},
		{"id": "courtyard_soil", "action": "plant_seed"},
		{"id": "canal_sluice_gate", "action": "open_sluice_gate"},
		{"id": "builder_archive_tablet", "action": "carve_tablet"},
	]
	var idx = int(Time.get_ticks_msec() / 3000) % entities.size()
	var e = entities[idx]
	NetworkClient.send_interaction(e.id, e.action, func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("✓ " + Localization.t("echo." + e.id), 2.0)
		else:
			EventBus.subtitle_requested.emit("✗ " + str(ack.get("error", "")), 2.0)
	)


func _on_quick_message_button_pressed(intent: String) -> void:
	NetworkClient.send_quick_message(intent)


func _on_ping_button_pressed(ping_type: String) -> void:
	NetworkClient.send_ping(ping_type, 400, 300)


# === Network event handlers ===
func _on_join_ack(ack: Dictionary) -> void:
	if ack.get("success"):
		is_host = false
		current_room_code = ack.room.get("code", "")
		_show_lobby_timeline_picker(ack.room.get("players", []))
		_show_status("دخلت الغرفة " + current_room_code)
		_show_screen(Screen.LOBBY)
	else:
		_show_status("فشل الانضمام: " + str(ack.get("error", "")))


func _on_create_ack(ack: Dictionary) -> void:
	if ack.get("success"):
		is_host = true
		current_room_code = ack.room.get("code", "")
		_show_status("أنشأت الغرفة: " + current_room_code)
		_show_lobby_timeline_picker(ack.room.get("players", []))
		_show_screen(Screen.LOBBY)
	else:
		_show_status("فشل الإنشاء: " + str(ack.get("error", "")))


func _on_select_timeline_ack(ack: Dictionary) -> void:
	if ack.get("success"):
		_show_status("اخترت " + ack.get("timeline", ""))
		$"UI/LobbyView/Panel/VBox/ReadyButton".visible = true


func _on_lobby_updated(roster: Dictionary) -> void:
	if current_screen != Screen.LOBBY:
		return
	var players = roster.get("players", [])
	_show_status(str(players.size()) + "/4 لاعبين")
	_show_lobby_timeline_picker(players)

	if has_node("UI/LobbyView/Panel/VBox/ReadyButton"):
		$"UI/LobbyView/Panel/VBox/ReadyButton".visible = true
	# Show start button if host and all ready
	if is_host and players.size() >= 2:
		var all_ready = true
		for p in players:
			if not p.get("isReady", false):
				all_ready = false
				break
		if all_ready:
			_show_status("الجميع جاهز! اضغط لبدء المباراة")
			# Could add a Start button here


func _on_match_started(match_id: String, initial_state: Dictionary) -> void:
	_show_screen(Screen.MATCH)
	EventBus.subtitle_requested.emit(Localization.t("match.started"), 3.0)
	AudioManager.play_echo(my_timeline if my_timeline else "past")


func _on_match_state_updated(state: Dictionary) -> void:
	# Update HUD timer & stability
	var sys = state.get("state", {}).get("system", {})
	if sys:
		var ms = int(sys.get("catastrophe_timer_ms", 0))
		var stability = int(sys.get("stability", 0))
		var stage = sys.get("current_stage", "stable")
		EventBus.catastrophe_updated.emit(ms, float(stability), stage)


func _on_match_concluded(recap: Dictionary) -> void:
	_show_screen(Screen.RECAP)


func _on_network_connected() -> void:
	_show_status("✓ متصل بالسيرفر")


func _on_network_error(reason: String) -> void:
	_show_status("✗ خطأ: " + reason)


# === Helpers ===
func _show_status(msg: String) -> void:
	if has_node("UI/LobbyView/Panel/VBox/StatusLabel"):
		$"UI/LobbyView/Panel/VBox/StatusLabel".text = msg
	print("[Main] " + msg)


func _input(event: InputEvent) -> void:
	if current_screen == Screen.MENU and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()


# Public method called from outside (e.g., when user clicks Play from menu)
func start_quick_match() -> void:
	_show_screen(Screen.LOBBY)
	if not NetworkClient.is_socket_connected():
		NetworkClient.connect_to_server("")
	_show_status("اختر: إنشاء غرفة جديدة أو الانضمام برمز")
	# Show input UI
	if has_node("UI/LobbyView/Panel/VBox/JoinRow"):
		$"UI/LobbyView/Panel/VBox/JoinRow".visible = true

func show_settings() -> void:
	_show_screen(Screen.SETTINGS)

func hide_settings() -> void:
	_show_screen(Screen.MENU if current_room_code == "" else Screen.LOBBY)
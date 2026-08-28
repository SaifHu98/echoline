class_name LobbyView
extends Control

# Timeline Selection & Matchmaking Lobby — Modern responsive redesign.
# Features:
#   - Room browser (open + private rooms with 🔒)
#   - Create room with optional password + max-players picker
#   - Join room with optional password prompt
#   - Timeline picker (past / present / future)
#   - Language switcher
#   - Responsive layout (works on any phone size from 360x640 upward)
#   - Large, easy-to-tap refresh button (60dp tall)

const ModernTheme := preload("res://ui/modern_theme.gd")

# ----- Constants -----
const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 4
const DEFAULT_PLAYERS: int = 4
const REFRESH_BTN_MIN_HEIGHT: int = 64

# ----- UI references (declared in main.tscn) -----
@onready var room_code_input: LineEdit = $Panel/VBox/HeaderRow/RoomCodeInput
@onready var join_btn: Button = $Panel/VBox/HeaderRow/JoinButton
@onready var create_btn: Button = $Panel/VBox/HeaderRow/CreateButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var past_card: Button = $Panel/VBox/CardsRow/PastCard
@onready var present_card: Button = $Panel/VBox/CardsRow/PresentCard
@onready var future_card: Button = $Panel/VBox/CardsRow/FutureCard
@onready var ready_btn: Button = $Panel/VBox/ActionRow/ReadyButton
@onready var leave_btn: Button = $Panel/VBox/ActionRow/LeaveButton
@onready var back_btn: Button = $BackButton
@onready var join_row: VBoxContainer = $Panel/VBox/HeaderRow
@onready var cards_row: VBoxContainer = $Panel/VBox/CardsRow
@onready var action_row: HBoxContainer = $Panel/VBox/ActionRow

# ----- Dynamic UI (created in _ensure_rooms_panel) -----
var rooms_scroll: ScrollContainer = null
var rooms_container: VBoxContainer = null
var rooms_panel: PanelContainer = null
var refresh_btn: Button = null
var join_section: VBoxContainer = null
var lobby_status_label: Label = null

# ----- Create-room modal state -----
var _create_modal: PopupPanel = null
var _create_password_field: LineEdit = null
var _create_max_players_value: int = DEFAULT_PLAYERS
var _create_max_players_label: Label = null

# ----- Join-room modal state -----
var _join_modal: PopupPanel = null
var _join_password_field: LineEdit = null
var _join_pending_code: String = ""

# ----- General state -----
var is_ready: bool = false
var selected_timeline: String = ""
var my_player_uid: String = ""
var is_host: bool = false
var current_locale: String = "en"
var available_rooms: Array = []
var _locale_fetch_timer: Timer = null
var _auto_refresh_timer: Timer = null

signal timeline_picked(timeline: String)
signal ready_state_changed(ready: bool)
signal start_match_requested()
signal leave_lobby_requested()


func _ready() -> void:
	print("[LobbyView] _ready() called")
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_scene_changed"):
		tc.event_scene_changed("", "lobby")
	modulate.a = 1.0

	_apply_current_locale()
	_build_modern_lobby()
	_connect_event_bus_safely()

	if EventBus.has_signal("lobby_updated"):
		EventBus.lobby_updated.connect(_on_lobby_updated)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	# Wire all in-scene buttons.
	_connect_button_safely(join_btn, _on_join_pressed)
	_connect_button_safely(create_btn, _on_create_pressed)
	_connect_button_safely(ready_btn, _on_ready_pressed)
	_connect_button_safely(leave_btn, _on_leave_pressed)
	_connect_button_safely(back_btn, _on_back_pressed)
	if refresh_btn:
		_connect_button_safely(refresh_btn, _on_refresh_rooms_pressed)

	if past_card:
		_connect_button_safely(past_card, _on_past_pressed)
	if present_card:
		_connect_button_safely(present_card, _on_present_pressed)
	if future_card:
		_connect_button_safely(future_card, _on_future_pressed)

	_style_timeline_cards()

	_call_deferred_layout()
	_show_input_state()
	_update_localized_texts()


func _call_deferred_layout() -> void:
	call_deferred("_ensure_rooms_panel")
	call_deferred("_fetch_available_rooms")
	# Auto-refresh the rooms list every 8 seconds so joining players see
	# new rooms without having to manually refresh.
	_auto_refresh_timer = Timer.new()
	_auto_refresh_timer.wait_time = 8.0
	_auto_refresh_timer.autostart = true
	_auto_refresh_timer.timeout.connect(_fetch_available_rooms)
	add_child(_auto_refresh_timer)


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)


func _apply_current_locale() -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		current_locale = loc.get_current_locale()


func _connect_event_bus_safely() -> void:
	if EventBus == null:
		return
	if EventBus.has_signal("network_connected") and not EventBus.network_connected.is_connected(_on_server_connected_event):
		EventBus.network_connected.connect(_on_server_connected_event)
	if EventBus.has_signal("network_error") and not EventBus.network_error.is_connected(_on_server_error_event):
		EventBus.network_error.connect(_on_server_error_event)


func _on_server_connected_event() -> void:
	if status_label:
		status_label.text = "✓ Connected"


func _on_server_error_event(reason: String) -> void:
	if status_label:
		status_label.text = "⚠ " + reason


func _on_locale_changed(new_locale: String, _is_rtl: bool) -> void:
	current_locale = new_locale
	_update_localized_texts()
	if _locale_fetch_timer:
		_locale_fetch_timer.stop()
	else:
		_locale_fetch_timer = Timer.new()
		_locale_fetch_timer.one_shot = true
		_locale_fetch_timer.wait_time = 1.0
		_locale_fetch_timer.timeout.connect(_fetch_available_rooms)
		add_child(_locale_fetch_timer)
	_locale_fetch_timer.start()


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


# =============================================================================
# ROOM BROWSER
# =============================================================================

func _fetch_available_rooms() -> void:
	if not has_node("/root/NetworkClient"):
		_show_rooms_empty("Network unavailable")
		return
	var nc = get_node("/root/NetworkClient")
	if not nc.has_method("list_rooms") and not nc.has_method("http_list_rooms"):
		_show_rooms_empty("Network unavailable")
		return
	if nc.has_method("list_rooms"):
		nc.list_rooms(current_locale, _on_rooms_received)
		var timer = get_tree().create_timer(3.0)
		if timer:
			timer.timeout.connect(_fetch_available_rooms_http)
	else:
		_fetch_available_rooms_http()


func _fetch_available_rooms_http() -> void:
	if not has_node("/root/NetworkClient"):
		return
	var nc = get_node("/root/NetworkClient")
	if nc.has_method("http_list_rooms"):
		nc.http_list_rooms(current_locale, _on_rooms_received)


func _on_rooms_received(result: Dictionary) -> void:
	if not result or not result.get("success", false):
		_show_rooms_empty(_tr("lobby.rooms_unavailable", "⚠ Rooms list unavailable"))
		return
	var rooms = result.get("rooms", [])
	available_rooms = rooms
	_populate_rooms_list(rooms)


func _show_rooms_empty(msg: String) -> void:
	if not rooms_container:
		return
	for child in rooms_container.get_children():
		child.queue_free()
	if msg == "":
		msg = _tr("lobby.no_rooms_open", "📭 No open rooms. Tap ➕ to create one!")
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1.0))
	label.modulate.a = 0.85
	rooms_container.add_child(label)


func _populate_rooms_list(rooms: Array) -> void:
	if not rooms_container:
		return
	for child in rooms_container.get_children():
		child.queue_free()
	if rooms.is_empty():
		_show_rooms_empty("")
		return
	for room_data in rooms:
		var card = _build_room_card(room_data)
		if card:
			rooms_container.add_child(card)


func _build_room_card(data: Dictionary) -> Control:
	var code: String = data.get("code", "")
	var host: String = data.get("hostName", "Host")
	var scenario: String = data.get("scenarioName", data.get("scenarioId", "Unknown"))
	var status: String = data.get("status", "open")
	var player_count: int = data.get("playerCount", 0)
	var max_players: int = data.get("maxPlayers", 4)
	var players: Array = data.get("players", [])
	var is_private: bool = data.get("isPrivate", false) or data.get("hasPassword", false)

	var card = Button.new()
	card.custom_minimum_size = Vector2(0, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.18, 0.92)
	sb.border_width_left = 4
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10

	match status:
		"open":
			sb.border_color = Color(0.3, 0.85, 0.4, 0.9)
			sb.shadow_color = Color(0.3, 0.85, 0.4, 0.3)
			sb.shadow_size = 6
		"ready":
			sb.border_color = Color(1.0, 0.84, 0.3, 0.9)
			sb.shadow_color = Color(1.0, 0.84, 0.3, 0.3)
			sb.shadow_size = 6
		"full":
			sb.border_color = Color(0.6, 0.6, 0.6, 0.5)
		"in_progress":
			sb.border_color = Color(0.95, 0.3, 0.4, 0.7)
		_:
			sb.border_color = Color(0.3, 0.85, 0.4, 0.9)

	card.add_theme_stylebox_override("normal", sb)
	var sb_hover = sb.duplicate()
	sb_hover.bg_color = Color(0.15, 0.18, 0.24, 0.95)
	card.add_theme_stylebox_override("hover", sb_hover)
	var sb_disabled = sb.duplicate()
	sb_disabled.bg_color = Color(0.08, 0.1, 0.13, 0.6)
	card.add_theme_stylebox_override("disabled", sb_disabled)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 14
	hbox.offset_right = -14
	hbox.offset_top = 10
	hbox.offset_bottom = -10
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	var icon = Label.new()
	icon.text = _get_status_icon(status) + (" 🔒" if is_private else "")
	icon.add_theme_font_size_override("font_size", 28)
	hbox.add_child(icon)

	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(row1)

	var code_label = Label.new()
	code_label.text = "🔑 " + code
	code_label.add_theme_font_size_override("font_size", 18)
	code_label.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))
	row1.add_child(code_label)

	var status_badge = Label.new()
	status_badge.text = "• " + _get_status_label(status)
	status_badge.add_theme_font_size_override("font_size", 13)
	status_badge.add_theme_color_override("font_color", _get_status_color(status))
	row1.add_child(status_badge)

	var row2 = Label.new()
	row2.text = "📜 " + scenario + "  •  👑 " + host
	row2.add_theme_font_size_override("font_size", 12)
	row2.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1.0))
	text_vbox.add_child(row2)

	var row3 = HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	row3.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(row3)
	for p in players:
		var pl_label = Label.new()
		var tl_emoji = _timeline_emoji(p.get("timeline", ""))
		var dn = str(p.get("displayName", "?"))
		if dn.length() > 8:
			dn = dn.substr(0, 8)
		pl_label.text = tl_emoji + " " + dn
		pl_label.add_theme_font_size_override("font_size", 10)
		pl_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.85))
		row3.add_child(pl_label)
	var count_label = Label.new()
	count_label.text = "  " + str(player_count) + "/" + str(max_players) + " 🎮"
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7, 1.0))
	row3.add_child(count_label)

	if status != "full" and status != "in_progress":
		card.disabled = false
		card.pressed.connect(_on_room_card_pressed.bind(code, is_private))
	else:
		card.disabled = true

	return card


func _get_status_icon(status: String) -> String:
	match status:
		"open": return "🟢"
		"ready": return "🟡"
		"full": return "⚫"
		"in_progress": return "🔴"
		_: return "⚪"


func _get_status_label(status: String) -> String:
	match status:
		"open": return _tr("lobby.status_open", "OPEN")
		"ready": return _tr("lobby.status_ready", "READY")
		"full": return _tr("lobby.status_full", "FULL")
		"in_progress": return _tr("lobby.status_in_progress", "IN PROGRESS")
		_: return status.to_upper()


func _get_status_color(status: String) -> Color:
	match status:
		"open": return Color(0.3, 0.95, 0.4)
		"ready": return Color(1.0, 0.84, 0.3)
		"full": return Color(0.6, 0.6, 0.6)
		"in_progress": return Color(0.95, 0.3, 0.4)
		_: return Color.WHITE


func _timeline_emoji(timeline: String) -> String:
	match timeline.to_lower():
		"past": return "◆"
		"present": return "▲"
		"future": return "●"
		_: return "○"


func _on_room_card_pressed(code: String, is_private: bool) -> void:
	print("[LobbyView] Room card pressed: " + code + " (private=" + str(is_private) + ")")
	if is_private:
		# Ask for the password before sending the join request.
		_show_join_password_modal(code)
	else:
		room_code_input.text = code
		_show_status("Joining room " + code + "...")
		_on_join_pressed()


func _on_refresh_rooms_pressed() -> void:
	print("[LobbyView] Refresh rooms pressed")
	_fetch_available_rooms()


# =============================================================================
# CREATE ROOM FLOW (with optional password + max-players picker)
# =============================================================================

func _on_create_pressed() -> void:
	print("[LobbyView] _on_create_pressed() called")
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_button_pressed"):
		tc.event_button_pressed("lobby.create", "lobby")
	_show_create_modal()


func _show_create_modal() -> void:
	if _create_modal and is_instance_valid(_create_modal):
		_create_modal.queue_free()
	_create_max_players_value = DEFAULT_PLAYERS

	var vp := get_viewport_rect().size
	var modal_w: float = min(560.0, vp.x - 40.0)
	var modal_h: float = min(620.0, vp.y - 80.0)

	_create_modal = PopupPanel.new()
	_create_modal.name = "CreateRoomModal"

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_create_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "➕ " + _tr("lobby.create_new", "Create New Room")
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 56)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(_create_modal):
			_create_modal.hide()
			_create_modal.queue_free()
	)
	title_row.add_child(close_btn)
	vbox.add_child(title_row)
	vbox.add_child(HSeparator.new())

	# Host name
	var host_label := Label.new()
	host_label.text = "👑 " + _tr("lobby.your_name", "Your Display Name")
	host_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(host_label)
	var host_field := LineEdit.new()
	host_field.name = "HostNameField"
	host_field.placeholder_text = _tr("lobby.name_placeholder", "Host")
	host_field.text = "Host" + str(randi() % 1000)
	host_field.custom_minimum_size = Vector2(0, 60)
	host_field.add_theme_font_size_override("font_size", 18)
	host_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(host_field)

	# Max players
	var mp_label := Label.new()
	mp_label.text = "👥 " + _tr("lobby.max_players", "Max Players")
	mp_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(mp_label)
	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 12)
	mp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for n in [MIN_PLAYERS, MIN_PLAYERS + 1, MIN_PLAYERS + 2, MAX_PLAYERS]:
		var btn := Button.new()
		btn.text = str(n) + (" 👤" if n > 1 else " 👤")
		btn.custom_minimum_size = Vector2(0, 60)
		btn.add_theme_font_size_override("font_size", 22)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggle_mode = true
		btn.pressed.connect(_on_max_players_pressed.bind(n, btn))
		if n == _create_max_players_value:
			btn.button_pressed = true
		mp_row.add_child(btn)
	vbox.add_child(mp_row)

	# Password (optional)
	var pw_label := Label.new()
	pw_label.text = "🔒 " + _tr("lobby.password_optional", "Password (optional)")
	pw_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(pw_label)
	_create_password_field = LineEdit.new()
	_create_password_field.name = "PasswordField"
	_create_password_field.placeholder_text = _tr("lobby.password_placeholder", "Leave empty for public room")
	_create_password_field.secret = true
	_create_password_field.custom_minimum_size = Vector2(0, 60)
	_create_password_field.add_theme_font_size_override("font_size", 18)
	_create_password_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_create_password_field)

	# Confirm button
	var confirm := Button.new()
	confirm.text = "✓  " + _tr("lobby.create", "Create Room")
	confirm.custom_minimum_size = Vector2(0, 64)
	confirm.add_theme_font_size_override("font_size", 22)
	confirm.pressed.connect(func() -> void:
		var name_field: LineEdit = _create_modal.get_node_or_null("Margin/VBox/HostNameField")
		var host_name := name_field.text if name_field else "Host"
		if host_name.strip_edges() == "":
			host_name = "Host"
		var pw := _create_password_field.text if _create_password_field else ""
		_do_create(host_name, _create_max_players_value, pw)
	)
	vbox.add_child(confirm)

	add_child(_create_modal)
	_create_modal.size = Vector2(modal_w, modal_h)
	_create_modal.popup(Rect2i(Vector2i.ZERO, Vector2i(modal_w, modal_h)))
	_create_modal.position = Vector2((vp.x - modal_w) * 0.5, (vp.y - modal_h) * 0.5)


func _on_max_players_pressed(n: int, btn: Button) -> void:
	_create_max_players_value = n
	# Untoggle siblings
	var parent := btn.get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling is Button and sibling != btn:
				sibling.button_pressed = false


func _do_create(host_name: String, max_players: int, password: String) -> void:
	if not has_node("/root/NetworkClient"):
		_show_status("⚠ Not connected to server")
		return
	var nc = get_node("/root/NetworkClient")
	if not nc.is_socket_connected():
		nc.connect_to_server("")
	if _create_modal and is_instance_valid(_create_modal):
		_create_modal.hide()
		_create_modal.queue_free()
	_show_status(_tr("lobby.creating", "Creating room..."))
	var pname := host_name.strip_edges()
	if pname == "":
		pname = "Host" + str(randi() % 1000)
	if nc.has_method("create_room"):
		nc.create_room(pname, current_locale, "clocktower_district", _on_create_ack, max_players, password)


# =============================================================================
# JOIN ROOM FLOW (with optional password prompt)
# =============================================================================

func _on_join_pressed() -> void:
	print("[LobbyView] _on_join_pressed() called")
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_button_pressed"):
		tc.event_button_pressed("lobby.join", "lobby")
	if not room_code_input:
		return
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_show_status(_tr("lobby.invalid_code", "Enter a valid room code (min 4 chars)"))
		return
	if not has_node("/root/NetworkClient"):
		return
	var nc = get_node("/root/NetworkClient")
	if not nc.is_socket_connected():
		nc.connect_to_server("")
	_show_status(_tr("lobby.connecting", "Connecting to server..."))
	var pname := "Player" + str(randi() % 1000)
	if nc.has_method("join_room_with_code"):
		nc.join_room_with_code(code, pname, current_locale, _on_join_ack)


func _do_join(code: String, password: String) -> void:
	if not has_node("/root/NetworkClient"):
		_show_status("⚠ Not connected to server")
		return
	var nc = get_node("/root/NetworkClient")
	if not nc.is_socket_connected():
		nc.connect_to_server("")
	_show_status(_tr("lobby.connecting", "Connecting to server..."))
	var pname := "Player" + str(randi() % 1000)
	if nc.has_method("join_room_with_code"):
		nc.join_room_with_code(code, pname, current_locale, _on_join_ack, password)


func _show_join_password_modal(code: String) -> void:
	if _join_modal and is_instance_valid(_join_modal):
		_join_modal.queue_free()
	_join_pending_code = code

	var vp := get_viewport_rect().size
	var modal_w: float = min(480.0, vp.x - 40.0)
	var modal_h: float = min(380.0, vp.y - 80.0)

	_join_modal = PopupPanel.new()
	_join_modal.name = "JoinPasswordModal"

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_join_modal.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "🔒 " + _tr("lobby.enter_password", "Enter Room Password")
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.84, 0.3, 1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(56, 56)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func() -> void:
		if is_instance_valid(_join_modal):
			_join_modal.hide()
			_join_modal.queue_free()
	)
	title_row.add_child(close_btn)
	vbox.add_child(title_row)

	var code_lbl := Label.new()
	code_lbl.text = "Room: " + code
	code_lbl.add_theme_font_size_override("font_size", 14)
	code_lbl.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))
	vbox.add_child(code_lbl)

	_join_password_field = LineEdit.new()
	_join_password_field.placeholder_text = _tr("lobby.password_placeholder", "Enter password")
	_join_password_field.secret = true
	_join_password_field.custom_minimum_size = Vector2(0, 60)
	_join_password_field.add_theme_font_size_override("font_size", 20)
	_join_password_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_join_password_field)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	var cancel_btn := Button.new()
	cancel_btn.text = _tr("menu.back", "Cancel")
	cancel_btn.custom_minimum_size = Vector2(0, 60)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(func() -> void:
		if is_instance_valid(_join_modal):
			_join_modal.hide()
			_join_modal.queue_free()
	)
	btn_row.add_child(cancel_btn)
	var join_btn_local := Button.new()
	join_btn_local.text = "✓  " + _tr("lobby.join", "Join")
	join_btn_local.custom_minimum_size = Vector2(0, 60)
	join_btn_local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn_local.pressed.connect(func() -> void:
		var pw := _join_password_field.text if _join_password_field else ""
		var c := _join_pending_code
		if is_instance_valid(_join_modal):
			_join_modal.hide()
			_join_modal.queue_free()
		_do_join(c, pw)
	)
	btn_row.add_child(join_btn_local)
	vbox.add_child(btn_row)

	add_child(_join_modal)
	_join_modal.size = Vector2(modal_w, modal_h)
	_join_modal.popup(Rect2i(Vector2i.ZERO, Vector2i(modal_w, modal_h)))
	_join_modal.position = Vector2((vp.x - modal_w) * 0.5, (vp.y - modal_h) * 0.5)


# =============================================================================
# CALLBACKS
# =============================================================================

func _on_create_ack(ack: Dictionary) -> void:
	print("[LobbyView] _on_create_ack: " + str(ack))
	if not ack.get("success"):
		var err = ack.get("error", "")
		var code = ack.get("code", "")
		_show_status(_tr("lobby.create_failed", "Create failed: {err}").format({"err": str(err) + " (" + str(code) + ")"}))
		var tc := get_node_or_null("/root/TelemetryClient")
		if tc and tc.has_method("log_error"):
			tc.log_error("lobby.create", str(err), {"code": str(code)})
		return
	is_host = true
	var room = ack.get("room", {})
	if room:
		room_code_input.text = room.get("code", "")
	_show_timeline_picker_state()
	_show_status(_tr("lobby.room_created", "Room created: {code} — Pick your timeline").format({"code": room.get("code", "")}))
	_update_cards_from_roster(room.get("players", []))
	_fetch_available_rooms()


func _on_join_ack(ack: Dictionary) -> void:
	print("[LobbyView] _on_join_ack: " + str(ack))
	if not ack.get("success"):
		var err = ack.get("error", "")
		var code = ack.get("code", "")
		var tc := get_node_or_null("/root/TelemetryClient")
		if tc and tc.has_method("log_error"):
			tc.log_error("lobby.join", str(err), {"code": str(code)})
		_show_status(_tr("lobby.join_failed", "Join failed: {err}").format({"err": str(err) + " (" + str(code) + ")"}))
		# If it was a wrong-password error and the user clicked via card,
		# the password modal is already gone. Show it again.
		if code == "WRONG_PASSWORD" and _join_pending_code != "":
			_show_join_password_modal(_join_pending_code)
		return
	is_host = false
	_show_timeline_picker_state()
	var room = ack.get("room", {})
	var code_str = room.get("code", "")
	_show_status(_tr("lobby.joined_room", "Joined room: {code} — Pick your timeline").format({"code": code_str}))
	_update_cards_from_roster(room.get("players", []))
	_fetch_available_rooms()


func _on_leave_pressed() -> void:
	print("[LobbyView] _on_leave_pressed() called")
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc.has_method("leave_lobby"):
			nc.leave_lobby()
	is_ready = false
	selected_timeline = ""
	is_host = false
	leave_lobby_requested.emit()
	_show_input_state()
	_show_status(_tr("lobby.left_room", "Left the room"))
	_fetch_available_rooms()


func _on_back_pressed() -> void:
	print("[LobbyView] _on_back_pressed() called")
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc.has_method("leave_lobby") and (is_host or selected_timeline != ""):
			nc.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_past_pressed() -> void:
	print("[LobbyView] _on_past_pressed() called")
	_select_timeline("past")


func _on_present_pressed() -> void:
	print("[LobbyView] _on_present_pressed() called")
	_select_timeline("present")


func _on_future_pressed() -> void:
	print("[LobbyView] _on_future_pressed() called")
	_select_timeline("future")


func _on_ready_pressed() -> void:
	print("[LobbyView] _on_ready_pressed() called")
	if not is_host and selected_timeline == "":
		_show_status("⚠ Pick a timeline first")
		return
	if selected_timeline == "":
		_show_status("⚠ Pick a timeline first")
		return
	is_ready = not is_ready
	if ready_btn:
		var ready_text = _tr("lobby.ready_done", "✓ READY") if is_ready else _tr("lobby.ready", "READY")
		ready_btn.text = ready_text
		ready_btn.modulate = Color(0.3, 1.0, 0.4) if is_ready else Color.WHITE
		var tween = create_tween().set_parallel(true)
		tween.tween_property(ready_btn, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(ready_btn, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)

	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc and nc.has_method("set_ready"):
			nc.set_ready(is_ready, func(ack): pass)
	ready_state_changed.emit(is_ready)


# =============================================================================
# TIMELINE STATE
# =============================================================================

func _style_timeline_cards() -> void:
	if past_card:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.13, 0.05, 0.8)
		sb.border_color = Color(0.83, 0.69, 0.22, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		past_card.add_theme_stylebox_override("normal", sb)
		var sb_hover = sb.duplicate()
		sb_hover.bg_color = Color(0.25, 0.18, 0.07, 0.95)
		sb_hover.border_color = Color(1.0, 0.84, 0.3, 1)
		past_card.add_theme_stylebox_override("hover", sb_hover)

	if present_card:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.12, 0.18, 0.8)
		sb.border_color = Color(0, 0.7, 0.85, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		present_card.add_theme_stylebox_override("normal", sb)
		var sb_hover = sb.duplicate()
		sb_hover.bg_color = Color(0.06, 0.18, 0.25, 0.95)
		sb_hover.border_color = Color(0.2, 0.95, 1, 1)
		present_card.add_theme_stylebox_override("hover", sb_hover)

	if future_card:
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.05, 0.18, 0.8)
		sb.border_color = Color(1, 0.31, 0.75, 0.7)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		future_card.add_theme_stylebox_override("normal", sb)
		var sb_hover = sb.duplicate()
		sb_hover.bg_color = Color(0.22, 0.07, 0.25, 0.95)
		sb_hover.border_color = Color(1, 0.5, 0.9, 1)
		future_card.add_theme_stylebox_override("hover", sb_hover)


func _show_input_state() -> void:
	if join_row: join_row.visible = true
	if cards_row: cards_row.visible = false
	if action_row: action_row.visible = false
	if rooms_panel: rooms_panel.visible = true


func reset_lobby_state() -> void:
	is_ready = false
	selected_timeline = ""
	is_host = false
	_show_input_state()
	_update_card_selection_visuals()


# Dynamically build the room browser panel if it wasn't present in the
# scene (main.tscn inlines the LobbyView without RoomsPanel).
func _ensure_rooms_panel() -> void:
	if rooms_panel and is_instance_valid(rooms_panel):
		return
	var vbox = get_node_or_null("Panel/VBox")
	if vbox == null:
		return

	# IMPORTANT: use PanelContainer so children auto-stack vertically.
	# Using a raw Panel lets children overlap at (0,0) which is the bug
	# we're fixing here.
	rooms_panel = PanelContainer.new()
	rooms_panel.name = "RoomsPanel"
	rooms_panel.custom_minimum_size = Vector2(0, 220)

	# Outer VBox inside PanelContainer — children stack vertically.
	var rooms_vbox := VBoxContainer.new()
	rooms_vbox.add_theme_constant_override("separation", 0)
	rooms_panel.add_child(rooms_vbox)

	var vbox_index := vbox.get_child_count()
	vbox.add_child(rooms_panel)
	vbox.move_child(rooms_panel, vbox_index - 2 if vbox_index >= 3 else 1)

	# Header row with title + big refresh button (sized for thumbs)
	var header_hbox := HBoxContainer.new()
	header_hbox.name = "Header"
	header_hbox.add_theme_constant_override("separation", 12)
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_margin := MarginContainer.new()
	header_margin.add_theme_constant_override("margin_left", 16)
	header_margin.add_theme_constant_override("margin_right", 16)
	header_margin.add_theme_constant_override("margin_top", 10)
	header_margin.add_theme_constant_override("margin_bottom", 8)
	rooms_vbox.add_child(header_margin)
	header_margin.add_child(header_hbox)

	var title_label := Label.new()
	title_label.text = "🌐 " + _tr("lobby.open_rooms", "Open Rooms")
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0, 0.95, 1, 1))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(title_label)

	# BIG REFRESH BUTTON — easy to tap (160 x 64 dp)
	refresh_btn = Button.new()
	refresh_btn.name = "RefreshButton"
	refresh_btn.text = _tr("lobby.refresh", "REFRESH")
	refresh_btn.custom_minimum_size = Vector2(160, REFRESH_BTN_MIN_HEIGHT)
	refresh_btn.add_theme_font_size_override("font_size", 16)
	refresh_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Prominent cyan styling
	var refresh_sb := StyleBoxFlat.new()
	refresh_sb.bg_color = Color(0, 0.45, 0.65, 0.9)
	refresh_sb.border_width_left = 2
	refresh_sb.border_width_top = 2
	refresh_sb.border_width_right = 2
	refresh_sb.border_width_bottom = 2
	refresh_sb.border_color = Color(0, 0.95, 1, 0.7)
	refresh_sb.corner_radius_top_left = 12
	refresh_sb.corner_radius_top_right = 12
	refresh_sb.corner_radius_bottom_right = 12
	refresh_sb.corner_radius_bottom_left = 12
	refresh_btn.add_theme_stylebox_override("normal", refresh_sb)
	var refresh_sb_hover = refresh_sb.duplicate()
	refresh_sb_hover.bg_color = Color(0, 0.6, 0.85, 1.0)
	refresh_sb_hover.border_color = Color(0, 0.95, 1, 1)
	refresh_btn.add_theme_stylebox_override("hover", refresh_sb_hover)
	var refresh_sb_press = refresh_sb.duplicate()
	refresh_sb_press.bg_color = Color(0, 0.85, 1, 1)
	refresh_btn.add_theme_stylebox_override("pressed", refresh_sb_press)
	header_hbox.add_child(refresh_btn)

	if not refresh_btn.pressed.is_connected(_on_refresh_rooms_pressed):
		refresh_btn.pressed.connect(_on_refresh_rooms_pressed)

	# Body — scroll + container (inside the rooms_vbox, vertically below header)
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left", 12)
	body_margin.add_theme_constant_override("margin_right", 12)
	body_margin.add_theme_constant_override("margin_top", 0)
	body_margin.add_theme_constant_override("margin_bottom", 12)
	rooms_vbox.add_child(body_margin)

	rooms_scroll = ScrollContainer.new()
	rooms_scroll.name = "RoomsScroll"
	rooms_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_scroll.custom_minimum_size = Vector2(0, 140)
	rooms_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_margin.add_child(rooms_scroll)

	rooms_container = VBoxContainer.new()
	rooms_container.name = "RoomsContainer"
	rooms_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_container.add_theme_constant_override("separation", 10)
	rooms_scroll.add_child(rooms_container)


func _show_timeline_picker_state() -> void:
	if join_row: join_row.visible = false
	if cards_row: cards_row.visible = true
	if action_row: action_row.visible = true
	if rooms_panel: rooms_panel.visible = false


func _select_timeline(timeline: String) -> void:
	print("[LobbyView] _select_timeline: " + timeline)
	selected_timeline = timeline
	_update_card_selection_visuals()
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc.has_method("select_timeline"):
			nc.select_timeline(timeline, func(_ack): pass)
	timeline_picked.emit(timeline)
	_show_status(_tr("lobby.timeline_chosen", "Timeline chosen: {t}").format({"t": timeline}))


func _update_card_selection_visuals() -> void:
	if past_card:
		past_card.modulate = Color(1.3, 1.3, 1.0) if selected_timeline == "past" else Color.WHITE
	if present_card:
		present_card.modulate = Color(1.3, 1.3, 1.0) if selected_timeline == "present" else Color.WHITE
	if future_card:
		future_card.modulate = Color(1.3, 1.3, 1.0) if selected_timeline == "future" else Color.WHITE


func _update_cards_from_roster(players: Array) -> void:
	for p in players:
		var tl = p.get("timeline", "")
		if tl == "past" and past_card:
			past_card.modulate = Color(1.3, 1.3, 1.0)
			selected_timeline = "past"
		elif tl == "present" and present_card:
			present_card.modulate = Color(1.3, 1.3, 1.0)
			selected_timeline = "present"
		elif tl == "future" and future_card:
			future_card.modulate = Color(1.3, 1.3, 1.0)
			selected_timeline = "future"


func _on_lobby_updated(roster: Variant) -> void:
	var players: Array = []
	if roster is Array:
		players = roster
	elif roster is Dictionary:
		players = roster.get("players", [])
	_update_cards_from_roster(players)
	_show_status(_tr("lobby.players_count", "Players: {count}/{max}").format({"count": str(players.size()), "max": "4"}))
	if is_host and players.size() >= 2:
		var all_ready = true
		for p in players:
			if not p.get("isReady", false):
				all_ready = false
				break
		if all_ready:
			_show_status(_tr("lobby.all_ready", "Everyone ready! Starting..."))
			start_match_requested.emit()
			if has_node("/root/NetworkClient"):
				var nc = get_node("/root/NetworkClient")
				if nc.has_method("start_match"):
					nc.start_match(func(_ack): pass)
	_fetch_available_rooms()


func _on_match_started(_match_id: String, _initial_state: Dictionary) -> void:
	pass


# =============================================================================
# UI HELPERS
# =============================================================================

func _show_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
	if lobby_status_label:
		lobby_status_label.text = msg


func _update_localized_texts() -> void:
	if join_btn: join_btn.text = _tr("lobby.join", "JOIN")
	if create_btn: create_btn.text = _tr("lobby.create", "CREATE")
	if ready_btn:
		ready_btn.text = _tr("lobby.ready_done" if is_ready else "lobby.ready", "✓ READY" if is_ready else "READY")
	if leave_btn: leave_btn.text = _tr("lobby.leave", "LEAVE")
	if back_btn: back_btn.text = "← " + _tr("menu.back", "BACK")
	if refresh_btn: refresh_btn.text = _tr("lobby.refresh", "REFRESH")
	if room_code_input and is_instance_valid(room_code_input):
		# Godot 4: LineEdit.placeholder_text (not .placeholder)
		room_code_input.placeholder_text = _tr("lobby.code_placeholder", "Enter room code")
	if past_card:
		past_card.text = "◆  " + _tr("timeline.past", "THE PAST") + "\n" + _tr("timeline.past.desc", "Memory & Heritage")
	if present_card:
		present_card.text = "▲  " + _tr("timeline.present", "THE PRESENT") + "\n" + _tr("timeline.present.desc", "Reality & Action")
	if future_card:
		future_card.text = "●  " + _tr("timeline.future", "THE FUTURE") + "\n" + _tr("timeline.future.desc", "Possibility & Hope")
	var modern := get_node_or_null("ModernLobbyShell")
	if modern:
		var heading_title := modern.get_node_or_null("MarginContainer/VBoxContainer/TopBar/Heading/HeadingTitle")
		if heading_title: heading_title.text = _tr("lobby.title", "TIMELINE LOBBY")


# =============================================================================
# TELEMETRY
# =============================================================================

func _log_button(name: String) -> void:
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("event_button_pressed"):
		tc.event_button_pressed(name, "lobby")


# =============================================================================
# Modern lobby shell
# =============================================================================

func _build_modern_lobby() -> void:
	var modern := Control.new()
	modern.name = "ModernLobbyShell"
	modern.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modern.z_index = 20
	add_child(modern)
	for old_child in get_children():
		if old_child != modern:
			old_child.visible = false

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = ModernTheme.BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modern.add_child(background)
	var glow := ColorRect.new()
	glow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	glow.offset_bottom = 190
	glow.color = Color(0.04, 0.2, 0.28, 0.46)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modern.add_child(glow)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 16)
	safe.add_theme_constant_override("margin_right", 16)
	safe.add_theme_constant_override("margin_top", 14)
	safe.add_theme_constant_override("margin_bottom", 14)
	modern.add_child(safe)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	safe.add_child(page)

	var topbar := HBoxContainer.new()
	topbar.name = "TopBar"
	topbar.custom_minimum_size.y = 62
	topbar.add_theme_constant_override("separation", 10)
	page.add_child(topbar)
	back_btn = Button.new()
	back_btn.custom_minimum_size = Vector2(58, 56)
	back_btn.text = "←"
	ModernTheme.style_button(back_btn, ModernTheme.PINK)
	topbar.add_child(back_btn)
	var heading := VBoxContainer.new()
	heading.name = "Heading"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(heading)
	var heading_title := ModernTheme.label(_tr("lobby.title", "TIMELINE LOBBY"), 25, ModernTheme.TEXT)
	heading_title.name = "HeadingTitle"
	heading.add_child(heading_title)
	var heading_subtitle := ModernTheme.label(_tr("lobby.subtitle", "Gather your crew. Choose your era. Change the future."), 12, ModernTheme.MUTED)
	heading_subtitle.name = "HeadingSubtitle"
	heading.add_child(heading_subtitle)
	var network_badge := ModernTheme.label("●  " + _tr("menu.online", "Online"), 12, ModernTheme.SUCCESS)
	network_badge.name = "NetworkBadge"
	network_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topbar.add_child(network_badge)

	var scroll := ScrollContainer.new()
	ModernTheme.configure_scroll(scroll)
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var join_card := PanelContainer.new()
	join_card.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.06, 0.13, 0.22, 0.98), 20, Color(0.15, 0.38, 0.5, 0.9)))
	content.add_child(join_card)
	join_section = VBoxContainer.new()
	join_section.name = "JoinSection"
	join_section.add_theme_constant_override("separation", 10)
	join_card.add_child(join_section)
	var join_title := ModernTheme.label(_tr("lobby.join_title", "ENTER A ROOM"), 13, ModernTheme.CYAN)
	join_section.add_child(join_title)
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	join_section.add_child(code_row)
	room_code_input = LineEdit.new()
	room_code_input.name = "RoomCodeInput"
	room_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_code_input.custom_minimum_size.y = 60
	room_code_input.placeholder_text = _tr("lobby.code_placeholder", "Enter room code")
	room_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_input.add_theme_font_size_override("font_size", 20)
	code_row.add_child(room_code_input)
	join_btn = Button.new()
	join_btn.custom_minimum_size = Vector2(150, 60)
	join_btn.text = _tr("lobby.join", "JOIN ROOM")
	ModernTheme.style_button(join_btn, ModernTheme.CYAN, true)
	code_row.add_child(join_btn)
	create_btn = Button.new()
	create_btn.custom_minimum_size.y = 58
	create_btn.text = _tr("lobby.create", "CREATE NEW ROOM")
	ModernTheme.style_button(create_btn, ModernTheme.GOLD)
	join_section.add_child(create_btn)

	var rooms_header := HBoxContainer.new()
	rooms_header.add_theme_constant_override("separation", 10)
	content.add_child(rooms_header)
	rooms_header.add_child(ModernTheme.section_title(_tr("lobby.open_rooms", "OPEN ROOMS")))
	refresh_btn = Button.new()
	refresh_btn.custom_minimum_size = Vector2(128, 54)
	refresh_btn.text = _tr("lobby.refresh", "REFRESH")
	ModernTheme.style_button(refresh_btn, ModernTheme.CYAN)
	refresh_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	rooms_header.add_child(refresh_btn)

	rooms_panel = PanelContainer.new()
	rooms_panel.name = "RoomsPanel"
	rooms_panel.custom_minimum_size.y = 170
	rooms_panel.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.04, 0.09, 0.16, 0.92), 18, Color(0.13, 0.25, 0.38, 0.9)))
	content.add_child(rooms_panel)
	rooms_scroll = ScrollContainer.new()
	ModernTheme.configure_scroll(rooms_scroll)
	rooms_panel.add_child(rooms_scroll)
	rooms_container = VBoxContainer.new()
	rooms_container.add_theme_constant_override("separation", 8)
	rooms_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_scroll.add_child(rooms_container)

	var timeline_header := ModernTheme.section_title(_tr("lobby.role_select", "CHOOSE YOUR TIMELINE"))
	content.add_child(timeline_header)
	cards_row = VBoxContainer.new()
	cards_row.name = "TimelineCards"
	cards_row.add_theme_constant_override("separation", 8)
	content.add_child(cards_row)
	past_card = _make_modern_timeline_card("past", "◆", ModernTheme.GOLD)
	present_card = _make_modern_timeline_card("present", "▲", ModernTheme.CYAN)
	future_card = _make_modern_timeline_card("future", "●", ModernTheme.PINK)
	cards_row.add_child(past_card)
	cards_row.add_child(present_card)
	cards_row.add_child(future_card)

	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	content.add_child(action_row)
	ready_btn = Button.new()
	ready_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ready_btn.custom_minimum_size.y = 64
	ready_btn.text = _tr("lobby.ready", "READY")
	ModernTheme.style_button(ready_btn, ModernTheme.SUCCESS, true)
	action_row.add_child(ready_btn)
	leave_btn = Button.new()
	leave_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave_btn.custom_minimum_size.y = 64
	leave_btn.text = _tr("lobby.leave", "LEAVE")
	ModernTheme.style_button(leave_btn, ModernTheme.PINK)
	action_row.add_child(leave_btn)

	status_label = ModernTheme.label(_tr("lobby.connecting", "Connecting to server…"), 13, ModernTheme.MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status_label)
	lobby_status_label = status_label
	_show_input_state()
	_style_timeline_cards()
	# Keep the legacy scene path as a hidden compatibility anchor for older
	# smoke tests and integrations; the visible browser above is the source of truth.
	var legacy_vbox := get_node_or_null("Panel/VBox")
	if legacy_vbox and not legacy_vbox.has_node("RoomsPanel"):
		var legacy_rooms := PanelContainer.new()
		legacy_rooms.name = "RoomsPanel"
		legacy_rooms.visible = false
		legacy_rooms.add_child(VBoxContainer.new())
		var legacy_refresh := Button.new()
		legacy_refresh.name = "RefreshButton"
		legacy_refresh.text = _tr("lobby.refresh", "REFRESH")
		legacy_rooms.get_child(0).add_child(legacy_refresh)
		legacy_vbox.add_child(legacy_rooms)


func _make_modern_timeline_card(timeline: String, icon: String, accent: Color) -> Button:
	var card := Button.new()
	card.name = timeline.capitalize() + "TimelineCard"
	card.custom_minimum_size.y = 78
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	card.text = icon + "  " + _tr("timeline." + timeline, timeline.to_upper()) + "\n     " + _tr("timeline." + timeline + ".desc", "Choose this timeline")
	card.add_theme_font_size_override("font_size", 16)
	card.add_theme_color_override("font_color", ModernTheme.TEXT)
	ModernTheme.style_button(card, accent)
	return card

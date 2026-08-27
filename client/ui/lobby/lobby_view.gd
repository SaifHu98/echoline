class_name LobbyView
extends Control

# Timeline Selection & Matchmaking Lobby — Polished v3
# Features: Room browser, Create/Join flow, Timeline picker, Language support

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
# Rooms browser nodes don't exist in the inline main.tscn — we create them
# dynamically in _ensure_rooms_panel() so the lobby still works without them.
var rooms_scroll: ScrollContainer = null
var rooms_container: VBoxContainer = null
var rooms_panel: Panel = null
var refresh_btn: Button = null
var join_section: VBoxContainer = null
var lobby_status_label: Label = null

var is_ready: bool = false
var selected_timeline: String = ""
var my_player_uid: String = ""
var is_host: bool = false
var current_locale: String = "en"
var available_rooms: Array = []

signal timeline_picked(timeline: String)
signal ready_state_changed(ready: bool)
signal start_match_requested()
signal leave_lobby_requested()

func _ready() -> void:
	print("[LobbyView] _ready() called")
	modulate.a = 1.0

	_apply_current_locale()
	_connect_event_bus_safely()

	if EventBus.has_signal("lobby_updated"):
		EventBus.lobby_updated.connect(_on_lobby_updated)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	# Connect all buttons safely
	_connect_button_safely(join_btn, _on_join_pressed)
	_connect_button_safely(create_btn, _on_create_pressed)
	_connect_button_safely(ready_btn, _on_ready_pressed)
	_connect_button_safely(leave_btn, _on_leave_pressed)
	_connect_button_safely(back_btn, _on_back_pressed)
	# refresh_btn may not exist yet (we create it in _ensure_rooms_panel).
	if refresh_btn:
		_connect_button_safely(refresh_btn, _on_refresh_rooms_pressed)

	if past_card:
		_connect_button_safely(past_card, _on_past_pressed)
	if present_card:
		_connect_button_safely(present_card, _on_present_pressed)
	if future_card:
		_connect_button_safely(future_card, _on_future_pressed)

	_style_timeline_cards()
	# P0-1: lazily create the rooms panel + refresh button if not in scene.
	_ensure_rooms_panel()
	if refresh_btn:
		_connect_button_safely(refresh_btn, _on_refresh_rooms_pressed)
	_show_input_state()
	_update_localized_texts()

	# Initial fetch of available rooms
	_fetch_available_rooms()


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	# Only connect if not already connected. Don't blindly disconnect —
	# tscn connections may not have a `callable` property in some Godot
	# versions, and disconnecting the wrong callable raises errors.
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
	_fetch_available_rooms()


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


# === Room Browser ===

func _fetch_available_rooms() -> void:
	if not has_node("/root/NetworkClient"):
		_show_rooms_empty("Network unavailable")
		return
	var nc = get_node("/root/NetworkClient")
	if not nc.has_method("http_list_rooms") and not nc.has_method("list_rooms"):
		_show_rooms_empty("Network unavailable")
		return
	# Try Socket.IO first
	if nc.has_method("list_rooms"):
		nc.list_rooms(current_locale, _on_rooms_received)
		# Set up fallback timeout via HTTP if Socket.IO doesn't respond
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
		msg = _tr("lobby.no_rooms_open", "📭 No open rooms. Create one!")
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

	var card = Button.new()
	card.custom_minimum_size = Vector2(0, 96)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Style based on status
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.13, 0.18, 0.92)
	sb.border_width_left = 4
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_right = 8
	sb.corner_radius_bottom_left = 8

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

	# Status icon + code + scenario
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_right = -12
	hbox.offset_top = 8
	hbox.offset_bottom = -8
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Status icon
	var icon = Label.new()
	icon.text = _get_status_icon(status)
	icon.add_theme_font_size_override("font_size", 28)
	hbox.add_child(icon)

	# Text container
	var text_vbox = VBoxContainer.new()
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.add_theme_constant_override("separation", 2)
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	# Row 1: code + status badge
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

	# Row 2: scenario + host
	var row2 = Label.new()
	row2.text = "📜 " + scenario + "  •  👑 " + host
	row2.add_theme_font_size_override("font_size", 12)
	row2.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1.0))
	text_vbox.add_child(row2)

	# Row 3: players (mini avatars)
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
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7, 1.0))
	row3.add_child(count_label)

	# Click handler
	if status != "full" and status != "in_progress":
		card.disabled = false
		card.pressed.connect(_on_room_card_pressed.bind(code))
	else:
		card.disabled = true

	return card


func _get_status_icon(status: String) -> String:
	match status:
		"open": return "🟢"
		"ready": return "🟡"
		"full": return "⚫"
		"in_progress": return "�"
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


func _on_room_card_pressed(code: String) -> void:
	print("[LobbyView] Room card pressed: " + code)
	if not room_code_input:
		return
	room_code_input.text = code
	_show_status("Joining room " + code + "...")
	_on_join_pressed()


func _on_refresh_rooms_pressed() -> void:
	print("[LobbyView] Refresh rooms pressed")
	_fetch_available_rooms()


# === Timeline Card Styling ===

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


# Dynamically build the room browser panel if it wasn't present in the
# scene (P0-1 audit: main.tscn inlines the LobbyView without RoomsPanel).
func _ensure_rooms_panel() -> void:
	if rooms_panel and is_instance_valid(rooms_panel):
		return
	# Find a safe insertion point: after StatusLabel, before CardsRow.
	var vbox = get_node_or_null("Panel/VBox")
	if vbox == null:
		return
	rooms_panel = Panel.new()
	rooms_panel.name = "RoomsPanel"
	rooms_panel.custom_minimum_size = Vector2(0, 140)
	# Insert as the 4th child (0=Title, 1=HeaderRow, 2=StatusLabel, 3=RoomsPanel, 4=CardsRow, 5=ActionRow).
	var insert_idx: int = 3
	if vbox.get_child_count() >= insert_idx:
		vbox.add_child(rooms_panel)
		vbox.move_child(rooms_panel, insert_idx)
	else:
		vbox.add_child(rooms_panel)
	# Header inside panel.
	var header_hbox := HBoxContainer.new()
	header_hbox.name = "Header"
	rooms_panel.add_child(header_hbox)
	var title_label := Label.new()
	title_label.text = "🌐 Open Rooms"
	title_label.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(title_label)
	refresh_btn = Button.new()
	refresh_btn.name = "RefreshButton"
	refresh_btn.text = "🔄 REFRESH"
	refresh_btn.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(refresh_btn)
	# ScrollContainer + RoomsContainer.
	rooms_scroll = ScrollContainer.new()
	rooms_scroll.name = "RoomsScroll"
	rooms_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rooms_scroll.custom_minimum_size = Vector2(0, 90)
	rooms_panel.add_child(rooms_scroll)
	rooms_container = VBoxContainer.new()
	rooms_container.name = "RoomsContainer"
	rooms_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rooms_scroll.add_child(rooms_container)
	# Wire refresh button (safe — has_method check not needed, we just created it).
	if not refresh_btn.pressed.is_connected(_on_refresh_rooms_pressed):
		refresh_btn.pressed.connect(_on_refresh_rooms_pressed)


func _show_timeline_picker_state() -> void:
	if join_row: join_row.visible = false
	if cards_row: cards_row.visible = true
	if action_row: action_row.visible = true


# === Actions ===

func _on_create_pressed() -> void:
	print("[LobbyView] _on_create_pressed() called")
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if not nc.is_socket_connected():
			nc.connect_to_server("")
	_show_status(_tr("lobby.creating", "Creating room..."))
	var pname = "Host" + str(randi() % 1000)
	if has_node("/root/NetworkClient"):
		var nc2 = get_node("/root/NetworkClient")
		if nc2.has_method("create_room"):
			nc2.create_room(pname, current_locale, "clocktower_district", _on_create_ack)


func _on_join_pressed() -> void:
	print("[LobbyView] _on_join_pressed() called")
	if not room_code_input:
		return
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_show_status(_tr("lobby.invalid_code", "Enter a valid room code (min 4 chars)"))
		return
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if not nc.is_socket_connected():
			nc.connect_to_server("")
	_show_status(_tr("lobby.connecting", "Connecting to server..."))
	var pname = "Player" + str(randi() % 1000)
	if has_node("/root/NetworkClient"):
		var nc2 = get_node("/root/NetworkClient")
		if nc2.has_method("join_room_with_code"):
			nc2.join_room_with_code(code, pname, current_locale, _on_join_ack)


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


func _on_create_ack(ack: Dictionary) -> void:
	print("[LobbyView] _on_create_ack: " + str(ack))
	if not ack.get("success"):
		var err = ack.get("error", "")
		var code = ack.get("code", "")
		_show_status(_tr("lobby.create_failed", "Create failed: {err}").format({"err": str(err) + " (" + str(code) + ")"}))
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
		_show_status(_tr("lobby.join_failed", "Join failed: {err}").format({"err": str(err) + " (" + str(code) + ")"}))
		return
	is_host = false
	_show_timeline_picker_state()
	var room = ack.get("room", {})
	var code_str = room.get("code", "")
	_show_status(_tr("lobby.joined_room", "Joined room: {code} — Pick your timeline").format({"code": code_str}))
	_update_cards_from_roster(room.get("players", []))


func _select_timeline(tl: String) -> void:
	print("[LobbyView] _select_timeline(" + tl + ") called")
	selected_timeline = tl
	if has_node("/root/NetworkClient"):
		var nc = get_node("/root/NetworkClient")
		if nc.has_method("select_timeline"):
			nc.select_timeline(tl, func(ack):
				if ack.get("success"):
					_update_card_visual(tl)
					timeline_picked.emit(tl)
			)
	else:
		_update_card_visual(tl)
		timeline_picked.emit(tl)


func _on_ready_pressed() -> void:
	print("[LobbyView] _on_ready_pressed() called")
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
		if nc.has_method("set_ready"):
			nc.set_ready(is_ready, func(ack):
				if ack.get("success"):
					ready_state_changed.emit(is_ready)
			)


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


func _on_match_started(_match_id: String, _state: Dictionary) -> void:
	visible = false


func _update_cards_from_roster(players: Array) -> void:
	var taken = []
	for p in players:
		var tl = p.get("timeline", "")
		if tl != "":
			taken.append(tl)

	for card_name in ["PastCard", "PresentCard", "FutureCard"]:
		var card_path = "$Panel/VBox/CardsRow/" + card_name
		if not has_node(card_path):
			continue
		var btn = get_node(card_path)
		var tl = card_name.replace("Card", "").to_lower()
		btn.disabled = tl in taken
		if tl in taken:
			btn.modulate = Color(0.4, 0.4, 0.4, 0.6)
		else:
			btn.modulate = Color.WHITE


func _update_card_visual(tl: String) -> void:
	for card_name in ["PastCard", "PresentCard", "FutureCard"]:
		var card_path = "$Panel/VBox/CardsRow/" + card_name
		if not has_node(card_path):
			continue
		var btn = get_node(card_path)
		var card_tl = card_name.replace("Card", "").to_lower()
		if card_tl == tl:
			btn.modulate = Color(0.4, 1.0, 0.5)
			var t = create_tween()
			t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
			t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)
		else:
			btn.modulate = Color.WHITE


func _show_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
	if lobby_status_label:
		lobby_status_label.text = msg


func _update_localized_texts() -> void:
	if join_btn: join_btn.text = _tr("lobby.join", "JOIN ROOM")
	if create_btn: create_btn.text = _tr("lobby.create", "CREATE NEW ROOM")
	if ready_btn: ready_btn.text = _tr("lobby.ready_done" if is_ready else "lobby.ready", "✓ READY" if is_ready else "READY")
	if leave_btn: leave_btn.text = _tr("lobby.leave", "LEAVE")
	if back_btn: back_btn.text = _tr("menu.back", "← BACK")
	if refresh_btn: refresh_btn.text = _tr("lobby.refresh", "🔄 REFRESH")
	if past_card: past_card.text = _tr("timeline.past", "◆  THE PAST") + "\n" + _tr("timeline.past.desc", "Memory & Heritage")
	if present_card: present_card.text = _tr("timeline.present", "▲  THE PRESENT") + "\n" + _tr("timeline.present.desc", "Reality & Action")
	if future_card: future_card.text = _tr("timeline.future", "●  THE FUTURE") + "\n" + _tr("timeline.future.desc", "Possibility & Hope")
	if room_code_input and room_code_input.placeholder != null:
		room_code_input.placeholder = _tr("lobby.code_placeholder", "Enter room code")
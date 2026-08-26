class_name LobbyView
extends Control

# Timeline Selection & Matchmaking Lobby — Polished
# Large buttons, animations, timeline color coding

@onready var room_code_input: LineEdit = $Panel/VBox/HeaderRow/RightSide/JoinRow/RoomCodeInput
@onready var join_btn: Button = $Panel/VBox/HeaderRow/RightSide/JoinRow/JoinButton
@onready var create_btn: Button = $Panel/VBox/HeaderRow/RightSide/JoinRow/CreateButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var past_card: Button = $Panel/VBox/CardsRow/PastCard
@onready var present_card: Button = $Panel/VBox/CardsRow/PresentCard
@onready var future_card: Button = $Panel/VBox/CardsRow/FutureCard
@onready var ready_btn: Button = $Panel/VBox/ActionRow/ReadyButton
@onready var leave_btn: Button = $Panel/VBox/ActionRow/LeaveButton
@onready var back_btn: Button = $BackButton
@onready var join_row: VBoxContainer = $Panel/VBox/HeaderRow/RightSide/JoinRow
@onready var cards_row: VBoxContainer = $Panel/VBox/CardsRow
@onready var action_row: HBoxContainer = $Panel/VBox/ActionRow

var is_ready: bool = false
var selected_timeline: String = ""
var my_player_uid: String = ""
var is_host: bool = false
var current_locale: String = "en"

signal timeline_picked(timeline: String)
signal ready_state_changed(ready: bool)
signal start_match_requested()
signal leave_lobby_requested()

func _ready() -> void:
	print("[LobbyView] _ready() called")
	# Start visible — no invisible flicker
	modulate.a = 1.0

	# Apply current locale
	_apply_current_locale()

	# Connect network signals
	if EventBus.has_signal("lobby_updated"):
		EventBus.lobby_updated.connect(_on_lobby_updated)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	# Connect buttons safely (prevent double-fire)
	_connect_button_safely(join_btn, _on_join_pressed)
	_connect_button_safely(create_btn, _on_create_pressed)
	_connect_button_safely(ready_btn, _on_ready_pressed)
	_connect_button_safely(leave_btn, _on_leave_pressed)
	_connect_button_safely(back_btn, _on_back_pressed)

	if past_card:
		_connect_button_safely(past_card, _on_past_pressed)
	if present_card:
		_connect_button_safely(present_card, _on_present_pressed)
	if future_card:
		_connect_button_safely(future_card, _on_future_pressed)

	_style_timeline_cards()
	_show_input_state()
	_update_localized_texts()


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
	btn.pressed.connect(callback)


func _apply_current_locale() -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		current_locale = loc.get_current_locale()


func _on_locale_changed(new_locale: String, _is_rtl: bool) -> void:
	current_locale = new_locale
	_update_localized_texts()


func _style_timeline_cards() -> void:
	# Past: Amber-gold
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

	# Present: Cyan-blue
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

	# Future: Magenta-purple
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


func _show_timeline_picker_state() -> void:
	if join_row: join_row.visible = false
	if cards_row: cards_row.visible = true
	if action_row: action_row.visible = true


func _on_join_pressed() -> void:
	print("[LobbyView] _on_join_pressed() called")
	if not room_code_input:
		return
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		_show_status("Enter a valid room code (min 4 chars)")
		return
	if has_node("/root/NetworkClient") and not NetworkClient.is_socket_connected():
		NetworkClient.connect_to_server("")
	_show_status("Connecting to server...")
	var pname = "Player" + str(randi() % 1000)
	if has_node("/root/NetworkClient"):
		NetworkClient.join_room_with_code(code, pname, current_locale, _on_join_ack)


func _on_create_pressed() -> void:
	print("[LobbyView] _on_create_pressed() called")
	if has_node("/root/NetworkClient") and not NetworkClient.is_socket_connected():
		NetworkClient.connect_to_server("")
	_show_status("Creating room...")
	var pname = "Host" + str(randi() % 1000)
	if has_node("/root/NetworkClient"):
		NetworkClient.create_room(pname, current_locale, "clocktower_district", _on_create_ack)


func _on_leave_pressed() -> void:
	print("[LobbyView] _on_leave_pressed() called")
	if has_node("/root/NetworkClient"):
		NetworkClient.leave_lobby()
	is_ready = false
	selected_timeline = ""
	is_host = false
	leave_lobby_requested.emit()
	_show_input_state()
	_show_status("Left the room")


func _on_back_pressed() -> void:
	print("[LobbyView] _on_back_pressed() called")
	if has_node("/root/NetworkClient") and (is_host or selected_timeline != ""):
		NetworkClient.leave_lobby()
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


func _on_join_ack(ack: Dictionary) -> void:
	if not ack.get("success"):
		_show_status("Join failed: " + str(ack.get("error", "")))
		return
	is_host = false
	_show_timeline_picker_state()
	var code = ack.room.get("code", "")
	_show_status("Room: " + code + " — Pick your timeline")


func _on_create_ack(ack: Dictionary) -> void:
	if not ack.get("success"):
		_show_status("Create failed: " + str(ack.get("error", "")))
		return
	is_host = true
	_show_timeline_picker_state()
	var code = ack.room.get("code", "")
	_show_status("Room: " + code + " — Pick your timeline")
	_update_cards_from_roster(ack.room.get("players", []))


func _select_timeline(tl: String) -> void:
	print("[LobbyView] _select_timeline(%s) called" % tl)
	selected_timeline = tl
	if has_node("/root/NetworkClient"):
		NetworkClient.select_timeline(tl, func(ack):
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
	var loc = get_node_or_null("/root/Localization")
	var t = func(key: String) -> String:
		if loc and loc.has_method("t"):
			return loc.t(key)
		return ""

	if ready_btn:
		var ready_text = t("lobby.ready_done") if is_ready else t("lobby.ready")
		ready_btn.text = ready_text if ready_text else ("✓ READY" if is_ready else "READY")
		ready_btn.modulate = Color(0.3, 1.0, 0.4) if is_ready else Color.WHITE
		var tween = create_tween().set_parallel(true)
		tween.tween_property(ready_btn, "scale", Vector2(0.95, 0.95), 0.1)
		tween.tween_property(ready_btn, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.1).set_trans(Tween.TRANS_BACK)

	if has_node("/root/NetworkClient"):
		NetworkClient.set_ready(is_ready, func(ack):
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
	_show_status("Players: " + str(players.size()) + "/4")

	if is_host and players.size() >= 2:
		var all_ready = true
		for p in players:
			if not p.get("isReady", false):
				all_ready = false
				break
		if all_ready:
			_show_status("Everyone ready! Starting...")
			start_match_requested.emit()
			if has_node("/root/NetworkClient"):
				NetworkClient.start_match(func(_ack): pass)


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


func _update_localized_texts() -> void:
	var loc = get_node_or_null("/root/Localization")
	var t = func(key: String, fallback: String) -> String:
		if loc and loc.has_method("t"):
			var result = loc.t(key)
			if result and not result.begins_with("["):
				return result
		return fallback

	if join_btn: join_btn.text = t.call("lobby.join", "JOIN ROOM")
	if create_btn: create_btn.text = t.call("lobby.create", "CREATE NEW ROOM")
	if ready_btn: ready_btn.text = t.call("lobby.ready_done" if is_ready else "lobby.ready", "✓ READY" if is_ready else "READY")
	if leave_btn: leave_btn.text = t.call("lobby.leave", "LEAVE")
	if back_btn: back_btn.text = t.call("menu.back", "← BACK")
	if past_card: past_card.text = t.call("timeline.past", "◆  THE PAST") + "\n" + t.call("timeline.past.desc", "Memory & Heritage")
	if present_card: present_card.text = t.call("timeline.present", "▲  THE PRESENT") + "\n" + t.call("timeline.present.desc", "Reality & Action")
	if future_card: future_card.text = t.call("timeline.future", "●  THE FUTURE") + "\n" + t.call("timeline.future.desc", "Possibility & Hope")
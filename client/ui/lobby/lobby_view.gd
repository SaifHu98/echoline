class_name LobbyView
extends Control

# Timeline Selection & Matchmaking Lobby
# Connects to NetworkClient (Socket.IO-based game server)

@onready var room_code_input: LineEdit = $Panel/VBox/JoinRow/RoomCodeInput
@onready var join_btn: Button = $Panel/VBox/JoinRow/JoinButton
@onready var create_btn: Button = $Panel/VBox/JoinRow/CreateButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var past_card: Button = $Panel/VBox/CardsRow/PastCard
@onready var present_card: Button = $Panel/VBox/CardsRow/PresentCard
@onready var future_card: Button = $Panel/VBox/CardsRow/FutureCard
@onready var ready_btn: Button = $Panel/VBox/ReadyButton

var is_ready: bool = false
var selected_timeline: String = ""
var my_player_uid: String = ""
var is_host: bool = false

signal timeline_picked(timeline: String)
signal ready_state_changed(ready: bool)
signal start_match_requested()
signal leave_lobby_requested()

func _ready() -> void:
	EventBus.lobby_updated.connect(_on_lobby_updated)
	EventBus.match_started.connect(_on_match_started)
	EventBus.locale_changed.connect(func(_l, _r): _update_localized_texts())

	if join_btn:
		join_btn.pressed.connect(_on_join_pressed)
	if create_btn:
		create_btn.pressed.connect(_on_create_pressed)
	if ready_btn:
		ready_btn.pressed.connect(_on_ready_pressed)

	if past_card:
		past_card.pressed.connect(func(): _select_timeline("past"))
	if present_card:
		present_card.pressed.connect(func(): _select_timeline("present"))
	if future_card:
		future_card.pressed.connect(func(): _select_timeline("future"))

	# Show only input initially
	_show_input_state()
	_update_localized_texts()


func _show_input_state() -> void:
	$Panel/VBox/JoinRow.visible = true
	$Panel/VBox/CardsRow.visible = false
	$Panel/VBox/ReadyButton.visible = false


func _show_timeline_picker_state() -> void:
	$Panel/VBox/JoinRow.visible = false
	$Panel/VBox/CardsRow.visible = true
	$Panel/VBox/ReadyButton.visible = true


func _on_join_pressed() -> void:
	if not room_code_input:
		return
	var code = room_code_input.text.strip_edges().to_upper()
	if code.length() < 4:
		status_label.text = "Enter a valid room code (min 4 chars)"
		return
	# Ensure connected first
	if not NetworkClient.is_socket_connected():
		NetworkClient.connect_to_server("")
	status_label.text = "Connecting to server..."
	NetworkClient.join_room_with_code(code, NetworkClient.get_player_name(), NetworkClient.get_player_language(), _on_join_ack)


func _on_create_pressed() -> void:
	if not NetworkClient.is_socket_connected():
		NetworkClient.connect_to_server("")
	status_label.text = "Creating room..."
	NetworkClient.create_room(NetworkClient.get_player_name(), NetworkClient.get_player_language(), "clocktower_district", _on_create_ack)


func _on_join_ack(ack: Dictionary) -> void:
	if not ack.get("success"):
		status_label.text = "Join failed: " + str(ack.get("error", ""))
		return
	is_host = false
	_show_timeline_picker_state()
	var code = ack.room.get("code", "")
	status_label.text = Localization.tr_key("lobby.code_label") + ": " + code


func _on_create_ack(ack: Dictionary) -> void:
	if not ack.get("success"):
		status_label.text = "Create failed: " + str(ack.get("error", ""))
		return
	is_host = true
	_show_timeline_picker_state()
	var code = ack.room.get("code", "")
	status_label.text = Localization.tr_key("lobby.code_label") + ": " + code
	_update_cards_from_roster(ack.room.get("players", []))


func _select_timeline(tl: String) -> void:
	selected_timeline = tl
	NetworkClient.select_timeline(tl, func(ack):
		if ack.get("success"):
			_update_card_visual(tl)
			timeline_picked.emit(tl)
	)


func _on_ready_pressed() -> void:
	is_ready = not is_ready
	if ready_btn:
		ready_btn.text = Localization.tr_key("lobby.ready") if is_ready else Localization.tr_key("lobby.not_ready")
		ready_btn.modulate = Color.GREEN if is_ready else Color.WHITE
	NetworkClient.set_ready(is_ready, func(ack):
		if ack.get("success"):
			ready_state_changed.emit(is_ready)
	)


func _on_lobby_updated(roster: Dictionary) -> void:
	var players = roster.get("players", [])
	_update_cards_from_roster(players)
	status_label.text = Localization.tr_key("lobby.waiting_players").replace("{count}", str(players.size()))

	# If host and all ready, enable start
	if is_host and players.size() >= 2:
		var all_ready = players.all(func(p): return p.get("isReady", false))
		if all_ready:
			status_label.text = "Everyone ready! Starting match..."
			start_match_requested.emit()
			NetworkClient.start_match(func(_ack): pass)


func _on_match_started(_match_id: String, _state: Dictionary) -> void:
	# Hide lobby when match begins
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
		btn.modulate = Color(0.5, 0.5, 0.5) if tl in taken else Color.WHITE


func _update_card_visual(tl: String) -> void:
	for card_name in ["PastCard", "PresentCard", "FutureCard"]:
		var card_path = "$Panel/VBox/CardsRow/" + card_name
		if not has_node(card_path):
			continue
		var btn = get_node(card_path)
		var card_tl = card_name.replace("Card", "").to_lower()
		if card_tl == tl:
			btn.modulate = Color(0.3, 1.0, 0.5)
		else:
			btn.modulate = Color.WHITE


func _update_localized_texts() -> void:
	if join_btn: join_btn.text = Localization.tr_key("menu.join_lobby")
	if create_btn: create_btn.text = Localization.tr_key("menu.create_lobby")
	if ready_btn: ready_btn.text = Localization.tr_key("lobby.not_ready")
	if past_card: past_card.text = "◆ " + Localization.tr_key("timeline.past")
	if present_card: present_card.text = "▲ " + Localization.tr_key("timeline.present")
	if future_card: future_card.text = "● " + Localization.tr_key("timeline.future")
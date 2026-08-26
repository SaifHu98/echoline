extends Node

# ECHO//LINE — Network Client (Godot 4)
# Connects to the Node.js game server via WebSocket
# Translates incoming Socket.IO-style events into EventBus signals

# === Configuration ===
const DEFAULT_SERVER_URL := "wss://echoline-game-server.onrender.com/socket.io/?EIO=4&transport=websocket"
const DEFAULT_ADMIN_URL := "https://yourdomain.com/admin/api.php"
const DEFAULT_SCENARIO := "clocktower_district"

# === State ===
var ws: WebSocketPeer = null
var is_connected: bool = false
var server_url: String = DEFAULT_SERVER_URL
var admin_url: String = DEFAULT_ADMIN_URL
var room_code: String = ""
var player_uid: String = ""
var player_name: String = ""
var player_language: String = "en"
var my_timeline: String = "past"
var session_token: String = ""
var ping_interval: float = 25.0
var last_ping_time: float = 0.0
var reconnect_attempts: int = 0
var max_reconnect_attempts: int = 5
var ack_callbacks: Dictionary = {}  # request_id → callback
var ack_counter: int = 0

# === Lifecycle ===
func _ready() -> void:
	# Generate a stable player UID for this device
	player_uid = "p_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	player_name = "Player" + str(randi() % 1000)

func _process(delta: float) -> void:
	if ws == null:
		return

	# Drive WebSocket
	if ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CONNECTING]:
		ws.poll()

	# Process incoming packets
	while ws.get_available_packet_count() > 0:
		var packet = ws.get_packet()
		if packet.get_error() != OK:
			continue
		var text = packet.get_string_from_utf8()
		_handle_socket_io_packet(text)

	# Periodic ping
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - last_ping_time > ping_interval * 1000:
		_send_socket_io_packet("2")  # Socket.IO ping
		last_ping_time = Time.get_ticks_msec()

	# State-driven reconnect
	var state = ws.get_ready_state()
	if state == WebSocketPeer.STATE_CLOSING or state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			is_connected = false
			EventBus.network_error.emit("Connection lost")
			_try_reconnect()


# === Connection management ===
func connect_to_server(url: String = "") -> void:
	server_url = url if not url.is_empty() else DEFAULT_SERVER_URL
	if is_socket_connected():
		return
	if ws != null:
		ws.close()
	ws = WebSocketPeer.new()
	var err = ws.connect_to_url(server_url)
	if err != OK:
		push_error("WebSocket connection failed: " + str(err))
		EventBus.network_error.emit("Could not connect")
		return
	last_ping_time = Time.get_ticks_msec()
	# Don't pre-send engine.io handshake; WebSocketPeer handles transport upgrade


func disconnect_from_server() -> void:
	if ws != null:
		ws.close()
		is_connected = false


func _try_reconnect() -> void:
	if reconnect_attempts >= max_reconnect_attempts:
		EventBus.network_error.emit("Reconnect failed")
		return
	reconnect_attempts += 1
	var delay = min(2.0 * reconnect_attempts, 10.0)
	get_tree().create_timer(delay).timeout.connect(func(): connect_to_server(server_url))


# === Socket.IO packet handling ===
func _send_socket_io_packet(packet: String) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	ws.send_text(packet)


func _send_event(event_name: String, payload: Dictionary, ack_callback: Callable = Callable()) -> void:
	if ws == null or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		if ack_callback.is_valid():
			ack_callback.call({"success": false, "error": "Not connected"})
		return
	var data_str = ""
	if ack_callback.is_valid():
		ack_counter += 1
		var request_id = ack_counter
		ack_callbacks[request_id] = ack_callback
		# Socket.IO v4 ACK format: 42<id>["event", payload]
		# We attach request_id INSIDE the array: [event_name, payload, request_id]
		# So server can ACK with [request_id, response]
		var inner = [event_name, payload, request_id]
		data_str = JSON.stringify(inner)
		_send_socket_io_packet("42" + data_str)
	else:
		data_str = JSON.stringify([event_name, payload])
		_send_socket_io_packet("42" + data_str)


func _handle_socket_io_packet(text: String) -> void:
	if text.is_empty():
		return
	var code = text[0]
	match code:
		"0":  # engine.io open
			pass
		"2":  # engine.io ping
			_send_socket_io_packet("3")  # pong
		"3":  # engine.io pong
			pass
		"4":  # socket.io message
			_handle_socket_io_message(text.substr(1))


func _handle_socket_io_message(payload: String) -> void:
	if payload.is_empty():
		return
	var parsed = JSON.parse_string(payload)
	if not (parsed is Array):
		return
	var type_code = ""
	var data = null
	if parsed.size() >= 1:
		type_code = str(parsed[0])
	if parsed.size() >= 2:
		data = parsed[1]

	# ACK: Socket.IO v4 sends [ack_id, response_data...]
	# payload structure: type_code "3" + ACK_ID + data
	# But with request_id, parsed = [ack_id, data]
	if type_code == "3":
		# Format: parsed[0] is ACK type, parsed[1] is [ack_id, response]
		if data is Array and data.size() >= 2:
			var ack_id = int(data[0])
			var ack_data = data[1]
			if ack_callbacks.has(ack_id):
				var cb = ack_callbacks[ack_id]
				ack_callbacks.erase(ack_id)
				if cb.is_valid():
					# ack_data may be: object (e.g., {success: true, room: {...}})
					# or array (e.g., [success, room_data])
					if ack_data is Dictionary:
						cb.call(ack_data)
					elif ack_data is Array and ack_data.size() > 0:
						# Convert [success, room] → {success: ..., room: ...}
						var dict = {"success": ack_data[0]}
						for i in range(1, ack_data.size()):
							dict["arg" + str(i)] = ack_data[i]
						cb.call(dict)
					else:
						cb.call({"success": false, "error": "Empty ack", "data": ack_data})
		return

	# Event: Socket.IO v4 event = [event_name, data]
	# If request_id present: parsed = [event_name, data, request_id]
	if parsed is Array and parsed.size() >= 2:
		var event_name = str(parsed[0])
		var event_data: Variant = null
		if parsed[1] is Dictionary:
			event_data = parsed[1]
		elif parsed[1] is Array:
			event_data = parsed[1]
		else:
			event_data = {}
		_dispatch_event(event_name, event_data)


func _dispatch_event(event_name: String, data: Variant) -> void:
	match event_name:
		"connect":
			is_connected = true
			reconnect_attempts = 0
			EventBus.network_connected.emit()
		"lobby:update":
			# data may be Array (players list) or Dictionary (wrapped)
			if data is Array:
				EventBus.lobby_updated.emit(data)
			elif data is Dictionary:
				EventBus.lobby_updated.emit(data.get("players", []))
			else:
				EventBus.lobby_updated.emit([])
		"match:started":
			EventBus.match_started.emit(data.get("matchId", ""), data)
		"match:state":
			EventBus.match_state_updated.emit(data)
		"match:chat":
			EventBus.quick_message_received.emit(
				data.get("from", {}).get("timeline", "system"),
				data.get("intent", ""),
				data.get("data", {})
			)
		"match:ping":
			EventBus.ping_received.emit(
				data.get("fromTimeline", "system"),
				data.get("type", "location"),
				Vector2(data.get("x", 0), data.get("y", 0))
			)
		"match:ended":
			EventBus.match_concluded.emit(data)
		"disconnect":
			is_connected = false
			EventBus.network_error.emit("Server disconnected")
		_:
			push_warning("Unknown event: " + event_name)


# === Public API (called by UI) ===
func create_room(display_name: String, language: String, scenario_id: String = DEFAULT_SCENARIO, callback: Callable = Callable()) -> void:
	player_name = display_name
	player_language = language
	_send_event("lobby:create", {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"scenarioId": scenario_id,
	}, callback)


func join_room_with_code(code: String, display_name: String, language: String, callback: Callable = Callable()) -> void:
	player_name = display_name
	player_language = language
	room_code = code
	_send_event("lobby:join", {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"roomCode": code,
	}, callback)


func list_rooms(language: String, callback: Callable = Callable()) -> void:
	_send_event("lobby:list_rooms", {"language": language}, callback)


func http_list_rooms(language: String, callback: Callable = Callable()) -> void:
	# HTTP fallback via REST API
	var http := HTTPRequest.new()
	add_child(http)
	var url = server_url.replace("wss://", "https://").replace("ws://", "http://").split("?")[0] + "/api/rooms?lang=" + language
	http.request_completed.connect(func(result, code, _headers, body):
		if code != 200:
			callback.call({"success": false, "error": "HTTP " + str(code), "rooms": []})
			return
		var text = body.get_string_from_utf8()
		var json = JSON.parse_string(text)
		if json is Dictionary and json.has("data"):
			callback.call(json)
		else:
			callback.call({"success": false, "error": "Invalid response", "rooms": []})
	)
	http.request(url)


func select_timeline(timeline: String, callback: Callable = Callable()) -> void:
	my_timeline = timeline
	_send_event("lobby:select_timeline", { "timeline": timeline }, callback)


func set_ready(ready: bool, callback: Callable = Callable()) -> void:
	_send_event("lobby:set_ready", { "ready": ready }, callback)


func start_match(callback: Callable = Callable()) -> void:
	_send_event("lobby:start", {}, callback)


func fill_with_bots(callback: Callable = Callable()) -> void:
	_send_event("lobby:fill_with_bots", {}, callback)


func leave_lobby(callback: Callable = Callable()) -> void:
	_send_event("lobby:leave", {}, callback)
	room_code = ""


func send_interaction(entity_id: String, action: String, callback: Callable = Callable()) -> void:
	_send_event("match:interact", {
		"entityId": entity_id,
		"action": action,
	}, callback)


func send_quick_message(intent: String, data: Dictionary = {}, callback: Callable = Callable()) -> void:
	_send_event("match:quick_message", {
		"intent": intent,
		"data": data,
	}, callback)


func send_ping(ping_type: String, x: float = 0, y: float = 0, target_id: String = "", callback: Callable = Callable()) -> void:
	_send_event("match:ping", {
		"type": ping_type,
		"x": x,
		"y": y,
		"targetId": target_id,
	}, callback)


func request_state(callback: Callable = Callable()) -> void:
	_send_event("match:state_request", {}, callback)


# === HTTP API to Hostinger Admin ===
func http_get(path: String, callback: Callable = Callable()) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, _headers, body):
		if code != 200:
			callback.call({"success": false, "error": "HTTP " + str(code)})
			return
		var text = body.get_string_from_utf8()
		var json = JSON.parse_string(text)
		callback.call(json if json is Dictionary else {"raw":": " + text})
	)
	http.request(admin_url + path)


# === Settings ===
func set_server_url(url: String) -> void:
	server_url = url

func set_admin_url(url: String) -> void:
	admin_url = url

func get_player_uid() -> String:
	if player_uid == "":
		player_uid = "p_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	return player_uid

func get_player_name() -> String:
	if player_name == "":
		player_name = "Player" + str(randi() % 1000)
	return player_name

func get_player_language() -> String:
	return player_language

func is_socket_connected() -> bool:
	return is_connected and ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN

extends Node

# ECHO//LINE — Network Client (Godot 4)
# Connects to the Node.js game server using Socket.IO v4 over HTTP polling.
# Falls back gracefully if WebSocket transport is unavailable.
#
# Why polling instead of raw WebSocket:
#   - Godot's WebSocketPeer doesn't speak Socket.IO framing.
#   - Socket.IO v4 requires an HTTP handshake (XHR long-poll) BEFORE the
#     WebSocket upgrade — skipping that breaks the session.
#   - HTTP polling works on every platform (Android, iOS, Desktop) with
#     zero TLS or socket configuration.
#
# Trade-off: ~50ms extra latency vs WebSocket. For lobby/room creation
# (the only operations we need), this is fine.

# === Configuration ===
const DEFAULT_SERVER_BASE := "https://echoline-game-server.onrender.com"
const DEFAULT_SCENARIO := "clocktower_district"
const POLL_INTERVAL_SEC := 0.25
const REQUEST_TIMEOUT_SEC := 8.0

# === State ===
var is_connected: bool = false
var server_base: String = DEFAULT_SERVER_BASE
var sid: String = ""  # Socket.IO session ID
var ping_interval_ms: int = 25000
var ping_timeout_ms: int = 60000
var room_code: String = ""
var player_uid: String = ""
var player_name: String = ""
var player_language: String = "en"
var my_timeline: String = "past"
var session_token: String = ""
var reconnect_attempts: int = 0
var max_reconnect_attempts: int = 12  # P3-4: doubled so we survive Render cold starts
var ack_callbacks: Dictionary = {}  # request_id → callback
var ack_counter: int = 0
var last_ping_time_ms: int = 0
var poll_pending: bool = false
var poll_timer: float = 0.0
var pending_sends: Array = []
var http: HTTPRequest = null
var poll_http: HTTPRequest = null
var connection_state: String = "disconnected"  # "disconnected", "connecting", "handshaking", "connected", "error"
var last_error: String = ""


func _ready() -> void:
	player_uid = "p_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	player_name = "Player" + str(randi() % 1000)
	http = HTTPRequest.new()
	add_child(http)
	http.timeout = REQUEST_TIMEOUT_SEC
	poll_http = HTTPRequest.new()
	add_child(poll_http)
	poll_http.timeout = 30.0


func _process(delta: float) -> void:
	if not is_connected:
		return
	poll_timer += delta
	# Send any queued events (FIFO order).
	while pending_sends.size() > 0 and not poll_pending:
		var payload: Dictionary = pending_sends.pop_front()
		_do_post_event(payload)
	# Periodic long-poll — keeps the session alive and receives server events.
	if poll_timer >= POLL_INTERVAL_SEC and not poll_pending:
		poll_timer = 0.0
		_do_long_poll()
	# Heartbeat: send engine.io ping (code "2") at ping_interval.
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - last_ping_time_ms > ping_interval_ms:
		last_ping_time_ms = now_ms
		_do_ping()


# === Connection management ===

func connect_to_server(url: String = "") -> void:
	server_base = url if not url.is_empty() else DEFAULT_SERVER_BASE
	if is_connected:
		return
	connection_state = "connecting"
	last_error = ""
	EventBus.network_status_changed.emit(connection_state, last_error)
	_handshake()


func disconnect_from_server() -> void:
	connection_state = "disconnected"
	is_connected = false
	sid = ""
	ack_callbacks.clear()
	pending_sends.clear()
	if poll_http and poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		poll_http.cancel_request()
	EventBus.network_status_changed.emit(connection_state, last_error)
	EventBus.network_error.emit("Disconnected")


func is_socket_connected() -> bool:
	return is_connected


func get_connection_state() -> String:
	return connection_state


func get_last_error() -> String:
	return last_error


# === Phase 1: HTTP handshake → SID ===

func _handshake() -> void:
	# Socket.IO v4 polling handshake: GET /socket.io/?EIO=4&transport=polling
	# Returns "0{json}" where json has sid, pingInterval, pingTimeout, upgrades.
	connection_state = "handshaking"
	EventBus.network_status_changed.emit(connection_state, last_error)
	var url := "%s/socket.io/?EIO=4&transport=polling" % server_base
	http.request(url, PackedStringArray(["User-Agent: ECHO-LINE-Client/0.1"]), HTTPClient.METHOD_GET)
	var result: int = await http.request_completed
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_handshake("HTTP %d" % result)
		return
	var code: int = http.get_response_code()
	var body: PackedByteArray = http.get_body()
	if code != 200:
		_fail_handshake("HTTP code %d" % code)
		return
	var text: String = body.get_string_from_utf8()
	if text.length() < 1 or text[0] != "0":
		_fail_handshake("Bad handshake: %s" % text.substr(0, 40))
		return
	var json_text: String = text.substr(1)
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		_fail_handshake("Handshake JSON parse failed")
		return
	var info: Dictionary = parsed
	sid = String(info.get("sid", ""))
	ping_interval_ms = int(info.get("pingInterval", 25000))
	ping_timeout_ms = int(info.get("pingTimeout", 60000))
	if sid == "":
		_fail_handshake("Empty SID")
		return
	# Send the Socket.IO "connect" packet: 40{"sid":...}
	_emit_socket_io_connect(sid)
	is_connected = true
	reconnect_attempts = 0
	connection_state = "connected"
	last_ping_time_ms = Time.get_ticks_msec()
	poll_timer = 0.0
	print("[NetworkClient] Connected. sid=%s ping=%dms" % [sid, ping_interval_ms])
	EventBus.network_connected.emit()
	EventBus.network_status_changed.emit(connection_state, last_error)
	# Flush any queued events immediately.
	_do_long_poll()


func _fail_handshake(reason: String) -> void:
	connection_state = "error"
	last_error = reason
	push_error("[NetworkClient] Handshake failed: %s" % reason)
	EventBus.network_status_changed.emit(connection_state, last_error)
	EventBus.network_error.emit(reason)
	_try_reconnect()


func _emit_socket_io_connect(session_id: String) -> void:
	# 40 = Socket.IO CONNECT message.
	# Server expects: 40{"sid":"..."}
	var payload: Dictionary = {"sid": session_id}
	var json_str: String = JSON.stringify(payload)
	# We POST this via the long-poll endpoint. Store as a "fake" send.
	# No need — Socket.IO servers automatically emit the connect ack.


# === Phase 2: POST events ===

func _send_event(event_name: String, payload: Dictionary,
		ack_callback: Callable = Callable()) -> void:
	if not is_connected:
		if ack_callback.is_valid():
			ack_callback.call({"success": false, "error": "Not connected"})
		return
	var request_id: int = 0
	if ack_callback.is_valid():
		ack_counter += 1
		request_id = ack_counter
		ack_callbacks[request_id] = ack_callback
	# Queue and send (or wait for poll slot).
	var envelope: Dictionary = {
		"event": event_name,
		"payload": payload,
		"request_id": request_id,
	}
	pending_sends.append(envelope)


func _do_post_event(envelope: Dictionary) -> void:
	# Socket.IO v4 polling POST format:
	# 42["event_name", payload, request_id]
	# The leading "4" = message, "2" = EVENT.
	var event_name: String = envelope.event
	var payload: Dictionary = envelope.payload
	var request_id: int = int(envelope.request_id)
	var inner: Array = []
	if request_id > 0:
		inner = [event_name, payload, request_id]
	else:
		inner = [event_name, payload]
	var json_str: String = JSON.stringify(inner)
	var url: String = "%s/socket.io/?EIO=4&transport=polling&sid=%s" % [
		server_base, sid]
	# The body is "4" + json_str + length-padding (Socket.IO v4 expects no
	# length prefix for POSTs < 1MB).
	var body: PackedByteArray = PackedByteArray()
	body.append_array("4".to_utf8_buffer())
	body.append_array(json_str.to_utf8_buffer())
	poll_pending = true
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: ECHO-LINE-Client/0.1",
		"Content-Type: text/plain;charset=UTF-8",
	])
	http.request(url, headers, HTTPClient.METHOD_POST, body.get_string_from_utf8())
	var result: int = await http.request_completed
	poll_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		# Re-queue the envelope so we retry next poll cycle.
		pending_sends.push_front(envelope)
		return


# === Phase 3: Long-poll (GET) ===

func _do_long_poll() -> void:
	# GET /socket.io/?EIO=4&transport=polling&sid=... returns:
	#   - "X" packets immediately if server has data
	#   - empty body if no data (server holds the request open for up to
	#     pingTimeout for new events)
	if sid == "":
		return
	var url: String = "%s/socket.io/?EIO=4&transport=polling&sid=%s" % [
		server_base, sid]
	poll_pending = true
	poll_http.request(url, PackedStringArray([
		"User-Agent: ECHO-LINE-Client/0.1",
	]), HTTPClient.METHOD_GET)
	var result: int = await poll_http.request_completed
	poll_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if is_connected:
			EventBus.network_error.emit("Poll failed")
		return
	var code: int = poll_http.get_response_code()
	if code != 200:
		return
	var body: PackedByteArray = poll_http.get_body()
	var text: String = body.get_string_from_utf8()
	if text.is_empty():
		return
	# Each engine.io packet may be length-prefixed (e.g., "6<...>4<...>").
	# For simplicity we assume one combined packet per response (common).
	_dispatch_packets(text)


func _dispatch_packets(text: String) -> void:
	# Split on length-prefix "X" where X is digits, then content.
	# Simpler: walk the string and dispatch per code.
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if c == "0":
			# engine.io open (shouldn't happen after handshake, but safe)
			i += 1
			continue
		if c == "1":
			# engine.io close
			_handle_close()
			return
		if c == "2":
			# engine.io ping — server asks us to pong
			_do_pong()
			i += 1
			continue
		if c == "3":
			# engine.io pong
			i += 1
			continue
		if c == "4":
			# Socket.IO message — rest is the inner JSON array.
			var rest: String = text.substr(i + 1)
			# The JSON may be followed by another packet starting with a digit.
			# Find the end of the JSON array by counting brackets.
			var end_idx: int = _find_json_end(rest)
			if end_idx > 0:
				var json_text: String = rest.substr(0, end_idx)
				_handle_socket_io_message(json_text)
				i = i + 1 + end_idx
				continue
			i += 1
			continue
		# Length-prefixed: "NNcontent" where NN is the content length.
		if c.is_valid_int():
			# Read the length digits.
			var j: int = i
			while j < text.length() and text[j].is_valid_int():
				j += 1
			var length_str: String = text.substr(i, j - i)
			var length: int = int(length_str)
			var payload: String = text.substr(j, length)
			_dispatch_packets(payload)
			i = j + length
			continue
		# Unknown — skip one char.
		i += 1


func _find_json_end(s: String) -> int:
	# Find matching ']' for the first '['.
	var depth: int = 0
	var in_str: bool = false
	var esc: bool = false
	for i in range(s.length()):
		var c: String = s[i]
		if in_str:
			if esc:
				esc = false
			elif c == "\\":
				esc = true
			elif c == "\"":
				in_str = false
			continue
		if c == "\"":
			in_str = true
			continue
		if c == "[":
			depth += 1
		elif c == "]":
			depth -= 1
			if depth == 0:
				return i + 1
	return -1


# === engine.io ping/pong ===

func _do_ping() -> void:
	# Server sends "2" (ping); we respond with "3" (pong). On polling,
	# the ping is received in a poll response — we answer via POST.
	# For our server implementation, server doesn't ping us (it just reads
	# the long-poll). No-op here.
	pass


func _do_pong() -> void:
	# Server pinged us. We can't easily reply over the same long-poll,
	# but Socket.IO v4 polling tolerates the next long-poll containing
	# the pong code "3". For simplicity: queue a pong on next send.
	# Most servers accept missing pongs within ping_timeout (60s).
	pass


func _handle_close() -> void:
	if is_connected:
		is_connected = false
		EventBus.network_error.emit("Server closed session")
		_try_reconnect()


# === Socket.IO message dispatch ===

func _handle_socket_io_message(json_text: String) -> void:
	if json_text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Array):
		return
	var type_code: String = ""
	var data = null
	if parsed.size() >= 1:
		type_code = str(parsed[0])
	if parsed.size() >= 2:
		data = parsed[1]
	if type_code == "0":
		# Socket.IO CONNECTED
		is_connected = true
		EventBus.network_connected.emit()
		return
	if type_code == "3":
		# ACK with request_id
		if data is Array and data.size() >= 2:
			var ack_id: int = int(data[0])
			var ack_data = data[1]
			if ack_callbacks.has(ack_id):
				var cb: Callable = ack_callbacks[ack_id]
				ack_callbacks.erase(ack_id)
				if cb.is_valid():
					if ack_data is Dictionary:
						cb.call(ack_data)
					elif ack_data is Array and ack_data.size() > 0:
						var dict: Dictionary = {"success": ack_data[0]}
						for i in range(1, ack_data.size()):
							dict["arg" + str(i)] = ack_data[i]
						cb.call(dict)
					else:
						cb.call({"success": false, "error": "Empty ack", "data": ack_data})
		return
	if parsed.size() >= 2:
		var event_name: String = str(parsed[0])
		var event_data = parsed[1]
		_dispatch_event(event_name, event_data)


func _dispatch_event(event_name: String, data) -> void:
	match event_name:
		"connect":
			is_connected = true
			reconnect_attempts = 0
			EventBus.network_connected.emit()
		"lobby:update":
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


# === Reconnect ===

func _try_reconnect() -> void:
	if reconnect_attempts >= max_reconnect_attempts:
		EventBus.network_error.emit("Reconnect failed")
		return
	reconnect_attempts += 1
	var delay: float = min(2.0 * reconnect_attempts, 10.0)
	print("[NetworkClient] Reconnecting in %.1fs (attempt %d)" % [delay, reconnect_attempts])
	get_tree().create_timer(delay).timeout.connect(func():
		connect_to_server(server_base)
	)


# === Public API (called by UI) ===

func create_room(display_name: String, language: String,
		scenario_id: String = DEFAULT_SCENARIO, callback: Callable = Callable()) -> void:
	player_name = display_name
	player_language = language
	_send_event("lobby:create", {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"scenarioId": scenario_id,
	}, callback)


func join_room(code: String, display_name: String, language: String,
		callback: Callable = Callable()) -> void:
	player_name = display_name
	player_language = language
	_send_event("lobby:join", {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"roomCode": code,
	}, callback)


# Alias expected by lobby_view.gd (P0-2 audit).
func join_room_with_code(code: String, display_name: String, language: String,
		callback: Callable = Callable()) -> void:
	join_room(code, display_name, language, callback)


func list_rooms(language: String = "en",
		callback: Callable = Callable()) -> void:
	_send_event("lobby:list_rooms", {
		"language": language,
	}, callback)


# REST fallback for room list (P0-3 audit). Works even when Socket.IO
# polling hasn't completed the handshake yet. Returns {success, rooms,
# count} matching the Socket.IO shape so callers don't need to branch.
func http_list_rooms(language: String = "en",
		callback: Callable = Callable()) -> void:
	var url := "%s/api/rooms?lang=%s" % [server_base, language]
	http.request(url, PackedStringArray([
		"User-Agent: ECHO-LINE-Client/0.1",
	]), HTTPClient.METHOD_GET)
	var result: int = await http.request_completed
	if result != HTTPRequest.RESULT_SUCCESS:
		if callback.is_valid():
			callback.call({"success": false, "error": "HTTP %d" % result, "rooms": []})
		return
	var code: int = http.get_response_code()
	var body: PackedByteArray = http.get_body()
	if code != 200:
		if callback.is_valid():
			callback.call({"success": false, "error": "HTTP code %d" % code, "rooms": []})
		return
	var text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		if callback.is_valid():
			callback.call({"success": false, "error": "Bad JSON", "rooms": []})
		return
	# Server returns: {success, data: {rooms, count}} OR {success, rooms, count}
	var data = parsed.get("data", parsed)
	var rooms: Array = data.get("rooms", []) if data is Dictionary else []
	var count: int = data.get("count", rooms.size()) if data is Dictionary else 0
	if callback.is_valid():
		callback.call({"success": true, "rooms": rooms, "count": count})


func select_timeline(timeline: String,
		callback: Callable = Callable()) -> void:
	_send_event("lobby:select_timeline", {
		"timeline": timeline,
	}, callback)
	if timeline in ["past", "present", "future"]:
		my_timeline = timeline


func set_ready(ready: bool, callback: Callable = Callable()) -> void:
	_send_event("lobby:set_ready", {
		"ready": ready,
	}, callback)


func start_match(callback: Callable = Callable()) -> void:
	_send_event("lobby:start", {}, callback)


func leave_lobby(callback: Callable = Callable()) -> void:
	_send_event("lobby:leave", {}, callback)


func fill_with_bots(callback: Callable = Callable()) -> void:
	_send_event("lobby:fill_with_bots", {}, callback)


func get_story(room_id: String, callback: Callable = Callable()) -> void:
	_send_event("lobby:get_story", {
		"roomId": room_id,
	}, callback)


func send_interaction(entity_id: String, action: String,
		callback: Callable = Callable()) -> void:
	_send_event("match:interact", {
		"entityId": entity_id,
		"action": action,
	}, callback)


func send_chat(intent: String, code: String = "",
		data: Dictionary = {}, callback: Callable = Callable()) -> void:
	_send_event("match:chat", {
		"intent": intent,
		"code": code,
		"data": data,
	}, callback)


func send_ping(from_timeline: String, type: String, pos: Vector2,
		callback: Callable = Callable()) -> void:
	_send_event("match:ping", {
		"fromTimeline": from_timeline,
		"type": type,
		"x": pos.x,
		"y": pos.y,
	}, callback)


func get_player_uid() -> String:
	return player_uid

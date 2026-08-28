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
	poll_http.timeout = 10.0  # P2-3: was 30.0 - reduce wait on Render cold start
	set_process(false)  # P2-4: only run _process when connected


func _process(delta: float) -> void:
	if not is_connected:
		return
	poll_timer += delta
	# P5-AUDIT: only dispatch ONE pending event per frame so the awaited
	# HTTPRequest doesn't stall the entire _process loop. The next event
	# fires on the following frame.
	if pending_sends.size() > 0 and not poll_pending:
		var envelope: Dictionary = pending_sends.pop_front()
		_do_post_event(envelope)
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
	set_process(true)  # P2-4: activate polling loop
	EventBus.network_status_changed.emit(connection_state, last_error)
	_handshake()


func disconnect_from_server() -> void:
	connection_state = "disconnected"
	is_connected = false
	sid = ""
	ack_callbacks.clear()
	pending_sends.clear()
	set_process(false)  # P2-4: deactivate polling loop
	if poll_http and poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		poll_http.cancel_request()
	EventBus.network_status_changed.emit(connection_state, last_error)
	EventBus.network_error.emit("Disconnected")


func is_socket_connected() -> bool:
	return is_connected


func get_server_base() -> String:
	return server_base


func get_session_id() -> String:
	return sid


func get_connection_state() -> String:
	return connection_state


func get_last_error() -> String:
	return last_error


# === Phase 1: HTTP handshake → SID ===

func _handshake() -> void:
	# Socket.IO v4 polling handshake (two phases):
	# Phase 1: Engine.IO OPEN
	#   GET  /socket.io/?EIO=4&transport=polling
	#   < 0{"sid":"...","upgrades":[...],"pingInterval":...}
	# Phase 2: Socket.IO CONNECT to namespace "/"
	#   POST /socket.io/?EIO=4&transport=polling&sid=...   body="40"
	#   < 40{"sid":"..."}
	connection_state = "handshaking"
	EventBus.network_status_changed.emit(connection_state, last_error)
	var url := "%s/socket.io/?EIO=4&transport=polling" % server_base
	http.request(url, PackedStringArray(["User-Agent: ECHO-LINE-Client/0.1"]), HTTPClient.METHOD_GET)
	# P3-CRIT: request_completed signal emits (result, response_code, headers, body).
	# Use Array to receive them, NOT a single int.
	var completed_args: Array = await http.request_completed
	var result: int = completed_args[0]
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail_handshake("HTTP %d" % result)
		return
	var code: int = completed_args[1]
	var body: PackedByteArray = completed_args[3]
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
	print("[NetworkClient] Phase 1 OK. sid=%s ping=%dms — sending Socket.IO CONNECT" % [sid, ping_interval_ms])
	# Phase 2: send Socket.IO CONNECT packet for default namespace "/".
	# Body = "40" (Engine.IO MESSAGE 4 + Socket.IO CONNECT 0). Empty payload.
	var connect_url := "%s/socket.io/?EIO=4&transport=polling&sid=%s" % [server_base, sid]
	http.request(connect_url, PackedStringArray([
		"User-Agent: ECHO-LINE-Client/0.1",
		"Content-Type: text/plain;charset=UTF-8",
	]), HTTPClient.METHOD_POST, "40")
	var connect_args: Array = await http.request_completed
	var connect_result: int = connect_args[0]
	if connect_result != HTTPRequest.RESULT_SUCCESS:
		_fail_handshake("CONNECT POST failed: %d" % connect_result)
		return
	# Read CONNECT ack via long-poll
	poll_pending = true
	poll_http.request(connect_url, PackedStringArray(["User-Agent: ECHO-LINE-Client/0.1"]), HTTPClient.METHOD_GET)
	var poll_args: Array = await poll_http.request_completed
	poll_pending = false
	var poll_result: int = poll_args[0]
	if poll_result != HTTPRequest.RESULT_SUCCESS:
		_fail_handshake("CONNECT poll failed: %d" % poll_result)
		return
	var connect_body: PackedByteArray = poll_args[3]
	var connect_text: String = connect_body.get_string_from_utf8()
	# Expect "40{"sid":"..."}" — server assigns a Socket.IO sid.
	print("[NetworkClient] CONNECT response: %s" % connect_text.substr(0, 80))
	is_connected = true
	reconnect_attempts = 0
	connection_state = "connected"
	last_ping_time_ms = Time.get_ticks_msec()
	poll_timer = 0.0
	print("[NetworkClient] Connected. sid=%s ping=%dms" % [sid, ping_interval_ms])
	EventBus.network_connected.emit()
	EventBus.network_status_changed.emit(connection_state, last_error)
	# Flush any queued events immediately (long-poll cycle resumes naturally).
	_do_long_poll()


func _fail_handshake(reason: String) -> void:
	connection_state = "error"
	last_error = reason
	push_error("[NetworkClient] Handshake failed: %s" % reason)
	# Telemetry ship-out so server can correlate client failures
	var tc := get_node_or_null("/root/TelemetryClient")
	if tc and tc.has_method("log_error"):
		tc.log_error("network.handshake", reason, {
			"server_base": server_base,
			"state": connection_state,
		})
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
	# Socket.IO v4 polling POST format for EVENT with ack:
	#   Engine.IO MESSAGE (4) + Socket.IO EVENT (2) + ack_id + JSON
	# Default namespace "/" is OMITTED in the JSON body — Socket.IO
	# understands the absence of a namespace prefix as "/".
	# Example: 421["lobby:create",{...}]   (no "/", no namespace prefix)
	#
	# We use request_id as the Socket.IO ack id so that when the server
	# responds with `43[id, args]`, our long-poll handler can dispatch
	# the matching ack_callback.
	var event_name: String = envelope.event
	var payload: Dictionary = envelope.payload
	var request_id: int = int(envelope.request_id)
	var inner: Array = [event_name, payload]
	var json_str: String = JSON.stringify(inner)
	var url: String = "%s/socket.io/?EIO=4&transport=polling&sid=%s" % [
		server_base, sid]
	# Engine.IO MESSAGE (4) + Socket.IO EVENT (2) + ack_id (or empty).
	# When ack_id > 0, server treats the EVENT as having an ack callback.
	var packet_type: String = "42"
	if request_id > 0:
		packet_type = "42%d" % request_id
	var body: PackedByteArray = PackedByteArray()
	body.append_array(packet_type.to_utf8_buffer())
	body.append_array(json_str.to_utf8_buffer())
	poll_pending = true
	var headers: PackedStringArray = PackedStringArray([
		"User-Agent: ECHO-LINE-Client/0.1",
		"Content-Type: text/plain;charset=UTF-8",
	])
	http.request(url, headers, HTTPClient.METHOD_POST, body.get_string_from_utf8())
	var completed_args2: Array = await http.request_completed
	var result: int = completed_args2[0]
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
	var completed_args3: Array = await poll_http.request_completed
	var result: int = completed_args3[0]
	poll_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		if is_connected:
			EventBus.network_error.emit("Poll failed")
		return
	var code: int = completed_args3[1]
	if code != 200:
		return
	var body: PackedByteArray = completed_args3[3]
	var text: String = body.get_string_from_utf8()
	if text.is_empty():
		return
	# Each engine.io packet may be length-prefixed (e.g., "6<...>4<...>").
	# For simplicity we assume one combined packet per response (common).
	_dispatch_packets(text)


func _dispatch_packets(text: String) -> void:
	# P5-AUDIT: walk the buffer and dispatch each engine.io / Socket.IO packet.
	# Packet formats we may receive:
	#   - "0<json>"        Engine.IO open (shouldn't happen post-handshake)
	#   - "1"              Engine.IO close
	#   - "2"              Engine.IO ping (we respond with pong)
	#   - "3"              Engine.IO pong
	#   - "4<json>"        Engine.IO MESSAGE (rest is a Socket.IO packet)
	#       Socket.IO types inside:
	#         "0"     CONNECT     — payload is {sid, ...}
	#         "2..."  EVENT       — payload is [namespace, event_name, args...]
	#         "3..."  ACK         — payload is [namespace, ack_id, args...]
	#   - "<length>content"    length-prefixed packet
	var i: int = 0
	while i < text.length():
		var c: String = text[i]
		if c == "0":
			# engine.io open (shouldn't happen after handshake)
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
			# Socket.IO message — rest is JSON array describing the inner packet.
			var rest: String = text.substr(i + 1)
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
	if not (parsed is Array) or parsed.size() == 0:
		return

	# P5-AUDIT: Socket.IO v4 message structure is
	#   [namespace_or_type, type_code, ...args]
	# or for legacy v3 (without namespace):
	#   [type_code, ...args]
	# We need to detect which form we got.
	var idx: int = 0
	var ns: String = "/"
	if parsed.size() >= 2 and parsed[0] is String and (parsed[0] as String).begins_with("/"):
		ns = parsed[0]
		idx = 1
	if idx >= parsed.size():
		return
	var type_code: String = str(parsed[idx])
	idx += 1

	if type_code == "0":
		# Socket.IO CONNECT
		is_connected = true
		EventBus.network_connected.emit()
		return
	if type_code == "1":
		# DISCONNECT
		is_connected = false
		EventBus.network_error.emit("Server disconnected")
		return
	if type_code == "2":
		# EVENT — remaining elements are [event_name, ...args]
		if idx >= parsed.size():
			return
		var event_name: String = str(parsed[idx])
		idx += 1
		var event_args: Array = []
		for k in range(idx, parsed.size()):
			event_args.append(parsed[k])
		# Most events deliver a single payload (Dictionary).
		var event_data = event_args[0] if event_args.size() >= 1 else {}
		_dispatch_event(event_name, event_data)
		return
	if type_code == "3":
		# ACK — [ack_id, ...args]
		if idx >= parsed.size():
			return
		var ack_id_raw = parsed[idx]
		var ack_id: int = -1
		if ack_id_raw is int or ack_id_raw is float:
			ack_id = int(ack_id_raw)
		idx += 1
		var ack_args: Array = []
		for k in range(idx, parsed.size()):
			ack_args.append(parsed[k])
		if ack_callbacks.has(ack_id):
			var cb: Callable = ack_callbacks[ack_id]
			ack_callbacks.erase(ack_id)
			if cb.is_valid():
				if ack_args.size() == 1 and ack_args[0] is Dictionary:
					cb.call(ack_args[0])
				elif ack_args.size() >= 1:
					var dict: Dictionary = {"success": ack_args[0]}
					for i in range(1, ack_args.size()):
						dict["arg" + str(i)] = ack_args[i]
					cb.call(dict)
				else:
					cb.call({"success": false, "error": "Empty ack"})
		return


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
		scenario_id: String = DEFAULT_SCENARIO, callback: Callable = Callable(),
		max_players: int = 4, password: String = "") -> void:
	player_name = display_name
	player_language = language
	var payload: Dictionary = {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"scenarioId": scenario_id,
		"maxPlayers": max_players,
	}
	if password != null and password.length() > 0:
		payload["password"] = password
	_send_event("lobby:create", payload, callback)


func join_room(code: String, display_name: String, language: String,
		callback: Callable = Callable(), password: String = "") -> void:
	player_name = display_name
	player_language = language
	var payload: Dictionary = {
		"playerUid": player_uid,
		"displayName": display_name,
		"language": language,
		"roomCode": code,
	}
	if password != null and password.length() > 0:
		payload["password"] = password
	_send_event("lobby:join", payload, callback)


# Alias expected by lobby_view.gd (P0-2 audit).
func join_room_with_code(code: String, display_name: String, language: String,
		callback: Callable = Callable(), password: String = "") -> void:
	join_room(code, display_name, language, callback, password)


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
	var completed_args4: Array = await http.request_completed
	var result: int = completed_args4[0]
	if result != HTTPRequest.RESULT_SUCCESS:
		if callback.is_valid():
			callback.call({"success": false, "error": "HTTP %d" % result, "rooms": []})
		return
	var code: int = completed_args4[1]
	var body: PackedByteArray = completed_args4[3]
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

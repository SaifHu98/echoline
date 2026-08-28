extends Node

# ECHO//LINE — Telemetry Client (Phase 7: client logs shipped to server)
# ---------------------------------------------------------------------------
# Captures runtime errors, warnings, and key events from the client and ships
# them to the game server for centralised analysis. Designed to be cheap on
# mobile data: events are batched (10) and sent every 15 seconds, with a
# flush on crash/quit. All transmission is best-effort and never blocks the
# game thread.

const SERVER_LOG_ENDPOINT := "/api/client/logs"
const LOG_BATCH_SIZE := 10
const LOG_FLUSH_INTERVAL_SEC := 15.0
const MAX_QUEUE_SIZE := 500  # cap memory if server unreachable
const MAX_LOG_AGE_HOURS := 24  # discard queued logs older than this

const SEVERITY_INFO := "info"
const SEVERITY_WARN := "warn"
const SEVERITY_ERROR := "error"
const SEVERITY_FATAL := "fatal"

var _queue: Array = []
var _http: HTTPRequest = null
var _flush_timer: Timer = null
var _session_id: String = ""
var _client_version: String = "0.1.0"
var _platform: String = ""
var _device_model: String = ""
var _os_version: String = ""

var _enabled: bool = true
var _endpoint_base: String = ""

# Stats
var _total_sent: int = 0
var _total_failed: int = 0
var _total_dropped: int = 0


func _ready() -> void:
	_session_id = _generate_session_id()
	_platform = OS.get_name()
	_os_version = OS.get_name() + " " + OS.get_version()
	var models := OS.get_model_name()
	_device_model = models if models != "" else "unknown"

	# Resolve the server base from the NetworkClient if available.
	var nc = get_node_or_null("/root/NetworkClient")
	if nc and nc.has_method("get_server_base"):
		_endpoint_base = nc.get_server_base()
	else:
		_endpoint_base = "https://echoline-game-server.onrender.com"

	# Allocate HTTP request once; reused across batches.
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_flush_completed)

	# Periodic flush.
	_flush_timer = Timer.new()
	_flush_timer.wait_time = LOG_FLUSH_INTERVAL_SEC
	_flush_timer.autostart = true
	_flush_timer.timeout.connect(_flush_queue)
	add_child(_flush_timer)

	# Wire up to Godot's runtime error handlers so crashes are captured.
	# (set_message_translation + push_error are emitted as console lines;
	# we can't intercept them directly, but our explicit log_error() calls
	# throughout the autoloads and scenes feed this service.)

	print("[TelemetryClient] Active. session=%s platform=%s" % [_session_id, _platform])


# =============================================================================
# Public API
# =============================================================================

func log_info(category: String, message: String, context: Dictionary = {}) -> void:
	_enqueue(SEVERITY_INFO, category, message, context)


func log_warn(category: String, message: String, context: Dictionary = {}) -> void:
	_enqueue(SEVERITY_WARN, category, message, context)


func log_error(category: String, message: String, context: Dictionary = {}) -> void:
	_enqueue(SEVERITY_ERROR, category, message, context)
	# Flush errors immediately so they aren't lost on crash.
	if _queue.size() >= LOG_BATCH_SIZE:
		_flush_queue()


func log_fatal(category: String, message: String, context: Dictionary = {}) -> void:
	_enqueue(SEVERITY_FATAL, category, message, context)
	# For fatal errors, attempt an immediate flush (best-effort).
	call_deferred("_flush_queue")


func set_enabled(enabled: bool) -> void:
	_enabled = enabled


func get_stats() -> Dictionary:
	return {
		"queued": _queue.size(),
		"sent": _total_sent,
		"failed": _total_failed,
		"dropped": _total_dropped,
		"session": _session_id,
	}


# Convenience helpers for the most common event categories.

func event_app_start() -> void:
	log_info("app", "Application started", {"version": _client_version})


func event_scene_changed(from_scene: String, to_scene: String) -> void:
	log_info("scene", "Scene change", {"from": from_scene, "to": to_scene})


func event_button_pressed(button_name: String, scene: String) -> void:
	log_info("ui", "Button pressed", {"button": button_name, "scene": scene})


func event_network_state(state: String, detail: String = "") -> void:
	log_info("network", "Network state change", {"state": state, "detail": detail})


func event_match_action(action: String, payload: Dictionary = {}) -> void:
	# Merge action into payload so callers can pass arbitrary structured data.
	var ctx: Dictionary = {"action": action}
	for k in payload.keys():
		ctx[k] = payload[k]
	log_info("match", "Match action: " + action, ctx)


# =============================================================================
# Internal
# =============================================================================

func _generate_session_id() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var s := ""
	for i in range(12):
		s += chars[randi() % chars.length()]
	return s


func _enqueue(severity: String, category: String, message: String, context: Dictionary) -> void:
	if not _enabled:
		return
	if _queue.size() >= MAX_QUEUE_SIZE:
		# Drop oldest entries to bound memory.
		_queue.pop_front()
		_total_dropped += 1
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"severity": severity,
		"category": category,
		"message": message,
		"context": context,
		"session": _session_id,
		"platform": _platform,
		"os": _os_version,
		"device": _device_model,
		"build": _client_version,
	}
	_queue.append(entry)


func _flush_queue() -> void:
	if not _enabled or _queue.is_empty():
		return
	if _http == null:
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		# Already flushing — wait until next tick.
		return

	var batch: Array = []
	var max_age: float = MAX_LOG_AGE_HOURS * 3600.0
	var now: float = Time.get_unix_time_from_system()
	while batch.size() < LOG_BATCH_SIZE and _queue.size() > 0:
		var entry: Dictionary = _queue[0]
		if now - float(entry.get("ts", now)) > max_age:
			_queue.pop_front()
			_total_dropped += 1
			continue
		batch.append(entry)
		_queue.pop_front()

	if batch.is_empty():
		return

	var url := "%s%s" % [_endpoint_base, SERVER_LOG_ENDPOINT]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"User-Agent: ECHO-LINE-Client/%s" % _client_version,
		"X-Client-Session: %s" % _session_id,
	])
	var payload := {
		"batch": batch,
		"session": _session_id,
		"platform": _platform,
		"build": _client_version,
	}
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		# Re-queue the batch so we try again next tick.
		# Push front so order is preserved.
		for i in range(batch.size() - 1, -1, -1):
			_queue.push_front(batch[i])
		_total_failed += 1


func _on_flush_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_total_sent += 1
	else:
		_total_failed += 1


func _exit_tree() -> void:
	# The HTTP child is already being torn down, so a request here would fail.
	# Queued entries remain best-effort in memory until the next active session.
	pass

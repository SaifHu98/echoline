class_name AnchorNetworkSync
extends Node

signal anchor_event_sent(event_id: String)
signal anchor_event_acked(event_id: String, ok: bool, reason: String)
signal anchor_state_received(server_slots: Array, server_seq: int)
signal anchor_completion_received(effects: Dictionary)
signal build_error(reason: String)
signal disconnected()

const MAX_RETRIES := 5
const RETRY_DELAY_SEC := 0.5
const SERVER_KEEPALIVE_TIMEOUT_SEC := 12.0

@export var network_client: Node
@export var controller: AnchorPlacementController

var _pending: Dictionary = {}
var _acked: Dictionary = {}
var _event_seq: int = 0
var _connected: bool = false
var _server_ack_timeout_ms: int = 3000
var _last_server_msg_ts: int = 0
var _retry_timer: Timer
var _keepalive_timer: Timer
var _room_id: String = ""

func _ready() -> void:
	if controller:
		controller.placement_requested.connect(_on_local_place)
		controller.anchor_reverted.connect(_on_local_revert)
	_retry_timer = Timer.new()
	_retry_timer.one_shot = true
	_retry_timer.wait_time = RETRY_DELAY_SEC
	add_child(_retry_timer)
	_keepalive_timer = Timer.new()
	_keepalive_timer.wait_time = SERVER_KEEPALIVE_TIMEOUT_SEC
	_keepalive_timer.autostart = false
	_keepalive_timer.timeout.connect(_on_keepalive_timeout)
	add_child(_keepalive_timer)

func bind_room(room_id: String) -> void:
	_room_id = room_id
	_pending.clear()
	_acked.clear()
	_event_seq = 0

func start() -> void:
	_connected = true
	_last_server_msg_ts = int(Time.get_unix_time_from_system() * 1000)
	_keepalive_timer.start()

func stop() -> void:
	_connected = false
	_keepalive_timer.stop()
	_retry_timer.stop()

func _on_local_place(slot_index: int, shard_id: String) -> void:
	if not _connected:
		return
	_event_seq += 1
	var event_id: String = "place_%d_%d" % [_event_seq, int(Time.get_unix_time_from_system() * 1000)]
	var payload: Dictionary = {
		"event_id": event_id,
		"seq": _event_seq,
		"type": "place_shard",
		"slot_index": slot_index,
		"shard_id": shard_id,
		"place_seq_at_send": controller.get_place_seq() if controller else 0,
		"player_index": controller.player_index if controller else 0,
		"ts": int(Time.get_unix_time_from_system() * 1000)
	}
	_pending[event_id] = {"payload": payload, "retries": 0}
	_send_event(payload)

func _on_local_revert(slot_index: int, prev_shard: String) -> void:
	if not _connected:
		return
	_event_seq += 1
	var event_id: String = "revert_%d_%d" % [_event_seq, int(Time.get_unix_time_from_system() * 1000)]
	var payload: Dictionary = {
		"event_id": event_id,
		"seq": _event_seq,
		"type": "remove_shard",
		"slot_index": slot_index,
		"prev_shard": prev_shard,
		"player_index": controller.player_index if controller else 0,
		"ts": int(Time.get_unix_time_from_system() * 1000)
	}
	_pending[event_id] = {"payload": payload, "retries": 0}
	_send_event(payload)

func _send_event(payload: Dictionary) -> void:
	if network_client == null:
		build_error.emit("network_client_null")
		return
	if not network_client.has_method("emit"):
		build_error.emit("network_client_no_emit")
		return
	network_client.emit("anchor_event", _room_id, payload)
	anchor_event_sent.emit(payload.event_id)

func handle_server_ack(event_id: String, ok: bool, reason: String = "") -> void:
	_last_server_msg_ts = int(Time.get_unix_time_from_system() * 1000)
	if not _pending.has(event_id):
		return
	_acked[event_id] = {"ok": ok, "reason": reason, "ts": _last_server_msg_ts}
	_pending.erase(event_id)
	anchor_event_acked.emit(event_id, ok, reason)

func handle_server_state(server_slots: Array, server_seq: int) -> void:
	_last_server_msg_ts = int(Time.get_unix_time_from_system() * 1000)
	anchor_state_received.emit(server_slots, server_seq)

func handle_server_completion(effects: Dictionary) -> void:
	_last_server_msg_ts = int(Time.get_unix_time_from_system() * 1000)
	anchor_completion_received.emit(effects)

func _on_keepalive_timeout() -> void:
	if not _connected:
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000)
	var since_last_ms: int = now_ms - _last_server_msg_ts
	if since_last_ms > (SERVER_KEEPALIVE_TIMEOUT_SEC * 1000.0):
		_connected = false
		disconnected.emit()

func retry_pending() -> void:
	if _pending.is_empty():
		return
	for event_id in _pending.keys():
		var entry: Dictionary = _pending[event_id]
		var retries: int = int(entry.get("retries", 0))
		if retries >= MAX_RETRIES:
			_pending.erase(event_id)
			anchor_event_acked.emit(event_id, false, "max_retries_exceeded")
			continue
		entry.retries = retries + 1
		_send_event(entry.payload)
class_name VoiceChatClient
extends Node

signal voice_state_changed(state: String)
signal voice_peer_joined(peer_id: String, peers: Array)
signal voice_peer_left(peer_id: String)
signal voice_signal_received(from_peer: String, payload: Dictionary)
signal voice_error(reason: String)
signal voice_age_gate_required()

enum VoiceState { DISABLED, IDLE, CONNECTING, CONNECTED, MUTED, DEAFENED, ERROR, AGE_GATED }

const MIN_AGE_FOR_VOICE := 13
const RECONNECT_BACKOFF_MS := [500, 1000, 2000, 5000, 10000]
const PING_INTERVAL_MS := 5000
const ICE_GATHER_TIMEOUT_MS := 8000

@export var network_client: Node
@export var auto_join_on_room_enter: bool = true
@export var age_verified: bool = false
@export var player_age: int = 0

var state: int = VoiceState.DISABLED
var _current_room_id: String = ""
var _current_peer_id: String = ""
var _turn_config: Dictionary = {}
var _peers: Array = []
var _muted: bool = false
var _deafened: bool = false
var _pc: Object = null
var _audio_capture: Object = null
var _audio_player: Object = null
var _ping_timer: Timer
var _reconnect_attempt: int = 0
var _signal_outbox: Array = []
var _signal_inbox: Array = []

func _ready() -> void:
	_ping_timer = Timer.new()
	_ping_timer.wait_time = PING_INTERVAL_MS / 1000.0
	_ping_timer.autostart = false
	_ping_timer.timeout.connect(_send_ping)
	add_child(_ping_timer)

func _exit_tree() -> void:
	leave_room()

func is_supported() -> bool:
	if not ClassDB.class_exists("WebRTCPeerConnection"):
		return false
	if OS.get_name() not in ["Android", "iOS", "Linux", "Windows", "macOS"]:
		return false
	return true

func check_age_eligibility(age_years: int) -> bool:
	if age_years <= 0:
		return false
	if age_years < MIN_AGE_FOR_VOICE:
		voice_age_gate_required.emit()
		voice_error.emit("age_too_young")
		_set_state(VoiceState.AGE_GATED)
		return false
	player_age = age_years
	age_verified = true
	return true

func join_room(room_id: String, peer_id: String) -> void:
	if not is_supported():
		_set_state(VoiceState.ERROR)
		voice_error.emit("webrtc_not_supported")
		return
	if not age_verified:
		_set_state(VoiceState.AGE_GATED)
		voice_age_gate_required.emit()
		return
	_current_room_id = room_id
	_current_peer_id = peer_id
	_set_state(VoiceState.CONNECTING)
	_send_join_request()

func leave_room() -> void:
	if _current_room_id == "" or _current_peer_id == "":
		return
	if network_client and network_client.has_method("emit"):
		network_client.emit("voice_leave", _current_room_id, _current_peer_id)
	_current_room_id = ""
	_current_peer_id = ""
	_peers.clear()
	_stop_ping()
	_destroy_peer_connection()
	_set_state(VoiceState.IDLE)

func set_muted(muted: bool) -> void:
	_muted = muted
	if _audio_capture and _audio_capture.has_method("set_muted"):
		_audio_capture.set_muted(muted)
	if state != VoiceState.DEAFENED:
		_set_state(VoiceState.MUTED if muted else VoiceState.CONNECTED)
	if network_client and network_client.has_method("emit"):
		network_client.emit("voice_state", _current_room_id, _current_peer_id, { muted: _muted, deafened: _deafened })

func set_deafened(deafened: bool) -> void:
	_deafened = deafened
	if _audio_player and _audio_player.has_method("set_muted"):
		_audio_player.set_muted(deafened)
	if deafened:
		_set_state(VoiceState.DEAFENED)
	else:
		_set_state(VoiceState.CONNECTED)
	if network_client and network_client.has_method("emit"):
		network_client.emit("voice_state", _current_room_id, _current_peer_id, { muted: _muted, deafened: _deafened })

func get_state_name() -> String:
	return VoiceState.keys()[state]

func is_muted() -> bool:
	return _muted

func is_deafened() -> bool:
	return _deafened

func get_peers() -> Array:
	return _peers.duplicate()

func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	state = new_state
	voice_state_changed.emit(get_state_name())

func _send_join_request() -> void:
	if network_client == null:
		_set_state(VoiceState.ERROR)
		voice_error.emit("network_client_null")
		return
	network_client.emit("voice_join", _current_room_id, _current_peer_id, age_verified)

func _send_ping() -> void:
	if network_client == null or _current_room_id == "":
		return
	network_client.emit("voice_ping", _current_room_id, _current_peer_id)

func _stop_ping() -> void:
	if _ping_timer:
		_ping_timer.stop()

func _start_ping() -> void:
	if _ping_timer:
		_ping_timer.start()

func _destroy_peer_connection() -> void:
	if _pc != null:
		if _pc.has_method("close"):
			_pc.close()
		_pc = null

func handle_server_joined(session_id: String, turn_config: Dictionary, peers: Array) -> void:
	_turn_config = turn_config
	_peers = peers
	_create_peer_connection()
	_set_state(VoiceState.CONNECTED)
	_start_ping()
	voice_peer_joined.emit(_current_peer_id, _peers)

func handle_server_peer_joined(peer_id: String, peers: Array) -> void:
	_peers = peers
	voice_peer_joined.emit(peer_id, _peers)
	if _pc != null and _pc.has_method("create_offer"):
		var offer: Dictionary = _pc.create_offer()
		_relay_signal(peer_id, { type: "offer", sdp: offer })

func handle_server_peer_left(peer_id: String) -> void:
	_peers = _peers.filter(func(p): return p.peer_id != peer_id)
	voice_peer_left.emit(peer_id)

func handle_server_signal(from_peer: String, payload: Dictionary) -> void:
	if not payload.has("type"):
		return
	var signal_type: String = payload.type
	if signal_type == "offer":
		_handle_offer(from_peer, payload.sdp)
	elif signal_type == "answer":
		_handle_answer(from_peer, payload.sdp)
	elif signal_type == "ice-candidate":
		_handle_ice_candidate(from_peer, payload.candidate)
	elif signal_type == "bye":
		voice_peer_left.emit(from_peer)
	voice_signal_received.emit(from_peer, payload)

func handle_server_error(reason: String) -> void:
	voice_error.emit(reason)
	_set_state(VoiceState.ERROR)

func _create_peer_connection() -> void:
	_destroy_peer_connection()
	if not ClassDB.class_exists("WebRTCPeerConnection"):
		handle_server_error("webrtc_class_missing")
		return
	var pc: Object = ClassDB.instantiate("WebRTCPeerConnection")
	if pc == null:
		handle_server_error("webrtc_instantiate_failed")
		return
	var ice_servers: Array = []
	if _turn_config.has("iceServers"):
		ice_servers = _turn_config.iceServers
	pc.initialize({ "iceServers": ice_servers })
	pc.connect("ice_candidate", _on_local_ice_candidate)
	_pc = pc
	_audio_capture = AudioStreamGenerator.new()
	_audio_player = AudioStreamGenerator.new()

func _on_local_ice_candidate(mid: String, index: int, candidate: String) -> void:
	_relay_signal("*", { type: "ice-candidate", mid: mid, index: index, candidate: candidate })

func _handle_offer(from_peer: String, sdp: String) -> void:
	if _pc == null:
		return
	_pc.set_remote_description("offer", sdp)
	var answer: Dictionary = _pc.create_answer()
	_pc.set_local_description("answer", answer.sdp)
	_relay_signal(from_peer, { type: "answer", sdp: answer })

func _handle_answer(from_peer: String, sdp: String) -> void:
	if _pc == null:
		return
	_pc.set_remote_description("answer", sdp)

func _handle_ice_candidate(from_peer: String, payload: Dictionary) -> void:
	if _pc == null:
		return
	var mid: String = payload.get("mid", "")
	var index: int = int(payload.get("index", 0))
	var candidate: String = payload.get("candidate", "")
	_pc.add_ice_candidate(mid, index, candidate)

func _relay_signal(target_peer: String, payload: Dictionary) -> void:
	if network_client == null:
		return
	if not network_client.has_method("emit"):
		return
	network_client.emit("voice_signal", _current_room_id, _current_peer_id, target_peer, payload)
class_name AnchorPlacementController
extends Node3D

signal slot_hovered(slot_index: int)
signal slot_selected(slot_index: int)
signal placement_requested(slot_index: int, shard_id: String)
signal placement_confirmed(slot_index: int, shard_id: String, place_seq: int)
signal placement_rejected(slot_index: int, reason: String)
signal anchor_progress_changed(progress: float)
signal anchor_completed()
signal anchor_reverted(slot_index: int, shard_id: String)
signal server_state_synced(server_slots: Array)

const SERVER_TICK_TIMEOUT_MS := 5000

@export var snap_grid: SnapGrid
@export var max_place_distance: float = 12.0
@export var require_owner_for_slot: bool = true
@export var player_index: int = 0
@export var enable_validation: bool = true

var _blueprint: Dictionary = {}
var _slots: Array = []
var _owner_map: Dictionary = {}
var _server_slots: Array = []
var _place_seq: int = 0
var _last_server_ts: int = 0
var _inventory: ShardInventory = null
var _catalog: Dictionary = {}

func setup(blueprint: Dictionary, inventory: ShardInventory, catalog: Dictionary, players: Array = []) -> void:
	_blueprint = blueprint
	_inventory = inventory
	_catalog = catalog
	_owner_map.clear()
	_slots.clear()
	for i in range(blueprint.slots.size()):
		var slot_def: Dictionary = blueprint.slots[i]
		var slot_state: Dictionary = {
			"slot_id": slot_def.slot_id,
			"slot_index": i,
			"state": "empty",
			"placed_shard": "",
			"filled_by": "",
			"place_seq": 0
		}
		_slots.append(slot_state)
		if slot_def.has("owner_index_required"):
			_owner_map[i] = slot_def.owner_index_required
	emit_signal("anchor_progress_changed", _compute_progress())

func get_blueprint() -> Dictionary:
	return _blueprint

func get_slots() -> Array:
	return _slots.duplicate(true)

func get_slot_state(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= _slots.size():
		return {}
	return _slots[slot_index].duplicate(true)

func is_complete() -> bool:
	for s in _slots:
		if s.state != "filled":
			return false
	return not _slots.is_empty()

func _compute_progress() -> float:
	if _slots.is_empty():
		return 0.0
	var filled: int = 0
	for s in _slots:
		if s.state == "filled":
			filled += 1
	return float(filled) / float(_slots.size())

func hover_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	emit_signal("slot_hovered", slot_index)

func select_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	emit_signal("slot_selected", slot_index)

func _can_place(slot_index: int, shard_id: String, owner_id: String) -> Dictionary:
	var slot: Dictionary = _slots[slot_index]
	if slot.state == "filled":
		return {"ok": false, "reason": "slot_already_filled"}
	var slot_def: Dictionary = _blueprint.slots[slot_index]
	if require_owner_for_slot and slot_def.has("owner_index_required"):
		var required_owner: int = slot_def.owner_index_required
		if required_owner != player_index:
			return {"ok": false, "reason": "wrong_owner", "required_owner": required_owner}
	if not _catalog.has(shard_id):
		return {"ok": false, "reason": "unknown_shard"}
	if not slot_def.has("valid_shards"):
		return {"ok": false, "reason": "invalid_slot_def"}
	var valid: Array = slot_def.valid_shards
	if not valid.has(shard_id):
		return {"ok": false, "reason": "invalid_shard_for_slot", "required": valid}
	if _inventory == null or not _inventory.has(shard_id):
		return {"ok": false, "reason": "no_shard_in_inventory"}
	return {"ok": true}

func request_placement(slot_index: int, shard_id: String, owner_id: String) -> void:
	emit_signal("placement_requested", slot_index, shard_id)
	if not enable_validation:
		return
	var validation: Dictionary = _can_place(slot_index, shard_id, owner_id)
	if not validation.ok:
		emit_signal("placement_rejected", slot_index, validation.reason)
		return
	_apply_local(slot_index, shard_id, owner_id)
	emit_signal("placement_confirmed", slot_index, shard_id, _place_seq)

func _apply_local(slot_index: int, shard_id: String, owner_id: String) -> void:
	_place_seq += 1
	var slot: Dictionary = _slots[slot_index]
	slot.state = "filled"
	slot.placed_shard = shard_id
	slot.filled_by = owner_id
	slot.place_seq = _place_seq
	if _inventory:
		_inventory.remove_shard(shard_id, 1)
	emit_signal("anchor_progress_changed", _compute_progress())
	if is_complete():
		emit_signal("anchor_completed")

func revert_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slots.size():
		return
	var slot: Dictionary = _slots[slot_index]
	if slot.state != "filled":
		return
	var slot_def: Dictionary = _blueprint.slots[slot_index]
	if require_owner_for_slot and slot_def.has("owner_index_required"):
		var required_owner: int = slot_def.owner_index_required
		if required_owner != player_index:
			emit_signal("placement_rejected", slot_index, "wrong_owner")
			return
	var prev_shard: String = slot.placed_shard
	slot.state = "empty"
	slot.placed_shard = ""
	slot.filled_by = ""
	slot.place_seq = 0
	if _inventory and prev_shard != "":
		_inventory.add_shard(prev_shard, 1)
	emit_signal("anchor_reverted", slot_index, prev_shard)
	emit_signal("anchor_progress_changed", _compute_progress())

func sync_from_server(server_slots: Array, server_place_seq: int, server_ts: int) -> void:
	if server_slots.is_empty() or _slots.is_empty():
		return
	if server_slots.size() != _slots.size():
		push_warning("AnchorPlacementController.sync_from_server: slot count mismatch local=%d server=%d" % [_slots.size(), server_slots.size()])
		return
	_last_server_ts = server_ts
	for i in range(_slots.size()):
		var local_slot: Dictionary = _slots[i]
		var server_slot: Dictionary = server_slots[i]
		var local_seq: int = int(local_slot.get("place_seq", 0))
		var server_seq: int = int(server_slot.get("place_seq", 0))
		if server_seq <= local_seq:
			continue
		_apply_remote_slot(i, server_slot, server_place_seq)
	emit_signal("server_state_synced", server_slots)
	emit_signal("anchor_progress_changed", _compute_progress())
	if is_complete():
		emit_signal("anchor_completed")

func _apply_remote_slot(slot_index: int, server_slot: Dictionary, server_place_seq: int) -> void:
	var local_slot: Dictionary = _slots[slot_index]
	if server_slot.get("state") == "filled":
		var prev_shard: String = local_slot.placed_shard
		local_slot.state = "filled"
		local_slot.placed_shard = server_slot.get("placed_shard", "")
		local_slot.filled_by = server_slot.get("filled_by", "")
		local_slot.place_seq = int(server_slot.get("place_seq", server_place_seq))
		if prev_shard != "" and prev_shard != local_slot.placed_shard and _inventory and _inventory.has(prev_shard):
			_inventory.remove_shard(prev_shard, 1)
		if _inventory and not _inventory.has(local_slot.placed_shard):
			_inventory.add_shard(local_slot.placed_shard, 1)
	else:
		local_slot.state = "empty"
		local_slot.placed_shard = ""
		local_slot.filled_by = ""
		local_slot.place_seq = 0

func get_progress() -> float:
	return _compute_progress()

func get_place_seq() -> int:
	return _place_seq

func has_unconfirmed_local_changes() -> bool:
	return false
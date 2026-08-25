class_name ShardInventory
extends RefCounted

signal shard_added(shard_id: String, new_count: int)
signal shard_removed(shard_id: String, remaining_count: int)
signal duplicates_converted(events: Array)

const DUPLICATE_CONVERSION := 3

var _counts: Dictionary = {}
var _catalog: Dictionary = {}

func setup(catalog: Dictionary) -> void:
	_catalog = catalog
	_counts.clear()

func reset() -> void:
	_counts.clear()

func load_from(inventory_data: Dictionary) -> void:
	_counts.clear()
	for shard_id in inventory_data:
		_counts[shard_id] = int(inventory_data[shard_id])

func snapshot() -> Dictionary:
	return _counts.duplicate(true)

func get_count(shard_id: String) -> int:
	return int(_counts.get(shard_id, 0))

func has(shard_id: String) -> bool:
	return get_count(shard_id) > 0

func add_shard(shard_id: String, amount: int = 1) -> int:
	if not _catalog.has(shard_id):
		push_warning("ShardInventory.add_shard: unknown shard_id=%s" % shard_id)
		return _counts.get(shard_id, 0)
	var new_count: int = get_count(shard_id) + amount
	_counts[shard_id] = new_count
	shard_added.emit(shard_id, new_count)
	return new_count

func remove_shard(shard_id: String, amount: int = 1) -> int:
	if not has(shard_id) or get_count(shard_id) < amount:
		push_warning("ShardInventory.remove_shard: insufficient %s" % shard_id)
		return _counts.get(shard_id, 0)
	var new_count: int = get_count(shard_id) - amount
	if new_count <= 0:
		_counts.erase(shard_id)
	else:
		_counts[shard_id] = new_count
	shard_removed.emit(shard_id, _counts.get(shard_id, 0))
	return _counts.get(shard_id, 0)

func convert_duplicates() -> Array:
	var events: Array = []
	for shard_id in _counts.keys():
		var owned: int = _counts[shard_id]
		var conversions: int = owned / DUPLICATE_CONVERSION
		if conversions <= 0:
			continue
		var remaining: int = owned - (conversions * DUPLICATE_CONVERSION)
		if remaining <= 0:
			_counts.erase(shard_id)
		else:
			_counts[shard_id] = remaining
		events.append({
			"shard_id": shard_id,
			"converted_count": conversions,
			"new_count": remaining
		})
	if not events.is_empty():
		duplicates_converted.emit(events)
	return events

func get_all() -> Array:
	var list: Array = []
	for shard_id in _counts:
		list.append({
			"shard_id": shard_id,
			"count": _counts[shard_id]
		})
	list.sort_custom(func(a, b): return a.shard_id < b.shard_id)
	return list

func total_count() -> int:
	var total: int = 0
	for count in _counts.values():
		total += int(count)
	return total

func validate_for_slot(slot: Dictionary) -> Dictionary:
	if not slot.has("valid_shards"):
		return {"ok": false, "reason": "invalid_slot"}
	var candidates: Array = []
	for shard_id in slot.valid_shards:
		if has(shard_id):
			var def: Dictionary = _catalog.get(shard_id, {})
			candidates.append({
				"id": shard_id,
				"tier": def.get("tier", "common"),
				"timeline": def.get("timeline", "neutral"),
				"count": get_count(shard_id),
				"preferred_match": def.get("timeline") == slot.get("preferred_timeline")
			})
	if candidates.is_empty():
		return {"ok": false, "reason": "no_shards_available", "required": slot.valid_shards}
	return {"ok": true, "candidates": candidates}

func serialize() -> Dictionary:
	return _counts.duplicate(true)

func deserialize(data: Dictionary) -> void:
	load_from(data)
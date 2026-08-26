class_name ShardInventoryBar
extends Panel

signal shard_selected(shard_id: String)

const ShardSlotButtonScript := preload("res://ui/hud/shard_slot_button.gd")

@export var catalog: Dictionary = {}
@export var max_visible_shards: int = 8
@export var language: String = "en"

var _slots: Array = []
var _active_shard: String = ""
var _h_box: HBoxContainer

func _ready() -> void:
	custom_minimum_size = Vector2(0, 110)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.85)
	style.border_color = Color(0.25, 0.25, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", style)
	_h_box = HBoxContainer.new()
	_h_box.name = "slots"
	_h_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_h_box.offset_left = 8
	_h_box.offset_right = -8
	_h_box.offset_top = 8
	_h_box.offset_bottom = -8
	_h_box.add_theme_constant_override("separation", 8)
	add_child(_h_box)

func setup(catalog_data: Dictionary, locale: String = "en") -> void:
	catalog = catalog_data
	language = locale
	_refresh()

func update_inventory(inventory: Dictionary) -> void:
	for slot in _slots:
		var id: String = slot.shard_id
		var count: int = int(inventory.get(id, 0))
		slot.set_count(count)
	_apply_active_visual()

func set_active_shard(shard_id: String) -> void:
	_active_shard = shard_id
	_apply_active_visual()

func get_active_shard() -> String:
	return _active_shard

func _refresh() -> void:
	for child in _h_box.get_children():
		child.queue_free()
	_slots.clear()
	var order: Array = _prioritized_shard_ids()
	for id in order:
		var def: Dictionary = catalog.get("shards", {}).get(id, {})
		if def.is_empty():
			continue
		var btn: ShardSlotButtonScript = ShardSlotButtonScript.new()
		btn.name = "slot_%s" % id
		_h_box.add_child(btn)
		var display_name: String = def.get("display_name", {}).get(language, def.get("display_name", {}).get("en", id))
		var tier: String = def.get("tier", "common")
		var timeline: String = def.get("timeline", "neutral")
		btn.setup(id, 0, display_name, tier, timeline)
		btn.shard_slot_pressed.connect(_on_slot_pressed)
		_slots.append(btn)
		if _slots.size() >= max_visible_shards:
			break

func _prioritized_shard_ids() -> Array:
	if not catalog.has("shards"):
		return []
	var ids: Array = catalog.shards.keys()
	var tier_order: Dictionary = {"legendary": 0, "epic": 1, "rare": 2, "common": 3}
	ids.sort_custom(func(a, b):
		var da: Dictionary = catalog.shards.get(a, {})
		var db: Dictionary = catalog.shards.get(b, {})
		var ta: int = tier_order.get(da.get("tier", "common"), 9)
		var tb: int = tier_order.get(db.get("tier", "common"), 9)
		if ta != tb:
			return ta < tb
		return a < b
	)
	return ids

func _on_slot_pressed(shard_id: String, count: int) -> void:
	if count <= 0:
		return
	_active_shard = shard_id
	_apply_active_visual()
	shard_selected.emit(shard_id)

func _apply_active_visual() -> void:
	for slot in _slots:
		if slot.shard_id == _active_shard and slot.count > 0:
			slot.modulate = Color(1.4, 1.4, 1.4, 1.0)
		elif slot.count > 0:
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			slot.modulate = Color(1.0, 1.0, 1.0, 0.4)
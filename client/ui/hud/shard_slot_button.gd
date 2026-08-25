class_name ShardSlotButton
extends Button

signal shard_slot_pressed(shard_id: String, count: int)

@export var shard_id: String = ""
@export var count: int = 0
@export var tier_color: Color = Color.WHITE
@export var timeline: String = "neutral"

var _count_label: Label
var _name_label: Label
var _tier_ring: ColorRect

func _ready() -> void:
	_build_layout()
	_apply_visual()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pressed.connect(_on_pressed)
	if not is_node_ready():
		await ready

func setup(id: String, count_value: int, display_name: String, tier: String = "common", timeline_name: String = "neutral") -> void:
	shard_id = id
	count = count_value
	timeline = timeline_name
	tier_color = _color_for_tier(tier)
	if _count_label and _name_label:
		_count_label.text = "x%d" % count
		_name_label.text = display_name
	_apply_visual()

func _build_layout() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var bg: ColorRect = ColorRect.new()
	bg.name = "bg"
	bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_tier_ring = ColorRect.new()
	_tier_ring.name = "tier_ring"
	_tier_ring.color = tier_color
	_tier_ring.position = Vector2(4, 4)
	_tier_ring.size = Vector2(8, 88)
	add_child(_tier_ring)
	_name_label = Label.new()
	_name_label.name = "name_label"
	_name_label.position = Vector2(20, 12)
	_name_label.size = Vector2(72, 40)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_name_label)
	_count_label = Label.new()
	_count_label.name = "count_label"
	_count_label.position = Vector2(20, 64)
	_count_label.size = Vector2(72, 24)
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", tier_color)
	add_child(_count_label)

func _apply_visual() -> void:
	if _tier_ring:
		_tier_ring.color = tier_color
	if _count_label:
		_count_label.text = "x%d" % count

func _color_for_tier(tier: String) -> Color:
	match tier:
		"common": return Color(0.78, 0.78, 0.78)
		"rare": return Color(0.45, 0.78, 1.0)
		"epic": return Color(0.78, 0.5, 1.0)
		"legendary": return Color(1.0, 0.78, 0.3)
		_: return Color.WHITE

func set_count(new_count: int) -> void:
	count = new_count
	if _count_label:
		_count_label.text = "x%d" % count
	modulate.a = 1.0 if count > 0 else 0.4

func _on_pressed() -> void:
	if count <= 0:
		return
	shard_slot_pressed.emit(shard_id, count)
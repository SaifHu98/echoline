class_name AnchorBlueprintPanel
extends Panel

signal start_blueprint(blueprint_id: String)
signal cancel_blueprint(blueprint_id: String)

var _blueprints: Dictionary = {}
var _list: VBoxContainer
var _active_blueprint: String = ""

func _ready() -> void:
	custom_minimum_size = Vector2(280, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.border_color = Color(0.4, 0.55, 0.85, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	add_theme_stylebox_override("panel", style)
	_list = VBoxContainer.new()
	_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_list.offset_left = 12
	_list.offset_right = -12
	_list.offset_top = 12
	_list.offset_bottom = -12
	_list.add_theme_constant_override("separation", 8)
	add_child(_list)

func set_blueprints(blueprints: Dictionary, language: String = "en") -> void:
	_blueprints = blueprints
	_refresh(language)

func _refresh(language: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	if not _blueprints.has("anchors"):
		return
	var ids: Array = _blueprints.anchors.keys()
	for id in ids:
		var def: Dictionary = _blueprints.anchors[id]
		_list.add_child(_build_blueprint_card(id, def, language))

func _build_blueprint_card(id: String, def: Dictionary, language: String) -> Control:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 1.0)
	style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", style)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var name_label: Label = Label.new()
	var names: Dictionary = def.get("display_name", {"en": id})
	name_label.text = names.get(language, names.get("en", id))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	v.add_child(name_label)
	var meta: Label = Label.new()
	var max_p: int = int(def.get("max_players", 1))
	var min_p: int = int(def.get("min_players_building", 1))
	var diff: int = int(def.get("difficulty", 1))
	var time_s: int = int(def.get("completion_time_seconds", 60))
	meta.text = "max %d • min %d • diff %d/5 • %ds" % [max_p, min_p, diff, time_s]
	meta.add_theme_font_size_override("font_size", 11)
	meta.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	v.add_child(meta)
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	v.add_child(h)
	var btn_start: Button = Button.new()
	btn_start.text = "Start" if language == "en" else "ابدأ"
	btn_start.pressed.connect(func(): start_blueprint.emit(id))
	h.add_child(btn_start)
	var btn_cancel: Button = Button.new()
	btn_cancel.text = "Cancel" if language == "en" else "إلغاء"
	btn_cancel.pressed.connect(func(): cancel_blueprint.emit(id))
	h.add_child(btn_cancel)
	return card
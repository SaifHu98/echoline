class_name RTLButton
extends Button

@export var loc_key: String = ""
@export var loc_params: Dictionary = {}

func _ready() -> void:
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.text_scale_changed.connect(_on_text_scale_changed)
	update_layout()

func set_loc_key(key: String, params: Dictionary = {}) -> void:
	loc_key = key
	loc_params = params
	update_layout()

func _on_locale_changed(_locale: String, _is_rtl: boolean) -> void:
	update_layout()

func _on_text_scale_changed(scale_factor: float) -> void:
	add_theme_font_size_override("font_size", int(16 * scale_factor))

func update_layout() -> void:
	if loc_key != "":
		text = Localization.tr_key(loc_key, loc_params)
	
	if Localization.is_rtl:
		alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		alignment = HORIZONTAL_ALIGNMENT_LEFT

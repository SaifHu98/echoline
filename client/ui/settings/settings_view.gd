class_name SettingsView
extends Control

# Settings & Accessibility Configuration

@onready var lang_option: OptionButton = $Panel/VBox/LangRow/OptionButton
@onready var contrast_check: CheckBox = $Panel/VBox/ContrastCheck
@onready var motion_check: CheckBox = $Panel/VBox/MotionCheck
@onready var scale_slider: HSlider = $Panel/VBox/ScaleRow/Slider
@onready var close_btn: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	# Start visible to prevent flicker
	modulate.a = 1.0

	if lang_option:
		lang_option.clear()
		lang_option.add_item("English", 0)
		lang_option.add_item("العربية (Arabic)", 1)
		lang_option.add_item("⟦Pseudo-Expanded⟧", 2)
		lang_option.add_item("⁅Pseudo-Mirrored⁆", 3)
		lang_option.item_selected.connect(_on_lang_selected)

	if contrast_check:
		contrast_check.toggled.connect(func(val):
			var a = get_node_or_null("/root/Accessibility")
			if a and a.has_method("set_high_contrast"):
				a.set_high_contrast(val)
		)
	if motion_check:
		motion_check.toggled.connect(func(val):
			var a = get_node_or_null("/root/Accessibility")
			if a and a.has_method("set_reduced_motion"):
				a.set_reduced_motion(val)
		)
	if scale_slider:
		scale_slider.value_changed.connect(func(val):
			var a = get_node_or_null("/root/Accessibility")
			if a and a.has_method("set_text_scale"):
				a.set_text_scale(val / 100.0)
		)
	if close_btn:
		_connect_button_safely(close_btn, func(): visible = false)

	_update_texts()
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(func(_l, _r): _update_texts())


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)
	btn.pressed.connect(callback)


func _on_lang_selected(index: int) -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc == null or not loc.has_method("set_locale"):
		return
	match index:
		0: loc.set_locale("en")
		1: loc.set_locale("ar")
		2: loc.set_locale("qps_expanded")
		3: loc.set_locale("qps_mirrored")


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


func _update_texts() -> void:
	if contrast_check: contrast_check.text = _tr("access.high_contrast", "High Contrast")
	if motion_check: motion_check.text = _tr("access.reduced_motion", "Reduced Motion")
	if close_btn: close_btn.text = _tr("recap.back_to_menu", "Back to Menu")
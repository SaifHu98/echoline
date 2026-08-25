class_name SettingsView
extends Control

# Settings & Accessibility Configuration

@onready var lang_option: OptionButton = $Panel/VBox/LangRow/OptionButton
@onready var contrast_check: CheckBox = $Panel/VBox/ContrastCheck
@onready var motion_check: CheckBox = $Panel/VBox/MotionCheck
@onready var scale_slider: HSlider = $Panel/VBox/ScaleRow/Slider
@onready var close_btn: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	if lang_option:
		lang_option.clear()
		lang_option.add_item("English", 0)
		lang_option.add_item("العربية (Arabic)", 1)
		lang_option.add_item("⟦Pseudo-Expanded⟧", 2)
		lang_option.add_item("⁅Pseudo-Mirrored⁆", 3)
		lang_option.item_selected.connect(_on_lang_selected)

	if contrast_check:
		contrast_check.toggled.connect(func(val): Accessibility.set_high_contrast(val))
	if motion_check:
		motion_check.toggled.connect(func(val): Accessibility.set_reduced_motion(val))
	if scale_slider:
		scale_slider.value_changed.connect(func(val): Accessibility.set_text_scale(val / 100.0))
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)

	_update_texts()
	EventBus.locale_changed.connect(func(_l, _r): _update_texts())

func _on_lang_selected(index: int) -> void:
	match index:
		0: Localization.set_locale("en")
		1: Localization.set_locale("ar")
		2: Localization.set_locale("qps_expanded")
		3: Localization.set_locale("qps_mirrored")

func _update_texts() -> void:
	if contrast_check: contrast_check.text = Localization.tr_key("access.high_contrast")
	if motion_check: motion_check.text = Localization.tr_key("access.reduced_motion")
	if close_btn: close_btn.text = Localization.tr_key("recap.back_to_menu")

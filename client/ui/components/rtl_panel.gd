class_name RTLPanel
extends PanelContainer

func _ready() -> void:
	EventBus.locale_changed.connect(_on_locale_changed)
	_apply_styling()

func _on_locale_changed(_locale: String, is_rtl: bool) -> void:
	layout_direction = Control.LAYOUT_DIRECTION_RTL if is_rtl else Control.LAYOUT_DIRECTION_LTR

func _apply_styling() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.4, 0.5, 0.4)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)


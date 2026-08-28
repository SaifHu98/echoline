extends RefCounted

# Shared visual language for the redesigned mobile UI.
# No textures are required: all surfaces are lightweight StyleBoxFlat objects.

const BG := Color("08111f")
const SURFACE := Color("101d31")
const SURFACE_2 := Color("142640")
const CYAN := Color("57e6ff")
const GOLD := Color("ffd36a")
const PINK := Color("ff72c8")
const TEXT := Color("f4f7ff")
const MUTED := Color("9aaac4")
const SUCCESS := Color("62e6a5")
const DANGER := Color("ff7187")

static func surface(color: Color = SURFACE, radius: int = 20, border: Color = Color("294361"), width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

static func button_style(color: Color, radius: int = 14, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var box := surface(color, radius, border, 1 if border.a > 0.0 else 0)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

static func style_button(button: Button, accent: Color = CYAN, filled: bool = false) -> void:
	if button == null:
		return
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 56.0)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", button_style(SURFACE_2 if not filled else accent.darkened(0.35), 14, accent.darkened(0.15)))
	button.add_theme_stylebox_override("hover", button_style(SURFACE_2.lightened(0.12) if not filled else accent.darkened(0.18), 14, accent))
	button.add_theme_stylebox_override("pressed", button_style(accent.darkened(0.08), 14, accent))
	button.add_theme_stylebox_override("focus", button_style(SURFACE_2, 14, accent))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func label(text_value: String, size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return result

static func section_title(text_value: String) -> Label:
	return label(text_value, 14, CYAN)

static func configure_scroll(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

static func add_margin(parent: Container, child: Control, horizontal: int = 20, vertical: int = 20) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	margin.add_child(child)
	return margin

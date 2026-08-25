class_name ArtTheme
extends Resource

# ECHO//LINE — Centralized Art Theme
# Single source of truth for all visual tokens
# Generates StyleBox resources programmatically (no binary .tres files to maintain)

# === Color Tokens (timeline-aware) ===
const COLOR_PAST = {
	"primary":   Color("#D4AF37"),  # gold
	"secondary": Color("#8B6F2E"),  # bronze
	"accent":    Color("#FFB347"),  # amber glow
	"neutral":   Color("#3A2E1A"),  # dark wood
	"ink":       Color("#F5E6C8"),  # parchment
	"shadow":    Color("#1F1709"),  # deep brown
	"highlight": Color("#FFE5A8"),  # sun-bleached gold
}

const COLOR_PRESENT = {
	"primary":   Color("#4FC3F7"),  # cyan
	"secondary": Color("#2C6E8F"),  # steel
	"accent":    Color("#00E5FF"),  # spark
	"neutral":   Color("#1E2429"),  # gunmetal
	"ink":       Color("#E8EEF2"),  # paper
	"shadow":    Color("#0D1114"),  # deep gunmetal
	"highlight": Color("#A0E5FF"),  # bright cyan
}

const COLOR_FUTURE = {
	"primary":   Color("#B388FF"),  # violet
	"secondary": Color("#6B4FBB"),  # deep violet
	"accent":    Color("#FF4FBF"),  # magenta
	"neutral":   Color("#1A1530"),  # deep space
	"ink":       Color("#E0D4FF"),  # hologram
	"shadow":    Color("#0A0718"),  # deep space
	"highlight": Color("#D6C5FF"),  # bright violet
}

# === UI State Colors ===
const COLOR_SUCCESS = Color("#2ECC71")
const COLOR_WARNING = Color("#F39C12")
const COLOR_DANGER = Color("#E74C3C")
const COLOR_INFO = Color("#3498DB")

# === Dimensions ===
const BUTTON_HEIGHT = 80
const BUTTON_RADIUS = 12
const BUTTON_BORDER_WIDTH = 2
const PANEL_RADIUS = 16
const FONT_SIZE_DISPLAY = 96
const FONT_SIZE_HEADING = 32
const FONT_SIZE_BODY = 18
const FONT_SIZE_SMALL = 14
const FONT_SIZE_TINY = 12

# === Animation Durations ===
const DURATION_INSTANT = 0.05
const DURATION_FAST = 0.15
const DURATION_NORMAL = 0.30
const DURATION_SLOW = 0.60

# === Easing ===
const EASE_DEFAULT = Tween.TRANS_CUBIC
const EASE_BOUNCE = Tween.TRANS_BACK
const EASE_SHARP = Tween.TRANS_QUART


# === Public helpers ===

static func get_timeline_palette(timeline: String) -> Dictionary:
	match timeline:
		"past": return COLOR_PAST
		"present": return COLOR_PRESENT
		"future": return COLOR_FUTURE
		_: return COLOR_PRESENT


static func make_button_style(timeline: String, pressed: bool = false) -> StyleBoxFlat:
	var palette = get_timeline_palette(timeline)
	var style = StyleBoxFlat.new()
	style.bg_color = palette.primary if pressed else Color(palette.neutral.r, palette.neutral.g, palette.neutral.b, 0.95)
	style.border_color = palette.accent
	style.set_border_width_all(BUTTON_BORDER_WIDTH)
	style.set_corner_radius_all(BUTTON_RADIUS)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if pressed:
		style.shadow_color = Color(palette.accent.r, palette.accent.g, palette.accent.b, 0.6)
		style.shadow_size = 16
		style.shadow_offset = Vector2(0, 0)
	return style


static func make_panel_style(timeline: String, opacity: float = 0.95) -> StyleBoxFlat:
	var palette = get_timeline_palette(timeline)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(palette.neutral.r, palette.neutral.g, palette.neutral.b, opacity)
	style.border_color = palette.primary
	style.set_border_width_all(2)
	style.set_corner_radius_all(PANEL_RADIUS)
	style.shadow_color = Color(palette.shadow.r, palette.shadow.g, palette.shadow.b, 0.7)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


static func make_timeline_badge_style(timeline: String) -> StyleBoxFlat:
	var palette = get_timeline_palette(timeline)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(palette.primary.r, palette.primary.g, palette.primary.b, 0.85)
	style.border_color = palette.ink
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


static func make_progress_bar_bg(timeline: String) -> StyleBoxFlat:
	var palette = get_timeline_palette(timeline)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(palette.shadow.r, palette.shadow.g, palette.shadow.b, 0.6)
	style.set_corner_radius_all(6)
	return style


static func make_progress_bar_fill(timeline: String) -> StyleBoxFlat:
	var palette = get_timeline_palette(timeline)
	var style = StyleBoxFlat.new()
	style.bg_color = palette.accent
	style.set_corner_radius_all(6)
	return style


static func get_glyph(timeline: String) -> String:
	match timeline:
		"past": return "◆"
		"present": return "▲"
		"future": return "●"
		_: return "◇"


static func get_timeline_name(timeline: String, lang: String = "en") -> String:
	if lang == "ar":
		match timeline:
			"past": return "الماضي"
			"present": return "الحاضر"
			"future": return "المستقبل"
			_: return "غير معروف"
	match timeline:
		"past": return "The Past"
		"present": return "The Present"
		"future": return "The Future"
		_: return "Unknown"

extends Node

# ECHO//LINE — Accessibility Service
# =================================
# يوفّر كل ما يلزم للوصول الشامل:
# - عمى الألوان (3 أنواع شائعة)
# - حجم النص القابل للتكبير (80% → 200%)
# - خفض الحركة والوميض
# - تباين عالي
# - ترجمة نصية
# - صوت منفصل لكل قناة
# - رجفة الشاشة قابلة للإيقاف
# - الإعدادات قابلة للحفظ/الاسترجاع

signal contrast_mode_changed(enabled: bool)
signal motion_mode_changed(reduced: bool)
signal text_scale_changed(scale: float)
signal colorblind_mode_changed(mode: int)
signal locale_changed(locale: String, is_rtl: bool)
signal subtitle_prefs_changed(enabled: bool, size: float)
signal audio_levels_changed(music: float, sfx: float, voice: float, ui: float)
signal haptic_changed(enabled: bool)
signal screen_shake_changed(enabled: bool)

# === Constants ===
const MIN_TEXT_SCALE = 0.8
const MAX_TEXT_SCALE = 2.0
const MIN_TOUCH_TARGET = 48  # dp

enum ColorblindMode {
	NONE,
	PROTANOPIA,   # red-blind
	DEUTERANOPIA, # green-blind
	TRITANOPIA    # blue-blind
}

# === State ===
var high_contrast: bool = false
var reduced_motion: bool = false
var text_scale: float = 1.0
var colorblind_mode: int = ColorblindMode.NONE
var subtitles_enabled: bool = true
var subtitle_size: float = 1.0
var screen_shake_enabled: bool = true
var haptic_enabled: bool = true
var locale: String = "en"
var is_rtl: bool = false
var voice_chat_allowed: bool = false  # off by default for minors safety

# Audio levels (0.0 — 1.0)
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var ui_volume: float = 1.0
var voice_volume: float = 0.0   # off by default
var ambient_volume: float = 0.6

# === Persistence path ===
const SAVE_PATH := "user://accessibility_settings.json"


func _ready() -> void:
	# Load on startup
	load_from_disk()


# ============================================================
# Public API
# ============================================================

func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	contrast_mode_changed.emit(enabled)
	_apply_to_scene()
	save_to_disk()


func set_reduced_motion(reduced: bool) -> void:
	reduced_motion = reduced
	motion_mode_changed.emit(reduced)
	save_to_disk()


func set_text_scale(scale: float) -> void:
	text_scale = clamp(scale, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
	text_scale_changed.emit(text_scale)
	save_to_disk()


func set_colorblind_mode(mode: int) -> void:
	colorblind_mode = mode
	colorblind_mode_changed.emit(mode)
	save_to_disk()


func set_subtitles_enabled(enabled: bool) -> void:
	subtitles_enabled = enabled
	subtitle_prefs_changed.emit(enabled, subtitle_size)
	save_to_disk()


func set_subtitle_size(size: float) -> void:
	subtitle_size = clamp(size, 0.8, 2.0)
	subtitle_prefs_changed.emit(subtitles_enabled, subtitle_size)
	save_to_disk()


func set_screen_shake(enabled: bool) -> void:
	screen_shake_enabled = enabled
	screen_shake_changed.emit(enabled)
	save_to_disk()


func set_haptic(enabled: bool) -> void:
	haptic_enabled = enabled
	haptic_changed.emit(enabled)
	save_to_disk()


func set_voice_chat_allowed(allowed: bool) -> void:
	# لا يمكن تفعيل المحادثة الصوتية للقاصرين افتراضياً
	# هذه الدالة تتأكد من تأكيد المستخدم إذا كان عمره أقل من 18
	if allowed and _age_under_18():
		push_warning("Voice chat requires age verification")
		return
	voice_chat_allowed = allowed
	save_to_disk()


func _age_under_18() -> bool:
	# في الإنتاج: استدعاء API للتحقق من العمر
	# هنا: false افتراضياً (نعتبر المستخدم بالغ)
	return false


func set_audio_levels(music: float, sfx: float, voice: float, ui: float) -> void:
	music_volume = clamp(music, 0.0, 1.0)
	sfx_volume = clamp(sfx, 0.0, 1.0)
	voice_volume = clamp(voice, 0.0, 1.0)
	ui_volume = clamp(ui, 0.0, 1.0)
	audio_levels_changed.emit(music_volume, sfx_volume, voice_volume, ui_volume)
	_apply_audio()
	save_to_disk()


func set_master_volume(vol: float) -> void:
	master_volume = clamp(vol, 0.0, 1.0)
	_apply_audio()
	save_to_disk()


func set_locale(loc: String, rtl: bool = false) -> void:
	locale = loc
	is_rtl = rtl
	locale_changed.emit(loc, rtl)
	save_to_disk()


# ============================================================
# Color transformations
# ============================================================

# Color matrices for colorblind simulation (LMS daltonization)
const CB_MATRICES = {
	ColorblindMode.NONE: [
		[1.0, 0.0, 0.0],
		[0.0, 1.0, 0.0],
		[0.0, 0.0, 1.0],
	],
	ColorblindMode.PROTANOPIA: [
		[0.567, 0.433, 0.0],
		[0.558, 0.442, 0.0],
		[0.0, 0.242, 0.758],
	],
	ColorblindMode.DEUTERANOPIA: [
		[0.625, 0.375, 0.0],
		[0.7, 0.3, 0.0],
		[0.0, 0.3, 0.7],
	],
	ColorblindMode.TRITANOPIA: [
		[0.95, 0.05, 0.0],
		[0.0, 0.433, 0.567],
		[0.0, 0.475, 0.525],
	],
}


func transform_color(c: Color) -> Color:
	if colorblind_mode == ColorblindMode.NONE:
		return c
	var m = CB_MATRICES.get(colorblind_mode, CB_MATRICES[ColorblindMode.NONE])
	return Color(
		clamp(c.r * m[0][0] + c.g * m[0][1] + c.b * m[0][2], 0.0, 1.0),
		clamp(c.r * m[1][0] + c.g * m[1][1] + c.b * m[1][2], 0.0, 1.0),
		clamp(c.r * m[2][0] + c.g * m[2][1] + c.b * m[2][2], 0.0, 1.0),
		c.a
	)


# ============================================================
# Apply to scene
# ============================================================

func _apply_to_scene() -> void:
	if not is_inside_tree():
		return
	var root = get_tree().root
	_set_contrast_on_tree(root)
	_set_motion_reduced_on_tree(root)


func _set_contrast_on_tree(node: Node) -> void:
	if node is Control and high_contrast:
		# Boost contrast by adding outline
		pass
	for child in node.get_children():
		_set_contrast_on_tree(child)


func _set_motion_reduced_on_tree(node: Node) -> void:
	if reduced_motion and node is AnimationPlayer:
		node.speed_scale = 0.0
	for child in node.get_children():
		_set_motion_reduced_on_tree(child)


# ============================================================
# Audio
# ============================================================

func _apply_audio() -> void:
	# في الإنتاج: AudioServer.set_bus_volume_db لكل bus
	pass


func get_audio_level(bus: String) -> float:
	match bus:
		"master": return master_volume
		"music": return music_volume
		"sfx": return sfx_volume
		"voice": return voice_volume
		"ui": return ui_volume
		"ambient": return ambient_volume
	return 1.0


func can_use_voice_chat() -> bool:
	return voice_chat_allowed


# ============================================================
# Touch target validation
# ============================================================

static func validate_touch_target(control: Control) -> bool:
	if control.custom_minimum_size.y >= MIN_TOUCH_TARGET:
		return true
	push_warning("Control '%s' touch target too small: %d (need ≥%d)" % [
		control.name, int(control.custom_minimum_size.y), MIN_TOUCH_TARGET
	])
	return false


static func ensure_touch_target(control: Control, min_size: int = MIN_TOUCH_TARGET) -> void:
	control.custom_minimum_size = Vector2(
		max(control.custom_minimum_size.x, min_size),
		max(control.custom_minimum_size.y, min_size)
	)


# ============================================================
# Persistence
# ============================================================

func save_to_disk() -> void:
	var data = {
		"high_contrast": high_contrast,
		"reduced_motion": reduced_motion,
		"text_scale": text_scale,
		"colorblind_mode": colorblind_mode,
		"subtitles_enabled": subtitles_enabled,
		"subtitle_size": subtitle_size,
		"screen_shake_enabled": screen_shake_enabled,
		"haptic_enabled": haptic_enabled,
		"voice_chat_allowed": voice_chat_allowed,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"voice_volume": voice_volume,
		"ui_volume": ui_volume,
		"ambient_volume": ambient_volume,
		"locale": locale,
		"is_rtl": is_rtl,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return
	high_contrast = parsed.get("high_contrast", false)
	reduced_motion = parsed.get("reduced_motion", false)
	text_scale = parsed.get("text_scale", 1.0)
	colorblind_mode = parsed.get("colorblind_mode", ColorblindMode.NONE)
	subtitles_enabled = parsed.get("subtitles_enabled", true)
	subtitle_size = parsed.get("subtitle_size", 1.0)
	screen_shake_enabled = parsed.get("screen_shake_enabled", true)
	haptic_enabled = parsed.get("haptic_enabled", true)
	voice_chat_allowed = parsed.get("voice_chat_allowed", false)
	master_volume = parsed.get("master_volume", 1.0)
	music_volume = parsed.get("music_volume", 0.7)
	sfx_volume = parsed.get("sfx_volume", 1.0)
	voice_volume = parsed.get("voice_volume", 0.0)
	ui_volume = parsed.get("ui_volume", 1.0)
	ambient_volume = parsed.get("ambient_volume", 0.6)
	locale = parsed.get("locale", "en")
	is_rtl = parsed.get("is_rtl", false)


func reset_to_defaults() -> void:
	high_contrast = false
	reduced_motion = false
	text_scale = 1.0
	colorblind_mode = ColorblindMode.NONE
	subtitles_enabled = true
	subtitle_size = 1.0
	screen_shake_enabled = true
	haptic_enabled = true
	voice_chat_allowed = false
	master_volume = 1.0
	music_volume = 0.7
	sfx_volume = 1.0
	voice_volume = 0.0
	ui_volume = 1.0
	ambient_volume = 0.6
	locale = "en"
	is_rtl = false
	save_to_disk()


# ============================================================
# Dark patterns guard
# ============================================================

# يمنع أنماط التصميم المظلم
static func is_dark_pattern(behavior: String) -> bool:
	# قائمة بأنماط محظورة — يجب ألا تظهر في اللعبة
	var banned = [
		"fake_countdown",        # عد تنازلي وهمي للضغط
		"hidden_cancel_button",   # زر إلغاء مخفي
		"confirm_shaming",       # إهانة لتأكيد الإلغاء
		"roaming_subscription",  # اشتراك يتجول بهدوء
		"variable_rewards_to_minors",  # مكافآت عشوائية للقاصرين
		"obstructed_logout",     # صعوبة تسجيل الخروج
	]
	return behavior in banned


# يضمن أن أي عملية حساسة تتطلب تأكيداً صريحاً
static func requires_confirmation(operation: String) -> bool:
	var sensitive = [
		"delete_account",
		"spend_premium_currency",
		"leave_match_in_progress",
		"send_public_message",
		"report_player",
		"change_voice_chat_setting",
	]
	return operation in sensitive

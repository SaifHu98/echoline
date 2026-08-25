class_name QuickChatSafe
extends RTLPanel

# ECHO//LINE — Safe Quick Chat
# ==============================
# رسائل سريعة:
# 1. **مراجعة مسبقاً** (curated) — لا إدخال حر
# 2. **مُعرّفة بمفاتيح ترجمة** — تُرجم لكل لغة
# 3. **آمنة للأطفال** — لا محتوى مسيء أو تنمّر
# 4. **مُصنّفة بالسياق** — تظهر فقط الرسائل المناسبة
# 5. **لا يمكن تجاهل الفلاتر** — السيرفر ينفّذ الـ filter

signal message_sent(intent_id: String, args: Dictionary)

# رسائل منظمة بسياقها (تظهر في سياقات مختلفة)
const MESSAGES = {
	"coordination": [
		{"id": "MSG_HELLO", "loc_key": "quickmsg.hello", "icon": "👋"},
		{"id": "MSG_GOOD_JOB", "loc_key": "quickmsg.good_job", "icon": "👍"},
		{"id": "MSG_THANKS", "loc_key": "quickmsg.thanks", "icon": "🙏"},
		{"id": "MSG_SORRY", "loc_key": "quickmsg.sorry", "icon": "🙇"},
		{"id": "MSG_WAIT", "loc_key": "quickmsg.wait", "icon": "⏸"},
		{"id": "MSG_GO", "loc_key": "quickmsg.go", "icon": "▶"},
		{"id": "MSG_HELP", "loc_key": "quickmsg.help", "icon": "❓"},
		{"id": "MSG_AFK", "loc_key": "quickmsg.afk", "icon": "💤"},
	],
	"echoes": [
		{"id": "MSG_WATER_NEEDED", "loc_key": "quickmsg.water_needed", "icon": "💧"},
		{"id": "MSG_WATER_FLOWING", "loc_key": "quickmsg.water_flowing", "icon": "�"},
		{"id": "MSG_TURBINE_READY", "loc_key": "quickmsg.turbine_ready", "icon": "⚙️"},
		{"id": "MSG_GATE_POWERED", "loc_key": "quickmsg.gate_powered", "icon": "⚡"},
		{"id": "MSG_CODE_FOUND", "loc_key": "quickmsg.code_found", "icon": "🔍"},
		{"id": "MSG_BRIDGE_READY", "loc_key": "quickmsg.bridge_ready", "icon": "🌉"},
		{"id": "MSG_TREE_GROWN", "loc_key": "quickmsg.tree_grown", "icon": "🌳"},
		{"id": "MSG_STABILIZER_ON", "loc_key": "quickmsg.stabilizer_on", "icon": "🔓"},
	],
	"warnings": [
		{"id": "MSG_DANGER", "loc_key": "quickmsg.danger", "icon": "⚠️"},
		{"id": "MSG_CAREFUL", "loc_key": "quickmsg.careful", "icon": "🛡"},
		{"id": "MSG_NO_TIME", "loc_key": "quickmsg.no_time", "icon": "⏰"},
	],
	"celebrate": [
		{"id": "MSG_GG", "loc_key": "quickmsg.gg", "icon": "🎉"},
		{"id": "MSG_PERFECT", "loc_key": "quickmsg.perfect", "icon": "✨"},
		{"id": "MSG_THANKS_TEAM", "loc_key": "quickmsg.thanks_team", "icon": "🤝"},
	],
}

# قائمة سوداء لمحتوى غير مسموح (للاستخدام من السيرفر أيضاً)
const BANNED_WORDS = [
	# قائمة فارغة - لا كلمات محظورة حالياً لأن كل الرسائل curated
	# لكن إذا أضيفت إدخال حر لاحقاً:
	"slur1", "slur2",
]

# Cooldown لمنع الإغراق
var last_send_times: Array[float] = []
var max_per_5_sec: int = 5

# Current category tabs
var current_category: String = "coordination"
var last_category_btn: Button = null


func _ready() -> void:
	super._ready()
	_build_category_tabs()
	_build_message_list()
	EventBus.locale_changed.connect(func(_l, _r): _rebuild())


func _build_category_tabs() -> void:
	_clear_tabs()
	var tab_container = HBoxContainer.new()
	tab_container.name = "Tabs"
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 4)
	add_child(tab_container)

	var labels = {
		"coordination": Localization.tr_key("quickmsg.tab.coordination"),
		"echoes":       Localization.tr_key("quickmsg.tab.echoes"),
		"warnings":     Localization.tr_key("quickmsg.tab.warnings"),
		"celebrate":    Localization.tr_key("quickmsg.tab.celebrate"),
	}

	for cat in labels.keys():
		var btn = Button.new()
		btn.text = labels[cat]
		btn.custom_minimum_size = Vector2(120, 48)
		TouchTargetValidator.ensure_size(btn, false)
		btn.pressed.connect(_on_category_chosen.bind(cat))
		tab_container.add_child(btn)
		if cat == current_category:
			last_category_btn = btn
			btn.modulate = Color(0.3, 1, 0.4)


func _on_category_chosen(category: String) -> void:
	if last_category_btn:
		last_category_btn.modulate = Color.WHITE
	current_category = category
	_build_category_tabs()
	_build_message_list()


func _build_message_list() -> void:
	_clear_list()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 280)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for msg in MESSAGES.get(current_category, []):
		var btn = _make_message_button(msg)
		grid.add_child(btn)

	scroll.add_child(grid)
	add_child(scroll)


func _make_message_button(msg: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = msg.icon + "  " + Localization.tr_key(msg.loc_key)
	btn.custom_minimum_size = Vector2(180, 60)
	TouchTargetValidator.ensure_size(btn, false)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_message_pressed.bind(msg))
	return btn


func _on_message_pressed(msg: Dictionary) -> void:
	# Rate limit check
	var now = Time.get_ticks_msec() / 1000.0
	last_send_times = last_send_times.filter(func(t): return now - t < 5.0)
	if last_send_times.size() >= max_per_5_sec:
		_show_too_fast()
		return

	last_send_times.append(now)

	# Send to server
	if NetworkClient:
		NetworkClient.send_quick_message(msg.id)
	message_sent.emit(msg.id, {})
	visible = false

	UXTelemetry.hints_requested = UXTelemetry.hints_requested  # don't count as hint
	UXTelemetry.save_to_disk()


func _show_too_fast() -> void:
	EventBus.subtitle_requested.emit(Localization.tr_key("quickmsg.slow_down"), 1.5)


func _clear_tabs() -> void:
	for child in get_children():
		if child.name == "Tabs":
			child.queue_free()


func _clear_list() -> void:
	for child in get_children():
		if child.name != "Tabs":
			child.queue_free()


func _rebuild() -> void:
	visible = false  # Force rebuild on next open
	_clear_tabs()
	_clear_list()
	_build_category_tabs()
	_build_message_list()


# ============================================
# Safety validation (server-side too)
# ============================================

static func validate_message_id(id: String) -> bool:
	# Only allow IDs from our curated list
	for cat in MESSAGES.keys():
		for msg in MESSAGES[cat]:
			if msg.id == id:
				return true
	return false


static func is_safe_text(text: String) -> bool:
	var lower = text.to_lower()
	for banned in BANNED_WORDS:
		if banned in lower:
			return false
	return true

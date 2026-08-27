extends Node

# True BiDi Localization Service for ECHO//LINE (أصداء)

const RTL_LOCALES = ["ar", "qps_mirrored", "fa", "ur", "he"]

var current_locale: String = "en"
var is_rtl: bool = false
var catalogs: Dictionary = {}
# P2-8: cached active catalogs to avoid repeated dictionary lookups in
# _tr() / tr_key() — every label update goes through these.
var _active_catalog: Dictionary = {}
var _fallback_catalog: Dictionary = {}

# Embedded fallback strings (used when JSON catalogs fail to load in exported builds)
const FALLBACK_EN := {
	"app.title": "ECHO//LINE",
	"app.subtitle": "Echoes Across Time",
	"menu.play": "PLAY",
	"menu.tutorial": "HOW TO PLAY",
	"menu.settings": "SETTINGS",
	"menu.language": "Language",
	"menu.credits": "CREDITS",
	"menu.credits_full": "⭐  CREDITS",
	"menu.back": "← BACK",
	"menu.section_play": "🎮 PLAY",
	"menu.section_options": "⚙ OPTIONS",
	"lobby.join": "JOIN ROOM",
	"lobby.create": "CREATE NEW ROOM",
	"lobby.ready": "READY",
	"lobby.ready_done": "✓ READY",
	"lobby.leave": "LEAVE",
	"lobby.refresh": "🔄 REFRESH",
	"lobby.code_placeholder": "Enter room code (min 4 chars)",
	"lobby.code_label": "Room code: {code}",
	"lobby.waiting": "Waiting for players ({count}/4)...",
	"lobby.status_open": "OPEN",
	"lobby.status_ready": "READY",
	"lobby.status_full": "FULL",
	"lobby.status_in_progress": "IN PROGRESS",
	"lobby.rooms_unavailable": "⚠ Rooms list unavailable",
	"lobby.no_rooms_open": "📭 No open rooms. Create one!",
	"lobby.creating": "Creating room...",
	"lobby.connecting": "Connecting to server...",
	"lobby.create_failed": "Create failed: {err}",
	"lobby.join_failed": "Join failed: {err}",
	"lobby.invalid_code": "Enter a valid room code (min 4 chars)",
	"lobby.room_created": "Room created: {code} — Pick your timeline",
	"lobby.joined_room": "Joined room: {code} — Pick your timeline",
	"lobby.players_count": "Players: {count}/{max}",
	"lobby.all_ready": "Everyone ready! Starting...",
	"lobby.left_room": "Left the room",
	"timeline.past": "◆  THE PAST",
	"timeline.past.desc": "Memory & Heritage",
	"timeline.present": "▲  THE PRESENT",
	"timeline.present.desc": "Reality & Action",
	"timeline.future": "●  THE FUTURE",
	"timeline.future.desc": "Possibility & Hope",
	"hud.interact": "INTERACT",
	"hud.quick_chat": "CHAT",
	"hud.ping": "PING",
	"settings.title": "⚙  SETTINGS",
	"settings.full": "Full settings panel coming in next build.",
	"tutorial.title": "📖  HOW TO PLAY",
	"credits.title": "⭐  CREDITS"
}

const FALLBACK_AR := {
	"app.title": "أصداء",
	"app.subtitle": "أَصْدَاء عبر الزَّمَن",
	"menu.play": "ابدأ اللعب",
	"menu.tutorial": "كيفية اللعب",
	"menu.settings": "الإعدادات",
	"menu.language": "اللغة",
	"menu.credits": "الفضل",
	"menu.credits_full": "⭐  الفضل",
	"menu.back": "→ رجوع",
	"menu.section_play": "🎮 ابدأ",
	"menu.section_options": "⚙ خيارات",
	"lobby.join": "🔑 انضم للغرفة",
	"lobby.create": "✨ إنشاء غرفة جديدة",
	"lobby.ready": "جاهز",
	"lobby.ready_done": "✓ جاهز",
	"lobby.leave": "🚪 مغادرة",
	"lobby.refresh": "🔄 تحديث",
	"lobby.code_placeholder": "أدخل رمز الغرفة (4 أحرف على الأقل)",
	"lobby.code_label": "رمز الغرفة: {code}",
	"lobby.waiting": "في انتظار اللاعبين ({count}/4)...",
	"lobby.status_open": "مفتوحة",
	"lobby.status_ready": "جاهزة",
	"lobby.status_full": "ممتلئة",
	"lobby.status_in_progress": "قيد اللعب",
	"lobby.rooms_unavailable": "⚠ قائمة الغرف غير متوفرة",
	"lobby.no_rooms_open": "📭 لا توجد غرف مفتوحة. أنشئ واحدة!",
	"lobby.creating": "جاري إنشاء الغرفة...",
	"lobby.connecting": "جاري الاتصال بالخادم...",
	"lobby.create_failed": "فشل الإنشاء: {err}",
	"lobby.join_failed": "فشل الانضمام: {err}",
	"lobby.invalid_code": "أدخل رمز غرفة صالح (4 أحرف على الأقل)",
	"lobby.room_created": "تم إنشاء الغرفة: {code} — اختر خطك الزمني",
	"lobby.joined_room": "انضممت للغرفة: {code} — اختر خطك الزمني",
	"lobby.players_count": "اللاعبون: {count}/{max}",
	"lobby.all_ready": "الجميع جاهز! جاري البدء...",
	"lobby.left_room": "غادرت الغرفة",
	"timeline.past": "◆  الماضي",
	"timeline.past.desc": "الذاكرة والتراث",
	"timeline.present": "▲  الحاضر",
	"timeline.present.desc": "الواقع والفعل",
	"timeline.future": "●  المستقبل",
	"timeline.future.desc": "الإمكانية والأمل",
	"hud.interact": "تفاعل",
	"hud.quick_chat": "دردشة",
	"hud.ping": "إشارة",
	"settings.title": "⚙  الإعدادات",
	"settings.full": "لوحة الإعدادات الكاملة قريباً.",
	"tutorial.title": "📖  كيفية اللعب",
	"credits.title": "⭐  الفضل"
}

func _ready() -> void:
	load_all_catalogs()
	# Detect system locale. P3-1: prefer the full locale tag and treat the
	# RTL variants explicitly so we don't default to English on Arabic
	# devices that report variants like "ar_IQ" or "ku".
	var lang := OS.get_locale_language()
	if lang in ["ar", "fa", "ur", "he", "ku", "yi"]:
		set_locale("ar")
	else:
		set_locale("en")


func t(key: String, params: Dictionary = {}) -> String:
	return tr_key(key, params)


func get_current_locale() -> String:
	return current_locale


func get_is_rtl() -> bool:
	return is_rtl

func load_all_catalogs() -> void:
	var loc_paths = {
		"en": "res://../shared/localization/en.json",
		"ar": "res://../shared/localization/ar.json",
		"qps_expanded": "res://../shared/localization/qps_expanded.json",
		"qps_mirrored": "res://../shared/localization/qps_mirrored.json"
	}

	# Always seed fallback catalogs (used in exported builds if JSON path fails)
	catalogs["en"] = FALLBACK_EN.duplicate()
	catalogs["ar"] = FALLBACK_AR.duplicate()
	# Pseudo-locales get a clone of English until proper JSON files exist
	catalogs["qps_expanded"] = FALLBACK_EN.duplicate()
	catalogs["qps_mirrored"] = FALLBACK_EN.duplicate()

	for loc in loc_paths.keys():
		var p = loc_paths[loc]
		if FileAccess.file_exists(p):
			var file = FileAccess.open(p, FileAccess.READ)
			if file == null:
				push_warning("[Localization] Could not open %s" % p)
				continue
			var json_text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary:
				# Merge JSON catalog over fallback (JSON takes priority)
				if not catalogs.has(loc):
					catalogs[loc] = FALLBACK_EN.duplicate()
				var merged: Dictionary = catalogs[loc].duplicate()
				for k in parsed.keys():
					merged[k] = parsed[k]
				catalogs[loc] = merged
		# If file doesn't exist, fallback catalog is already in place


func set_locale(new_locale: String) -> void:
	if not catalogs.has(new_locale):
		push_warning("[Localization] Catalog missing for %s — falling back to en" % new_locale)
		new_locale = "en"

	current_locale = new_locale
	is_rtl = RTL_LOCALES.has(current_locale)
	# P2-8: refresh the cached lookup tables.
	_active_catalog = catalogs.get(current_locale, {})
	_fallback_catalog = catalogs.get("en", {})

	# Set Godot engine root layout direction
	# Control.LAYOUT_DIRECTION_LTR = 0, LAYOUT_DIRECTION_RTL = 1, LOCALE = 2
	# Window.layout_direction is read-only in headless mode (no display);
	# we silently skip the assignment when the engine isn't drawing a window.
	if DisplayServer.get_name() != "headless":
		var root = get_tree().root
		if root:
			root.layout_direction = 1 if is_rtl else 0

	EventBus.locale_changed.emit(current_locale, is_rtl)
	print("[Localization] Locale changed to %s (RTL=%s)" % [current_locale, is_rtl])


func tr_key(key: String, params: Dictionary = {}) -> String:
	# P2-8: use cached active catalog instead of two dict.has/[] chains
	# per call. The cached references are refreshed in set_locale().
	var raw_str: String = ""
	if _active_catalog.has(key):
		raw_str = _active_catalog[key]
	elif _fallback_catalog.has(key):
		raw_str = _fallback_catalog[key]
	elif FALLBACK_EN.has(key):
		raw_str = FALLBACK_EN[key]
	else:
		return "[" + key + "]"

	# Interpolate variables safely with BiDi isolation
	for placeholder in params.keys():
		var val_str = str(params[placeholder])
		# Wrap interpolated variables in unicode isolate markers to avoid corrupting RTL text flow
		if is_rtl:
			val_str = "\u2068" + val_str + "\u2069"
		raw_str = raw_str.replace("{" + placeholder + "}", val_str)

	return raw_str



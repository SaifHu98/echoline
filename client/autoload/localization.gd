extends Node

# True BiDi Localization Service for ECHO//LINE (أصداء)

const RTL_LOCALES = ["ar", "qps_mirrored", "fa", "ur", "he"]

var current_locale: String = "en"
var is_rtl: bool = false
var catalogs: Dictionary = {}

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
	"lobby.join": "JOIN ROOM",
	"lobby.create": "CREATE NEW ROOM",
	"lobby.ready": "READY",
	"lobby.ready_done": "✓ READY",
	"lobby.leave": "LEAVE",
	"lobby.code_label": "Room code: {code}",
	"lobby.waiting": "Waiting for players ({count}/4)...",
	"timeline.past": "◆  THE PAST",
	"timeline.past.desc": "Memory & Heritage",
	"timeline.present": "▲  THE PRESENT",
	"timeline.present.desc": "Reality & Action",
	"timeline.future": "●  THE FUTURE",
	"timeline.future.desc": "Possibility & Hope",
	"hud.interact": "INTERACT",
	"hud.quick_chat": "CHAT",
	"hud.ping": "PING",
	"settings.title": "�  SETTINGS",
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
	"lobby.join": "انضم للغرفة",
	"lobby.create": "إنشاء غرفة",
	"lobby.ready": "جاهز",
	"lobby.ready_done": "✓ جاهز",
	"lobby.leave": "مغادرة",
	"lobby.code_label": "رمز الغرفة: {code}",
	"lobby.waiting": "في انتظار اللاعبين ({count}/4)...",
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
	# Detect system locale or default to English/Arabic
	var os_locale = OS.get_locale_language()
	if os_locale == "ar":
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

	# Set Godot engine root layout direction
	var root = get_tree().root
	if root:
		if is_rtl:
			root.layout_direction = Control.LAYOUT_DIRECTION_RTL
		else:
			root.layout_direction = Control.LAYOUT_DIRECTION_LTR

	EventBus.locale_changed.emit(current_locale, is_rtl)
	print("[Localization] Locale changed to %s (RTL=%s)" % [current_locale, is_rtl])


func tr_key(key: String, params: Dictionary = {}) -> String:
	var raw_str: String = ""
	if catalogs.has(current_locale) and catalogs[current_locale].has(key):
		raw_str = catalogs[current_locale][key]
	elif catalogs.has("en") and catalogs["en"].has(key):
		raw_str = catalogs["en"][key]
	else:
		# Final fallback before returning "[key]"
		if FALLBACK_EN.has(key):
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



extends Node

# True BiDi Localization Service for ECHO//LINE (أصداء)

const RTL_LOCALES = ["ar", "qps_mirrored", "fa", "ur", "he"]

var current_locale: String = "en"
var is_rtl: bool = false
var catalogs: Dictionary = {}

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

func load_all_catalogs() -> void:
	var loc_paths = {
		"en": "res://../shared/localization/en.json",
		"ar": "res://../shared/localization/ar.json",
		"qps_expanded": "res://../shared/localization/qps_expanded.json",
		"qps_mirrored": "res://../shared/localization/qps_mirrored.json"
	}

	for loc in loc_paths.keys():
		var p = loc_paths[loc]
		if FileAccess.file_exists(p):
			var file = FileAccess.open(p, FileAccess.READ)
			var json_text = file.get_as_text()
			var parsed = JSON.parse_string(json_text)
			if parsed is Dictionary:
				catalogs[loc] = parsed
		else:
			# In exported builds or if relative path fails, fallback to embedded minimal dictionary
			catalogs[loc] = {}

func set_locale(new_locale: String) -> void:
	if not catalogs.has(new_locale) and new_locale != "en":
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

func tr_key(key: String, params: Dictionary = {}) -> String:
	var raw_str: String = ""
	if catalogs.has(current_locale) and catalogs[current_locale].has(key):
		raw_str = catalogs[current_locale][key]
	elif catalogs.has("en") and catalogs["en"].has(key):
		raw_str = catalogs["en"][key]
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


extends Node

# ECHO//LINE — Audio Mixer Service
# ================================
# 4 قنوات صوتية منفصلة مع ضوابط مستقلة:
# - Master (العام)
# - Music (الموسيقى التصويرية)
# - SFX (مؤثرات اللعبة)
# - UI (أصوات الواجهة)
# - Voice (المحادثة الصوتية — معطّلة افتراضياً)
# - Ambient (الأصوات المحيطة)

signal channel_changed(channel: String, level: float)
signal muted_changed(channel: String, muted: bool)
signal voice_chat_toggled(enabled: bool)

const CHANNELS = ["master", "music", "sfx", "ui", "voice", "ambient"]
const CHANNEL_BUSES = {
	"master":  "Master",
	"music":   "Music",
	"sfx":     "SFX",
	"ui":      "UI",
	"voice":   "Voice",
	"ambient": "Ambient",
}

# حالة كل قناة
var levels: Dictionary = {
	"master": 1.0,
	"music": 0.7,
	"sfx": 1.0,
	"ui": 1.0,
	"voice": 0.0,
	"ambient": 0.5,
}
var muted: Dictionary = {
	"master": false,
	"music": false,
	"sfx": false,
	"ui": false,
	"voice": true,  # معطّلة افتراضياً (خصوصية القاصرين)
	"ambient": false,
}
var voice_chat_enabled: bool = false


func _ready() -> void:
	_ensure_audio_buses()
	_apply_all()
	# مزامنة مع AccessibilityService
	if Accessibility.has_signal("audio_levels_changed"):
		Accessibility.audio_levels_changed.connect(_on_accessibility_audio_changed)


func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_count() < CHANNELS.size() + 1:
		# إنشاء buses إن لم تكن موجودة
		for ch in CHANNELS:
			if AudioServer.get_bus_index(CHANNEL_BUSES[ch]) < 0:
				AudioServer.add_bus(AudioServer.get_bus_count())
				AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, CHANNEL_BUSES[ch])


func _on_accessibility_audio_changed(music: float, sfx: float, voice: float, ui: float) -> void:
	set_channel("music", music)
	set_channel("sfx", sfx)
	set_channel("voice", voice)
	set_channel("ui", ui)


# === Public API ===

func set_channel(channel: String, level: float) -> void:
	if channel not in levels:
		push_warning("Unknown audio channel: %s" % channel)
		return
	levels[channel] = clamp(level, 0.0, 1.0)
	_apply_channel(channel)
	channel_changed.emit(channel, levels[channel])


func toggle_mute(channel: String) -> void:
	if channel not in muted:
		return
	muted[channel] = not muted[channel]
	_apply_channel(channel)
	muted_changed.emit(channel, muted[channel])


func set_muted(channel: String, value: bool) -> void:
	if channel not in muted:
		return
	muted[channel] = value
	_apply_channel(channel)
	muted_changed.emit(channel, value)


func enable_voice_chat(confirm_age: bool = false) -> bool:
	# للأمان: يجب تأكيد العمر قبل تفعيل المحادثة الصوتية
	if not confirm_age:
		push_warning("Voice chat requires age confirmation")
		return false
	voice_chat_enabled = true
	muted["voice"] = false
	set_channel("voice", 0.7)
	voice_chat_toggled.emit(true)
	return true


func disable_voice_chat() -> void:
	voice_chat_enabled = false
	muted["voice"] = true
	set_channel("voice", 0.0)
	voice_chat_toggled.emit(false)


func is_voice_chat_enabled() -> bool:
	return voice_chat_enabled


func get_level(channel: String) -> float:
	return levels.get(channel, 1.0)


func is_muted(channel: String) -> bool:
	return muted.get(channel, false)


func get_effective_level(channel: String) -> float:
	# المستوى النهائي بعد تطبيق mute و master
	if muted.get(channel, false):
		return 0.0
	var lvl = levels.get(channel, 1.0)
	if channel != "master":
		lvl *= levels.get("master", 1.0)
	return clamp(lvl, 0.0, 1.0)


# === Apply to audio server ===

func _apply_channel(channel: String) -> void:
	if not AudioServer.get_bus_index(CHANNEL_BUSES.get(channel, "")) >= 0:
		return
	var bus_idx = AudioServer.get_bus_index(CHANNEL_BUSES[channel])
	var effective = get_effective_level(channel)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(effective))
	AudioServer.set_bus_mute(bus_idx, muted.get(channel, false))


func _apply_all() -> void:
	for ch in CHANNELS:
		_apply_channel(ch)


func linear_to_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


# === Persist ===

func save_to_disk() -> void:
	var data = {
		"levels": levels,
		"muted": muted,
		"voice_chat_enabled": voice_chat_enabled,
	}
	var f = FileAccess.open("user://audio_settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_from_disk() -> void:
	if not FileAccess.file_exists("user://audio_settings.json"):
		return
	var f = FileAccess.open("user://audio_settings.json", FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var l = parsed.get("levels", {})
		var m = parsed.get("muted", {})
		for ch in CHANNELS:
			if l.has(ch): levels[ch] = l[ch]
			if m.has(ch): muted[ch] = m[ch]
		voice_chat_enabled = parsed.get("voice_chat_enabled", false)
	_apply_all()

extends Control

# ECHO//LINE — Connection State Indicator
# =========================================
# مؤشرات واضحة بصرية + نصية لحالة:
# - الاتصال بالسيرفر
# - الاستعداد في الغرفة
# - الخط الزمني للاعب
# - العلاقة سبب → نتيجة (Echo Direction)
#
# يستخدم إشارات EventBus بدون polling.

@onready var connection_icon: ColorRect = $Connection/Icon
@onready var connection_label: Label = $Connection/Label
@onready var ready_icon: ColorRect = $ReadyIndicator/Icon
@onready var ready_label: Label = $ReadyIndicator/Label
@onready var timeline_badge: PanelContainer = $TimelineBadge
@onready var timeline_glyph: Label = $TimelineBadge/Glyph
@onready var timeline_label: Label = $TimelineBadge/Label
@onready var echo_direction_icon: ColorRect = $EchoDirection/Icon
@onready var echo_direction_label: Label = $EchoDirection/Label

var current_state: String = "disconnected"
var current_timeline: String = ""
var last_echo_direction: String = ""
var last_echo_clear_time: float = 0.0


func _ready() -> void:
	_set_state("disconnected", "●", Localization.tr_key("status.disconnected"))
	_set_ready(false)
	_set_timeline("")
	_set_echo_direction("")
	TouchTargetValidator.ensure_size(self, false)

	if EventBus.has_signal("network_connected"):
		EventBus.network_connected.connect(_on_connected)
	if EventBus.has_signal("network_error"):
		EventBus.network_error.connect(_on_disconnected)
	if EventBus.has_signal("lobby_updated"):
		EventBus.lobby_updated.connect(_on_lobby_updated)
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)
	if NetworkClient.has_signal("reconnect_attempting"):
		NetworkClient.reconnect_attempting.connect(_on_reconnect_attempting)


func _process(_delta: float) -> void:
	# إخفاء اتجاه الـ Echo بعد 4 ثوانٍ
	if last_echo_clear_time > 0 and Time.get_ticks_msec() / 1000.0 - last_echo_clear_time > 4.0:
		_set_echo_direction("")


func _set_state(state: String, icon: String, text: String) -> void:
	current_state = state
	if connection_icon:
		match state:
			"connected": connection_icon.color = Color(0.3, 1.0, 0.4, 1)
			"connecting": connection_icon.color = Color(1.0, 0.8, 0.2, 1)
			"reconnecting":
				connection_icon.color = Color(1.0, 0.6, 0.2, 1)
				_animate_pulse(connection_icon)
			"disconnected": connection_icon.color = Color(1.0, 0.3, 0.3, 1)
		if icon != "":
			# ارسم الـ icon كنص في الـ label
			pass
	if connection_label:
		connection_label.text = icon + " " + text


func _set_ready(ready: bool) -> void:
	if ready_icon:
		ready_icon.color = Color(0.3, 1.0, 0.4, 1) if ready else Color(0.5, 0.5, 0.5, 1)
	if ready_label:
		ready_label.text = Localization.tr_key("status.ready_yes" if ready else "status.ready_no")
	if ready:
		_animate_pulse(ready_icon)


func _set_timeline(timeline: String) -> void:
	current_timeline = timeline
	if timeline == "":
		if timeline_badge: timeline_badge.visible = false
		return
	if timeline_badge: timeline_badge.visible = true
	if timeline_glyph:
		match timeline:
			"past": timeline_glyph.text = "◆"
			"present": timeline_glyph.text = "▲"
			"future": timeline_glyph.text = "●"
			_: timeline_glyph.text = "?"
	if timeline_label:
		timeline_label.text = Localization.tr_key("timeline." + timeline)
	# تلوين بحسب الـ Timeline
	var color = Color.WHITE
	match timeline:
		"past": color = Color("#D4AF37")
		"present": color = Color("#4FC3F7")
		"future": color = Color("#B388FF")
	if timeline_badge:
		var sb = StyleBoxFlat.new()
		sb.bg_color = color.darkened(0.6)
		sb.border_color = color
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		timeline_badge.add_theme_stylebox_override("panel", sb)
	if timeline_glyph:
		timeline_glyph.add_theme_color_override("font_color", color)


func _set_echo_direction(direction: String) -> void:
	last_echo_direction = direction
	if echo_direction_icon:
		echo_direction_icon.color = Color(1, 0.84, 0.4, 1) if direction != "" else Color(0.3, 0.3, 0.3, 0.5)
	if echo_direction_label:
		echo_direction_label.text = direction


func _animate_pulse(node: Control) -> void:
	if node == null:
		return
	var t = create_tween().set_loops(3)
	t.tween_property(node, "modulate:a", 0.5, 0.3)
	t.tween_property(node, "modulate:a", 1.0, 0.3)


# === Event handlers ===

func _on_connected() -> void:
	_set_state("connected", "✓", Localization.tr_key("status.online"))


func _on_disconnected(reason: String) -> void:
	_set_state("disconnected", "�", Localization.tr_key("status.offline") + ": " + reason)


func _on_reconnect_attempting(attempt: int, max_attempts: int) -> void:
	_set_state("reconnecting", "↻", Localization.tr_key("status.reconnecting") + " " + str(attempt) + "/" + str(max_attempts))


func _on_lobby_updated(roster: Variant) -> void:
	# استخراج حالة player الحالي
	var players: Array = []
	if roster is Array:
		players = roster
	elif roster is Dictionary:
		players = roster.get("players", [])

	var me = NetworkClient.get_player_uid()
	var player = null
	if players:
		player = players.find(func(p): return p.get("uid") == me)
	# ملاحظة: players قد لا يكون dictionary مع uid لكل عنصر
	# البحث البديل:
	if not player:
		for p in players:
			if p.get("uid", null) == me:
				player = p
				break

	if player:
		_set_ready(player.get("isReady", false))
		var tl = player.get("timeline", "")
		_set_timeline(tl)


func _on_match_started(_match_id: String, initial_state: Dictionary) -> void:
	_set_state("connected", "▶", Localization.tr_key("status.match_running"))
	if initial_state.has("you"):
		_set_timeline(initial_state.you.get("timeline", ""))


func _on_echo_propagated(echo_id: String, _loc_key: String, _audio: String, _visual: String, deltas: Array) -> void:
	if deltas.is_empty():
		return
	var delta = deltas[0]
	var from_tl = delta.get("source_timeline", current_timeline)
	var to_tl = delta.get("timeline", "")
	if from_tl and to_tl and from_tl != to_tl:
		_set_echo_direction(Localization.tr_key("echo.from_to") % [
			_get_glyph(from_tl),
			_get_glyph(to_tl),
			Localization.tr_key("timeline." + from_tl),
			Localization.tr_key("timeline." + to_tl),
		])
		last_echo_clear_time = Time.get_ticks_msec() / 1000.0


func _get_glyph(timeline: String) -> String:
	match timeline:
		"past": return "◆"
		"present": return "▲"
		"future": return "●"
	return "?"

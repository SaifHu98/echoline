class_name GameHUD
extends Control

# In-Game Mobile & Desktop HUD

@onready var stability_bar: ProgressBar = $TopBar/StabilityBar
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var stage_label: Label = $TopBar/StageLabel
@onready var timeline_badge: Label = $TopBar/TimelineBadge
@onready var interact_btn: Button = $BottomBar/InteractButton
@onready var quick_chat_btn: Button = $BottomBar/QuickChatButton
@onready var ping_btn: Button = $BottomBar/PingButton
@onready var subtitle_label: Label = $SubtitleContainer/SubtitleLabel
@onready var message_feed: VBoxContainer = $MessageFeed

var current_interactable_echo: String = ""

func _ready() -> void:
	if EventBus.has_signal("catastrophe_updated"):
		EventBus.catastrophe_updated.connect(_on_catastrophe_updated)
	if EventBus.has_signal("subtitle_requested"):
		EventBus.subtitle_requested.connect(_on_subtitle_requested)
	if EventBus.has_signal("quick_message_received"):
		EventBus.quick_message_received.connect(_on_quick_msg_received)
	if EventBus.has_signal("match_state_updated"):
		EventBus.match_state_updated.connect(_on_match_state)
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)
	if EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	# Connect buttons safely
	_connect_button_safely(interact_btn, _on_interact_pressed)
	_connect_button_safely(quick_chat_btn, _on_quick_chat_pressed)
	_connect_button_safely(ping_btn, _on_ping_pressed)

	_apply_localized_texts()
	update_timeline_badge()


func _connect_button_safely(btn: Button, callback: Callable) -> void:
	if btn == null or not is_instance_valid(btn):
		return
	if not btn.pressed.is_connected(callback):
		btn.pressed.connect(callback)


func _apply_localized_texts() -> void:
	var loc = get_node_or_null("/root/Localization")
	if loc == null or not loc.has_method("t"):
		return
	if interact_btn:
		interact_btn.text = loc.t("hud.interact")
	if quick_chat_btn:
		quick_chat_btn.text = loc.t("hud.quick_chat")
	if ping_btn:
		ping_btn.text = loc.t("hud.ping")


func _on_locale_changed(_new_locale: String, _is_rtl: bool) -> void:
	_apply_localized_texts()
	update_timeline_badge()


func update_timeline_badge() -> void:
	if not timeline_badge:
		return
	var tl = NetworkClient.my_timeline if NetworkClient.my_timeline != "" else "past"
	timeline_badge.text = "◆ " + tl.to_upper()
	var colors = {"past": Color("#D4AF37"), "present": Color("#4FC3F7"), "future": Color("#B388FF")}
	timeline_badge.modulate = colors.get(tl, Color.WHITE)


func _on_match_state(state: Dictionary) -> void:
	var you = state.get("you", {})
	if you:
		NetworkClient.my_timeline = you.get("timeline", NetworkClient.my_timeline)
		update_timeline_badge()
	var sys = state.get("state", {}).get("system", {})
	if sys:
		var ms = int(sys.get("catastrophe_timer_ms", 0))
		var stability = float(sys.get("stability", 0))
		var stage = sys.get("current_stage", "stable")
		EventBus.catastrophe_updated.emit(ms, stability, stage)


func _on_catastrophe_updated(remaining_ms: int, stability_pct: float, stage: String) -> void:
	if timer_label:
		var sec = int(remaining_ms / 1000.0)
		var m = int(sec / 60)
		var s = sec % 60
		timer_label.text = "%02d:%02d" % [m, s]
	if stage_label:
		stage_label.text = stage.to_upper()
	if stability_bar:
		stability_bar.value = stability_pct
		if stability_pct > 60:
			stability_bar.modulate = Color.GREEN
		elif stability_pct > 30:
			stability_bar.modulate = Color.ORANGE
		else:
			stability_bar.modulate = Color.RED


func _on_echo_propagated(echo_id: String, loc_key: String, _audio: String, _visual: String, _deltas: Array) -> void:
	_post_feed_message("[ECHO] " + loc_key, Color("#00E5FF"))


func _on_quick_msg_received(sender_tl: String, intent_id: String, _args: Dictionary) -> void:
	_post_feed_message("💬 [" + sender_tl + "]: " + intent_id, Color("#00E5FF"))


func _on_subtitle_requested(text: String, duration_sec: float) -> void:
	if not subtitle_label:
		return
	subtitle_label.text = text
	subtitle_label.visible = true
	get_tree().create_timer(duration_sec).timeout.connect(func():
		if subtitle_label.text == text:
			subtitle_label.visible = false
	)


func _post_feed_message(msg: String, col: Color) -> void:
	if not message_feed:
		return
	var lbl = Label.new()
	lbl.text = msg
	lbl.modulate = col
	lbl.add_theme_font_size_override("font_size", 18)
	message_feed.add_child(lbl)
	if message_feed.get_child_count() > 6:
		message_feed.get_child(0).queue_free()
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _on_interact_pressed() -> void:
	var tl = NetworkClient.my_timeline if NetworkClient.my_timeline != "" else "past"
	var entities = []
	if tl == "past":
		entities = [
			{"id": "canal_debris", "action": "clear_debris"},
			{"id": "courtyard_soil", "action": "plant_seed"},
			{"id": "canal_sluice_gate", "action": "open_sluice_gate"},
			{"id": "builder_archive_tablet", "action": "carve_tablet"},
		]
	elif tl == "present":
		entities = [
			{"id": "courtyard_tree", "action": "prune_branches"},
			{"id": "clock_gear_mechanism", "action": "insert_gear"},
			{"id": "archive_manuscript", "action": "restore_manuscript"},
		]
	elif tl == "future":
		entities = [
			{"id": "temporal_gate_console", "action": "tune_frequency"},
			{"id": "gate_stabilizer_unit", "action": "activate_stabilizer"},
		]
	if entities.is_empty():
		return
	var idx = int(Time.get_ticks_msec() / 3000) % entities.size()
	var e = entities[idx]
	NetworkClient.send_interaction(e.id, e.action, func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("✓ " + str(e.id), 2.0)
		else:
			EventBus.subtitle_requested.emit("✗ Failed", 2.0)
	)


func _on_quick_chat_pressed() -> void:
	NetworkClient.send_quick_message("ack")
	EventBus.subtitle_requested.emit("💬 Sent: ack", 1.5)


func _on_ping_pressed() -> void:
	NetworkClient.send_ping("location", "manual", Vector2(0.5, 0.5))
	EventBus.subtitle_requested.emit("📍 Ping sent", 1.5)

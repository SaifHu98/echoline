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
@onready var message_feed: VBoxContainer = $MessageFeed/FeedContainer
@onready var ping_wheel: SmartPingWheel = $SmartPingWheel
@onready var quick_chat_menu: QuickChatMenu = $QuickChatMenu

var current_interactable_echo: String = ""

func _ready() -> void:
	EventBus.catastrophe_updated.connect(_on_catastrophe_updated)
	EventBus.echo_propagated.connect(_on_echo_propagated)
	EventBus.quick_message_received.connect(_on_quick_msg_received)
	EventBus.ping_received.connect(_on_ping_received)
	EventBus.subtitle_requested.connect(_on_subtitle_requested)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.match_state_updated.connect(_on_match_state)
	EventBus.match_concluded.connect(_on_match_concluded)

	if interact_btn:
		interact_btn.pressed.connect(_on_interact_pressed)
	if quick_chat_btn:
		quick_chat_btn.pressed.connect(func(): quick_chat_menu.visible = !quick_chat_menu.visible)
	if ping_btn:
		ping_btn.pressed.connect(func(): ping_wheel.open_at(get_viewport_rect().size / 2.0))
	if ping_wheel:
		ping_wheel.ping_selected.connect(func(ping_id): NetworkClient.send_ping(ping_id, 0, 0, ""))

	update_timeline_badge()


func update_timeline_badge() -> void:
	if not timeline_badge:
		return
	var tl = NetworkClient.my_timeline if NetworkClient.my_timeline else "past"
	timeline_badge.text = "◆ " + Localization.tr_key("timeline." + tl)
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
		timer_label.text = Localization.tr_key("catastrophe.timer", { "seconds": sec })
	if stage_label:
		stage_label.text = Localization.tr_key("catastrophe.stage." + stage)
	if stability_bar:
		stability_bar.value = stability_pct
		if stability_pct > 60:
			stability_bar.modulate = Color.GREEN
		elif stability_pct > 30:
			stability_bar.modulate = Color.ORANGE
		else:
			stability_bar.modulate = Color.RED


func _on_echo_propagated(echo_id: String, loc_key: String, _audio: String, _visual: String, _deltas: Array) -> void:
	var desc = Localization.tr_key(loc_key)
	_post_feed_message("[ECHO] " + desc, Color("#00E5FF"))


func _on_quick_msg_received(sender_tl: String, intent_id: String, args: Dictionary) -> void:
	var text = intent_id
	for q in quick_chat_menu.quick_intents:
		if q.get("id") == intent_id:
			text = Localization.tr_key(q.get("loc_key", intent_id), args)
			break
	_post_feed_message("💬 " + text, Color("#00E5FF"))


func _on_ping_received(sender_tl: String, ping_id: String, _pos: Vector2) -> void:
	_post_feed_message("📍 [PING: " + ping_id + "]", Color.YELLOW)


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
	message_feed.add_child(lbl)
	if message_feed.get_child_count() > 6:
		message_feed.get_child(0).queue_free()
	get_tree().create_timer(8.0).timeout.connect(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


func _on_interact_pressed() -> void:
	# Cycle through available echoes based on player timeline
	var tl = NetworkClient.my_timeline
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
			{"id": "temporal_gate_console", "action": "submit_code"},
			{"id": "gate_stabilizer_unit", "action": "activate_stabilizer"},
		]
	if entities.is_empty():
		return
	var idx = int(Time.get_ticks_msec() / 3000) % entities.size()
	var e = entities[idx]
	NetworkClient.send_interaction(e.id, e.action, func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("✓ " + Localization.t("echo." + e.id), 2.0)
		else:
			EventBus.subtitle_requested.emit("✗ " + str(ack.get("error", "")), 2.0)
	)


func _on_match_concluded(_recap: Dictionary) -> void:
	# Transition handled by main.gd
	pass


func _on_locale_changed(_loc: String, _is_rtl: boolean) -> void:
	update_timeline_badge()

class_name QuickChatMenu
extends RTLPanel

# Localized Quick Message Intent Selector

var quick_intents = [
	{ "id": "MSG_WATER_NEED_FLOW", "loc_key": "quickmsg.water_need_flow" },
	{ "id": "MSG_WATER_STOP_FLOW", "loc_key": "quickmsg.water_stop_flow" },
	{ "id": "MSG_FOUND_HISTORICAL_CODE", "loc_key": "quickmsg.found_historical_code", "params": {"code": "CHRONOS_77"} },
	{ "id": "MSG_TURBINE_POWER_READY", "loc_key": "quickmsg.turbine_power_ready" },
	{ "id": "MSG_DO_NOT_DESTROY", "loc_key": "quickmsg.do_not_destroy" },
	{ "id": "MSG_PLANT_IN_COURTYARD", "loc_key": "quickmsg.plant_in_courtyard" },
	{ "id": "MSG_WAIT_FOR_SYNC", "loc_key": "quickmsg.wait_for_sync" },
	{ "id": "MSG_GATE_DESTABILIZING", "loc_key": "quickmsg.gate_destabilizing" },
	{ "id": "MSG_NEED_PRESENT_REPAIR", "loc_key": "quickmsg.need_present_repair" },
	{ "id": "MSG_BRIDGE_ACCESSIBLE", "loc_key": "quickmsg.bridge_accessible" }
]

func _ready() -> void:
	super._ready()
	_rebuild_list()
	EventBus.locale_changed.connect(func(_loc, _rtl): _rebuild_list())

func _rebuild_list() -> void:
	for child in get_children():
		child.queue_free()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 220)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for item in quick_intents:
		var btn = Button.new()
		var params = item.get("params", {})
		btn.text = Localization.tr_key(item["loc_key"], params)
		btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT if Localization.is_rtl else HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func():
			NetworkClient.send_quick_message(item["id"], params)
			visible = false
		)
		vbox.add_child(btn)

	scroll.add_child(vbox)
	add_child(scroll)

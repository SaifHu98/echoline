class_name BuildingScene
extends Control

signal build_started(blueprint_id: String, anchor_id: String)
signal build_progress(anchor_id: String, progress: float)
signal build_completed(anchor_id: String, effects: Dictionary)
signal build_canceled(anchor_id: String)

const ShardInventoryBarScript := preload("res://ui/hud/shard_inventory_bar.gd")
const AnchorBlueprintPanelScript := preload("res://ui/hud/anchor_blueprint_panel.gd")

@export var network_client: Node
@export var player_index: int = 0
@export var default_language: String = "en"

@onready var _shard_bar: ShardInventoryBarScript
@onready var _blueprint_panel: AnchorBlueprintPanelScript
@onready var _progress_label: Label
@onready var _info_label: Label

var _inventory: ShardInventory
var _catalog: Dictionary = {}
var _blueprints: Dictionary = {}
var _current_anchor: Dictionary = {}
var _current_blueprint: String = ""
var _controller: AnchorPlacementController

func _ready() -> void:
	_inventory = ShardInventory.new()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_layout()
	_controller = AnchorPlacementController.new()
	_controller.player_index = player_index
	_controller.setup({}, _inventory, {}, [])
	_bind_network_signals()

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var top: HBoxContainer = HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 16
	top.offset_bottom = 60
	top.add_theme_constant_override("separation", 16)
	add_child(top)
	_info_label = Label.new()
	_info_label.text = "Build Mode — pick a blueprint from the right panel."
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(_info_label)
	_progress_label = Label.new()
	_progress_label.text = "Progress: --"
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
	top.add_child(_progress_label)
	_blueprint_panel = AnchorBlueprintPanelScript.new()
	_blueprint_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_blueprint_panel.offset_top = 80
	_blueprint_panel.offset_bottom = -140
	_blueprint_panel.offset_left = -300
	_blueprint_panel.offset_right = -16
	add_child(_blueprint_panel)
	_blueprint_panel.start_blueprint.connect(_on_start_blueprint)
	_blueprint_panel.cancel_blueprint.connect(_on_cancel_blueprint)
	_shard_bar = ShardInventoryBarScript.new()
	_shard_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_shard_bar.offset_left = 16
	_shard_bar.offset_right = -320
	_shard_bar.offset_top = -130
	_shard_bar.offset_bottom = -16
	add_child(_shard_bar)
	_shard_bar.shard_selected.connect(_on_shard_selected)

func load_catalogs(catalog: Dictionary, blueprints: Dictionary, language: String = "en") -> void:
	_catalog = catalog
	_blueprints = blueprints
	default_language = language
	_shard_bar.setup(catalog, language)
	_blueprint_panel.set_blueprints(blueprints, language)

func load_inventory(inventory_data: Dictionary) -> void:
	_inventory.setup(_catalog)
	_inventory.load_from(inventory_data)
	_shard_bar.update_inventory(_inventory.snapshot())

func _on_start_blueprint(blueprint_id: String) -> void:
	if not _blueprints.has("anchors") or not _blueprints.anchors.has(blueprint_id):
		push_error("BuildingScene: unknown blueprint %s" % blueprint_id)
		return
	var bp: Dictionary = _blueprints.anchors[blueprint_id]
	var players: Array = []
	for i in range(int(bp.get("max_players", 4))):
		players.append({"id": "player_%d" % i, "name": "P%d" % i, "timeline": "neutral"})
	var payload: Dictionary = {
		"type": "create_anchor",
		"blueprint_id": blueprint_id,
		"players": players
	}
	if network_client:
		network_client.emit("anchor_create", payload)
	_current_blueprint = blueprint_id
	_info_label.text = "Build started: %s" % blueprint_id

func _on_cancel_blueprint(blueprint_id: String) -> void:
	if network_client:
		network_client.emit("anchor_cancel", {"blueprint_id": blueprint_id})
	_current_blueprint = ""
	_info_label.text = "Build canceled."
	_current_anchor = {}

func _on_shard_selected(shard_id: String) -> void:
	if _current_anchor.is_empty():
		_info_label.text = "Pick a blueprint first."
		return
	var slot_index: int = _find_preferred_slot_for_shard(shard_id)
	if slot_index < 0:
		_info_label.text = "No slot accepts %s." % shard_id
		return
	var owner_id: String = "player_%d" % player_index
	if network_client:
		network_client.emit("anchor_event", _current_anchor.get("anchor_id", ""), {
			"type": "place_shard",
			"slot_index": slot_index,
			"shard_id": shard_id,
			"player_id": owner_id,
			"player_index": player_index
		})

func _find_preferred_slot_for_shard(shard_id: String) -> int:
	if not _current_anchor.has("slots"):
		return -1
	var slots: Array = _current_anchor.slots
	for i in range(slots.size()):
		if slots[i].state == "filled":
			continue
		var slot_def: Dictionary = _blueprints.anchors[_current_blueprint].slots[i]
		var valid: Array = slot_def.get("valid_shards", [])
		if valid.has(shard_id):
			return i
	return -1

func apply_server_state(anchor_state: Dictionary) -> void:
	_current_anchor = anchor_state
	if anchor_state.has("slots"):
		var inv: Dictionary = {}
		for slot in anchor_state.slots:
			if slot.state == "filled":
				var id: String = slot.placed_shard
				inv[id] = inv.get(id, 0) + 1
		_shard_bar.update_inventory(_inventory.snapshot())
	if anchor_state.has("progress"):
		_progress_label.text = "Progress: %d%%" % int(anchor_state.progress * 100)
		build_progress.emit(anchor_state.get("anchor_id", ""), anchor_state.progress)
	if anchor_state.get("state") == "complete":
		_info_label.text = "Anchor complete!"
		build_completed.emit(anchor_state.get("anchor_id", ""), {})

func _bind_network_signals() -> void:
	if network_client == null:
		return
	if network_client.has_signal("anchor_state_received"):
		network_client.anchor_state_received.connect(_on_server_state_received)
	if network_client.has_signal("build_error"):
		network_client.build_error.connect(_on_build_error)

func _on_server_state_received(server_slots: Array, server_seq: int, anchor_id: String = "") -> void:
	apply_server_state({"slots": server_slots, "place_seq": server_seq, "anchor_id": anchor_id})

func _on_build_error(reason: String) -> void:
	_info_label.text = "Build error: %s" % reason
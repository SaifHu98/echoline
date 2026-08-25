class_name ChronoCodexView
extends RTLPanel

# Interactive Chrono Codex & Lore Archive for ECHO//LINE (أصداء)

@onready var entry_list: VBoxContainer = $VBox/HSplit/EntriesList
@onready var entry_title: Label = $VBox/HSplit/Content/TitleLabel
@onready var entry_body: RichTextLabel = $VBox/HSplit/Content/BodyText
@onready var close_btn: Button = $VBox/CloseButton

var codex_entries: Array[Dictionary] = [
	{
		"id": "codex_great_divergence",
		"title_key": "codex.divergence.title",
		"body_key": "codex.divergence.body",
		"is_unlocked": true
	},
	{
		"id": "codex_clocktower_origin",
		"title_key": "codex.clocktower.title",
		"body_key": "codex.clocktower.body",
		"is_unlocked": true
	},
	{
		"id": "codex_subterranean_vaults",
		"title_key": "codex.vaults.title",
		"body_key": "codex.vaults.body",
		"is_unlocked": true
	},
	{
		"id": "codex_temporal_harmonics",
		"title_key": "codex.harmonics.title",
		"body_key": "codex.harmonics.body",
		"is_unlocked": true
	}
]

func _ready() -> void:
	super._ready()
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)
	visible = false
	_populate_entries()

func _populate_entries() -> void:
	for child in entry_list.get_children():
		child.queue_free()

	for entry in codex_entries:
		var btn = RTLButton.new()
		btn.text = Localization.tr_key(entry.get("title_key", ""))
		btn.pressed.connect(func(): _display_entry(entry))
		entry_list.add_child(btn)

	if not codex_entries.is_empty():
		_display_entry(codex_entries[0])

func _display_entry(entry: Dictionary) -> void:
	if entry_title:
		entry_title.text = Localization.tr_key(entry.get("title_key", ""))
	if entry_body:
		entry_body.text = Localization.tr_key(entry.get("body_key", ""))

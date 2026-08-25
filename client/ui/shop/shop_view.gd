class_name InGameShopView
extends Control

# RTL-Aware In-Game Shop & Cosmetic Wardrobe

@onready var tabs_container: HBoxContainer = $Panel/VBox/TabsContainer
@onready var items_grid: GridContainer = $Panel/VBox/Scroll/ItemsGrid
@onready var close_btn: Button = $Panel/VBox/CloseButton
@onready var shards_label: Label = $Panel/VBox/WalletBar/ShardsLabel
@onready var flux_label: Label = $Panel/VBox/WalletBar/FluxLabel

var shop_catalog: Dictionary = {}
var user_flux: int = 1500
var user_shards: int = 250

func _ready() -> void:
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)
	visible = false
	_load_catalog()

func _load_catalog() -> void:
	# Load from shared catalog or server REST endpoint
	var p = "res://../shared/shop_catalog.json"
	if FileAccess.file_exists(p):
		var f = FileAccess.open(p, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			shop_catalog = parsed
			_render_shop_items("all")

func _render_shop_items(category_filter: String) -> void:
	for child in items_grid.get_children():
		child.queue_free()

	var items = shop_catalog.get("items", [])
	for item in items:
		if category_filter != "all" and item.get("category_id") != category_filter:
			continue

		var item_card = PanelContainer.new()
		var vbox = VBoxContainer.new()

		var title = Label.new()
		title.text = Localization.tr_key(item.get("title_key", ""))
		vbox.add_child(title)

		var buy_btn = RTLButton.new()
		var price = item.get("price", {})
		var sku = item.get("google_play_sku")

		if sku != null:
			buy_btn.text = "$" + str(price.get("amount", 0)) + " USD"
			buy_btn.pressed.connect(func(): IAPManager.buy_google_play_sku(sku))
		else:
			var curr = price.get("currency", "")
			buy_btn.text = str(price.get("amount", 0)) + " " + curr
			buy_btn.pressed.connect(func(): _buy_soft_item(item))

		vbox.add_child(buy_btn)
		item_card.add_child(vbox)
		items_grid.add_child(item_card)

func _buy_soft_item(item: Dictionary) -> void:
	var price = item.get("price", {})
	var amount = price.get("amount", 0)
	var curr = price.get("currency", "")

	if curr == "chrono_flux" and user_flux >= amount:
		user_flux -= amount
		_update_wallet_labels()
	elif curr == "chrono_shards" and user_shards >= amount:
		user_shards -= amount
		_update_wallet_labels()

func _update_wallet_labels() -> void:
	if shards_label: shards_label.text = "◆ " + str(user_shards)
	if flux_label: flux_label.text = "● " + str(user_flux)

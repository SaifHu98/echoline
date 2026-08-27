extends Node

# Google Play In-App Purchase & Billing Gateway Integration

signal purchase_completed(item_id: String, grant_contents: Dictionary)
signal purchase_failed(error_message: String)

var payment_plugin = null
var is_billing_ready: bool = false

func _ready() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		payment_plugin = Engine.get_singleton("GodotGooglePlayBilling")
		# P1-5: Guard against the singleton being registered but null (some
		# builds expose the name without an instance). Without this check the
		# subsequent `connect` calls would crash on the first purchase.
		if payment_plugin != null:
			if payment_plugin.has_signal("connected"):
				payment_plugin.connected.connect(_on_billing_connected)
			if payment_plugin.has_signal("purchase_success"):
				payment_plugin.purchase_success.connect(_on_google_purchase_success)
			if payment_plugin.has_signal("purchase_error"):
				payment_plugin.purchase_error.connect(_on_google_purchase_error)
			if payment_plugin.has_method("start_connection"):
				payment_plugin.start_connection()
		else:
			# Plugin name registered but no instance; treat as mock.
			is_billing_ready = true
	else:
		# Development mock billing active
		is_billing_ready = true

func _on_billing_connected() -> void:
	is_billing_ready = true

func buy_google_play_sku(sku_id: String) -> void:
	if payment_plugin:
		payment_plugin.purchase(sku_id)
	else:
		# Simulate server-side verification in development
		var mock_receipt = {
			"orderId": "GPA." + str(Time.get_ticks_msec()),
			"packageName": "com.ecouni.echoline",
			"productId": sku_id,
			"purchaseState": 0,
			"purchaseToken": "mock_token_" + str(Time.get_unix_time_from_system())
		}
		_verify_receipt_on_server(mock_receipt)

func _on_google_purchase_success(purchase_token: String, sku: String, order_id: String) -> void:
	var receipt = {
		"orderId": order_id,
		"packageName": "com.ecouni.echoline",
		"productId": sku,
		"purchaseState": 0,
		"purchaseToken": purchase_token
	}
	_verify_receipt_on_server(receipt)

func _on_google_purchase_error(code: int, message: String) -> void:
	purchase_failed.emit("Google Play Billing Error (" + str(code) + "): " + message)

func _verify_receipt_on_server(receipt: Dictionary) -> void:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		http_request.queue_free()
		if response_code == 200:
			var json = JSON.parse_string(body.get_string_from_utf8())
			if json is Dictionary and json.get("success", false):
				purchase_completed.emit(receipt.get("productId", ""), json.get("grant", {}))
			else:
				purchase_failed.emit("Receipt verification rejected by authoritative server.")
		else:
			purchase_failed.emit("Network error verifying purchase receipt.")
	)
	var payload = JSON.stringify(receipt)
	http_request.request("http://localhost:7778/api/billing/google-play/verify", ["Content-Type: application/json"], HTTPClient.METHOD_POST, payload)


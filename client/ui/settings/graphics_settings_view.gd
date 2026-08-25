class_name GraphicsSettingsView
extends RTLPanel

# Mobile Graphics, Frame Rate (FPS), and Visual Quality Settings Panel

@onready var fps_options: OptionButton = $VBox/FPSRow/OptionButton
@onready var battery_saver_check: CheckBox = $VBox/BatterySaverCheck
@onready var res_slider: HSlider = $VBox/ResRow/Slider
@onready var res_label: Label = $VBox/ResRow/ValueLabel
@onready var shadow_options: OptionButton = $VBox/ShadowRow/OptionButton
@onready var bloom_check: CheckBox = $VBox/BloomCheck
@onready var msaa_options: OptionButton = $VBox/MSAARow/OptionButton
@onready var live_fps_label: Label = $VBox/PerformanceTelemetry/LiveFPSLabel

func _ready() -> void:
	super._ready()
	_setup_ui_options()
	_update_localized_texts()
	EventBus.locale_changed.connect(func(_l, _r): _update_localized_texts())

func _process(_delta: float) -> void:
	if visible and live_fps_label:
		var current_fps = Engine.get_frames_per_second()
		var frame_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		live_fps_label.text = Localization.tr_key("graphics.live_telemetry", {
			"fps": str(current_fps),
			"ms": "%.1f" % frame_time
		})

func _setup_ui_options() -> void:
	# FPS options
	if fps_options:
		fps_options.clear()
		fps_options.add_item("30 FPS (Battery Saver / توفير البطارية)", 0)
		fps_options.add_item("60 FPS (Balanced Smooth / متوازن سلس)", 1)
		fps_options.add_item("90 FPS (High Refresh / معدل تحديث عالي)", 2)
		fps_options.add_item("120 FPS (Ultra / ألترا فائق)", 3)
		fps_options.item_selected.connect(_on_fps_selected)

	# Battery Saver
	if battery_saver_check:
		battery_saver_check.toggled.connect(func(val):
			GraphicsManager.set_battery_saver_mode(val)
			_sync_ui_with_manager()
		)

	# Resolution Scaling
	if res_slider:
		res_slider.min_value = 50.0
		res_slider.max_value = 100.0
		res_slider.value = GraphicsManager.resolution_scale * 100.0
		res_slider.value_changed.connect(func(val):
			GraphicsManager.set_resolution_scale(val / 100.0)
			res_label.text = str(int(val)) + "%"
		)

	# Shadows
	if shadow_options:
		shadow_options.clear()
		shadow_options.add_item("Off (معطل)", 0)
		shadow_options.add_item("Low 512 (منخفض)", 1)
		shadow_options.add_item("Medium 1024 (متوسط)", 2)
		shadow_options.add_item("High 2048 (عالي)", 3)
		shadow_options.item_selected.connect(_on_shadow_selected)

	# Bloom
	if bloom_check:
		bloom_check.toggled.connect(func(val): GraphicsManager.set_bloom(val))

	# MSAA
	if msaa_options:
		msaa_options.clear()
		msaa_options.add_item("Off (معطل)", 0)
		msaa_options.add_item("2X MSAA", 1)
		msaa_options.add_item("4X MSAA", 2)
		msaa_options.item_selected.connect(func(idx): GraphicsManager.set_msaa(idx))

	_sync_ui_with_manager()

func _on_fps_selected(index: int) -> void:
	match index:
		0: GraphicsManager.set_target_fps(30)
		1: GraphicsManager.set_target_fps(60)
		2: GraphicsManager.set_target_fps(90)
		3: GraphicsManager.set_target_fps(120)

func _on_shadow_selected(index: int) -> void:
	match index:
		0: GraphicsManager.set_shadow_quality(0)
		1: GraphicsManager.set_shadow_quality(512)
		2: GraphicsManager.set_shadow_quality(1024)
		3: GraphicsManager.set_shadow_quality(2048)

func _sync_ui_with_manager() -> void:
	if battery_saver_check:
		battery_saver_check.button_pressed = GraphicsManager.battery_saver_active
	if bloom_check:
		bloom_check.button_pressed = GraphicsManager.bloom_enabled
	if res_slider:
		res_slider.value = GraphicsManager.resolution_scale * 100.0
	if res_label:
		res_label.text = str(int(GraphicsManager.resolution_scale * 100.0)) + "%"

func _update_localized_texts() -> void:
	if battery_saver_check: battery_saver_check.text = Localization.tr_key("graphics.battery_saver")
	if bloom_check: bloom_check.text = Localization.tr_key("graphics.bloom_glow")

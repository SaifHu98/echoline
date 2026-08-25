extends Control

# ECHO//LINE — Onboarding (Playable Tutorial)
# ============================================
# بدلاً من نصوص طويلة، نتعلم باللعب:
#
# Step 1: تحية + اختيار اللغة (شاشة رئيسية)
# Step 2: حجرة تجريبية صغيرة — حرّك الشخصية
# Step 3: تفاعل مع prop واحد — اعرف الـ echo
# Step 4: ربط الخطّين — شوف ripple ينتقل
# Step 5: تجربة كاملة — 60 ثانية في سيناريو مبسط
#
# كل خطوة تظهر "لمسة" واحدة فقط ثم تُنفّذ عملياً.

signal onboarding_completed

@onready var title_label: Label = $Root/Title
@onready var subtitle_label: Label = $Root/Subtitle
@onready var step_label: Label = $Root/StepLabel
@onready var next_btn: Button = $Root/NextButton
@onready var skip_btn: Button = $Root/SkipButton
@onready var progress_bar: ProgressBar = $Root/ProgressBar
@onready var play_area: Control = $Root/PlayArea
@onready var hint_bubble: Control = $Root/HintBubble
@onready var hint_label: Label = $Root/HintBubble/HintLabel

enum Step {
	LANGUAGE_SELECTION = 0,
	FIRST_LOCOMOTION = 1,
	FIRST_INTERACTION = 2,
	FIRST_ECHO = 3,
	MICRO_SCENARIO = 4,
}

var current_step: int = Step.LANGUAGE_SELECTION
var total_steps: int = 5
var demo_prop: Control = null
var demo_target: Control = null
var demo_origin_pos: Vector2
var demo_target_pos: Vector2
var micro_timer: float = 0.0


func _ready() -> void:
	if UXTelemetry.training_started_at == 0 and not UXTelemetry.training_completed:
		UXTelemetry.training_started(total_steps)
	_apply_texts()
	_setup_step()
	_connect_buttons()


func _connect_buttons() -> void:
	if next_btn:
		next_btn.pressed.connect(_on_next_pressed)
	if skip_btn:
		skip_btn.pressed.connect(_on_skip_pressed)


func _apply_texts() -> void:
	if title_label:
		title_label.text = Localization.tr_key("onboarding.welcome_title")
	if subtitle_label:
		subtitle_label.text = Localization.tr_key("onboarding.welcome_subtitle")
	if next_btn:
		next_btn.text = Localization.tr_key("onboarding.next")
	if skip_btn:
		skip_btn.text = Localization.tr_key("onboarding.skip_to_menu")

	# Touch targets
	if next_btn: TouchTargetValidator.ensure_size(next_btn)
	if skip_btn: TouchTargetValidator.ensure_size(skip_btn)


func _setup_step() -> void:
	# ابدأ بخطوة اللغة
	_show_step(LOCALIZATION_STEP_TITLE, LOCALIZATION_STEP_HINT)
	_show_language_picker()


const LOCALIZATION_STEP_TITLE = "step_lang_title"
const LOCALIZATION_STEP_HINT = "step_lang_hint"


func _show_step(title_key: String, hint_key: String) -> void:
	if title_label:
		title_label.text = Localization.tr_key(title_key)
	if step_label:
		step_label.text = Localization.tr_key(hint_key)
	if progress_bar:
		progress_bar.value = (current_step + 1) * 100.0 / total_steps


func _on_next_pressed() -> void:
	current_step += 1
	UXTelemetry.training_step_completed(current_step - 1)
	if current_step >= total_steps:
		_finish_onboarding()
		return
	_advance_to_step()


func _on_skip_pressed() -> void:
	# Skip to menu — not finish onboarding
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _finish_onboarding() -> void:
	UXTelemetry.training_finished(true)
	UXTelemetry.save_to_disk()
	onboarding_completed.emit()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _advance_to_step() -> void:
	match current_step:
		Step.FIRST_LOCOMOTION:
			_show_step("step_move_title", "step_move_hint")
			_show_locomotion_demo()
		Step.FIRST_INTERACTION:
			_show_step("step_interact_title", "step_interact_hint")
			_show_interaction_demo()
		Step.FIRST_ECHO:
			_show_step("step_echo_title", "step_echo_hint")
			_show_echo_demo()
		Step.MICRO_SCENARIO:
			_show_step("step_scenario_title", "step_scenario_hint")
			_show_micro_scenario()


# ============================================
# Step 0: Language selection
# ============================================

func _show_language_picker() -> void:
	_clear_play_area()

	var container = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 16)
	play_area.add_child(container)

	for lang_data in [
		{"id": "en", "name": "English"},
		{"id": "ar", "name": "العربية"},
		{"id": "qps_mirrored", "name": "Pseudo-Mirrored RTL"},
	]:
		var btn = Button.new()
		btn.text = lang_data.name
		btn.custom_minimum_size = Vector2(200, 80)
		TouchTargetValidator.ensure_size(btn, true)
		btn.pressed.connect(_on_language_chosen.bind(lang_data.id))
		container.add_child(btn)


func _on_language_chosen(lang_id: String) -> void:
	var is_rtl = lang_id == "ar" or lang_id == "qps_mirrored"
	Localization.set_locale(lang_id)
	Accessibility.set_locale(lang_id, is_rtl)
	_apply_texts()
	# Auto-advance after language is chosen
	get_tree().create_timer(0.5).timeout.connect(_on_next_pressed)


# ============================================
# Step 1: First locomotion
# ============================================

func _show_locomotion_demo() -> void:
	_clear_play_area()

	var demo_dot = ColorRect.new()
	demo_dot.color = Color("#4FC3F7")
	demo_dot.custom_minimum_size = Vector2(60, 60)
	demo_dot.position = Vector2(100, 200)
	demo_dot.size = Vector2(60, 60)
	play_area.add_child(demo_dot)

	var target_dot = ColorRect.new()
	target_dot.color = Color("#D4AF37")
	target_dot.custom_minimum_size = Vector2(80, 80)
	target_dot.position = Vector2(500, 200)
	target_dot.size = Vector2(80, 80)
	play_area.add_child(target_dot)

	# Simulate movement with tween
	var t = create_tween()
	t.tween_property(demo_dot, "position", Vector2(460, 200), 1.5)

	# When demo completes, allow next
	t.tween_callback(_on_demo_finished)


func _on_demo_finished() -> void:
	_show_hint_pulse(Localization.tr_key("step_move_done"))


# ============================================
# Step 2: First interaction
# ============================================

func _show_interaction_demo() -> void:
	_clear_play_area()

	# Create an interactive prop demo
	var prop = Button.new()
	prop.text = Localization.tr_key("demo.interact_button")
	prop.custom_minimum_size = Vector2(220, 96)
	TouchTargetValidator.ensure_size(prop, true)
	prop.position = Vector2(280, 180)
	prop.size = Vector2(220, 96)
	prop.pressed.connect(_on_demo_prop_clicked)
	play_area.add_child(prop)
	demo_prop = prop


func _on_demo_prop_clicked() -> void:
	if demo_prop:
		demo_prop.disabled = true
		demo_prop.modulate = Color(0.5, 1, 0.5, 1)
	_show_hint_pulse(Localization.tr_key("step_interact_done"))
	UXTelemetry.first_echo_seen("demo.echo")


# ============================================
# Step 3: First Echo
# ============================================

func _show_echo_demo() -> void:
	_clear_play_area()

	# Timeline A prop (Past)
	var origin = Button.new()
	origin.text = "◆ " + Localization.tr_key("demo.past_prop")
	origin.custom_minimum_size = Vector2(200, 80)
	origin.position = Vector2(150, 200)
	origin.size = Vector2(200, 80)
	TouchTargetValidator.ensure_size(origin, true)
	play_area.add_child(origin)

	# Timeline B prop (Future)
	var target = Button.new()
	target.text = "● " + Localization.tr_key("demo.future_prop")
	target.custom_minimum_size = Vector2(200, 80)
	target.position = Vector2(550, 200)
	target.size = Vector2(200, 80)
	TouchTargetValidator.ensure_size(target, true)
	play_area.add_child(target)

	# Ripple animation connecting them
	demo_origin_pos = Vector2(250, 240)
	demo_target_pos = Vector2(650, 240)
	spawn_ripple_demo(demo_origin_pos, demo_target_pos)

	demo_prop = origin
	demo_target = target

	origin.pressed.connect(_on_origin_clicked)


func _on_origin_clicked() -> void:
	spawn_ripple_demo(demo_origin_pos, demo_target_pos)
	if demo_target:
		demo_target.modulate = Color(1, 0.5, 1, 1)
	_show_hint_pulse(Localization.tr_key("step_echo_done"))
	UXTelemetry.first_echo_understood_now()


func spawn_ripple_demo(from: Vector2, to: Vector2) -> void:
	# Create a temporary ripple using tween
	var ripple = ColorRect.new()
	ripple.color = Color(1, 0.84, 0.4, 0.6)
	ripple.custom_minimum_size = Vector2(30, 30)
	ripple.position = from - Vector2(15, 15)
	ripple.size = Vector2(30, 30)
	play_area.add_child(ripple)

	var t = create_tween().set_parallel(true)
	t.tween_property(ripple, "position", to - Vector2(15, 15), 0.8)
	t.tween_property(ripple, "scale", Vector2(2, 2), 0.8)
	t.tween_property(ripple, "modulate:a", 0.0, 0.8)
	get_tree().create_timer(1.0).timeout.connect(func(): ripple.queue_free())


# ============================================
# Step 4: Micro scenario
# ============================================

func _show_micro_scenario() -> void:
	_clear_play_area()

	var label = Label.new()
	label.text = Localization.tr_key("demo.scenario_intro")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	play_area.add_child(label)

	# Simple visual: Past, Present, Future panels
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	hbox.position = Vector2(40, 200)
	hbox.size = Vector2(800, 200)
	play_area.add_child(hbox)

	for tl in [
		{"id": "past", "glyph": "◆", "color": Color("#D4AF37")},
		{"id": "present", "glyph": "▲", "color": Color("#4FC3F7")},
		{"id": "future", "glyph": "●", "color": Color("#B388FF")},
	]:
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(220, 200)
		panel.size = Vector2(220, 200)
		var style = StyleBoxFlat.new()
		style.bg_color = tl.color.darkened(0.7)
		style.border_color = tl.color
		style.set_border_width_all(3)
		style.set_corner_radius_all(16)
		panel.add_theme_stylebox_override("panel", style)

		var lbl = Label.new()
		lbl.text = tl.glyph + "\n" + Localization.tr_key("timeline." + tl.id)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		panel.add_child(lbl)
		hbox.add_child(panel)

	# Schedule auto-finish
	micro_timer = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if current_step == Step.MICRO_SCENARIO:
		micro_timer += delta
		if micro_timer >= 6.0:
			UXTelemetry.scenario_started("tutorial_micro")
			UXTelemetry.scenario_finished(true, "tutorial_micro")
			UXTelemetry.training_step_completed(Step.MICRO_SCENARIO)
			_finish_onboarding()


# ============================================
# Helpers
# ============================================

func _clear_play_area() -> void:
	for child in play_area.get_children():
		child.queue_free()


func _show_hint_pulse(text: String) -> void:
	if hint_label:
		hint_label.text = text
	if hint_bubble:
		hint_bubble.visible = true
		var t = create_tween()
		t.tween_property(hint_bubble, "modulate:a", 1.0, 0.3)
		t.tween_interval(2.5)
		t.tween_property(hint_bubble, "modulate:a", 0.0, 0.5)


# ============================================
# Input handling
# ============================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			# Don't auto-advance on language picker (must choose one)
			if current_step == Step.LANGUAGE_SELECTION:
				return
			_on_next_pressed()
		elif event.keycode == KEY_ESCAPE:
			# Skip on Escape
			_on_skip_pressed()

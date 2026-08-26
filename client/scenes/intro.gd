extends Control

# ECHO//LINE — Cinematic Intro Sequence
# Plays once at game launch, then auto-transitions to Main Menu

@onready var title_label: Label = $Root/TitleStack/TitleLabel
@onready var subtitle_label: Label = $Root/TitleStack/SubtitleLabel
@onready var arabic_label: Label = $Root/TitleStack/ArabicLabel
@onready var logo_container: Control = $Root/LogoContainer
@onready var logo_echo_glow: Control = $Root/LogoContainer/EchoGlow
@onready var logo_past: Control = $Root/LogoContainer/Timelines/PastArc
@onready var logo_present: Control = $Root/LogoContainer/Timelines/PresentArc
@onready var logo_future: Control = $Root/LogoContainer/Timelines/FutureArc
@onready var logo_core: Control = $Root/LogoContainer/CoreDot
@onready var skip_btn: Button = $Root/SkipButton
@onready var progress_bar: ProgressBar = $Root/ProgressBar
@onready var background: ColorRect = $Background

var intro_duration: float = 5.5
var elapsed_time: float = 0.0
var can_skip: bool = false
var is_transitioning: bool = false
var _transition_lock: bool = false

const NEXT_SCENE_PATH := "res://scenes/main_menu.tscn"

func _ready() -> void:
	# Apply current locale
	_apply_current_locale()

	# Subscribe to locale changes
	if EventBus and EventBus.has_signal("locale_changed"):
		EventBus.locale_changed.connect(_on_locale_changed)

	# Ensure background is visible from frame 1 (prevents black flash)
	if background:
		background.color = Color(0.02, 0.03, 0.06, 1.0)
		background.modulate.a = 1.0
		background.visible = true

	# Hide animated elements initially
	modulate.a = 1.0
	if title_label:
		title_label.modulate.a = 0.0
	if subtitle_label:
		subtitle_label.modulate.a = 0.0
	if arabic_label:
		arabic_label.modulate.a = 0.0
	if logo_past:
		logo_past.modulate.a = 0.0
	if logo_present:
		logo_present.modulate.a = 0.0
	if logo_future:
		logo_future.modulate.a = 0.0
	if logo_core:
		logo_core.modulate.a = 0.0
	if logo_echo_glow:
		logo_echo_glow.modulate.a = 0.0
	if progress_bar:
		progress_bar.modulate.a = 0.0
	if skip_btn:
		skip_btn.modulate.a = 0.0
		skip_btn.pressed.connect(_skip_intro)

	# Start intro sequence
	_start_sequence()


func _process(delta: float) -> void:
	if is_transitioning:
		return
	elapsed_time += delta

	var progress = clamp(elapsed_time / intro_duration, 0.0, 1.0)
	if progress_bar:
		progress_bar.value = progress * 100.0

	if elapsed_time >= intro_duration:
		_transition_to_menu()
		return

	if not can_skip and elapsed_time > 1.0:
		can_skip = true
		var tween = create_tween()
		tween.tween_property(skip_btn, "modulate:a", 1.0, 0.5)


func _start_sequence() -> void:
	# Phase 1: Logo arcs appear (0 - 1.5s)
	var t1 = create_tween()
	t1.set_parallel(true)
	if logo_past:
		t1.tween_property(logo_past, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC)
	if logo_present:
		t1.tween_property(logo_present, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC).set_delay(0.15)
	if logo_future:
		t1.tween_property(logo_future, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC).set_delay(0.30)

	# Phase 2: Core pulse + echo glow (1.5 - 2.2s)
	t1.tween_callback(func():
		if logo_core:
			var core_t = create_tween().set_parallel(true)
			core_t.tween_property(logo_core, "modulate:a", 1.0, 0.5)
			var pulse = create_tween().set_loops()
			pulse.tween_property(logo_core, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(logo_core, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
		if logo_echo_glow:
			var glow_t = create_tween()
			glow_t.tween_property(logo_echo_glow, "modulate:a", 1.0, 0.8)
	).set_delay(1.0)

	# Phase 3: Title text appears
	t1.tween_callback(func():
		if title_label:
			var t = create_tween().set_parallel(true)
			t.tween_property(title_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_BACK)
			t.tween_property(title_label, "position:y", title_label.position.y - 20, 0.8).set_trans(Tween.TRANS_BACK)
	).set_delay(2.0)

	# Phase 4: Subtitle + Arabic
	t1.tween_callback(func():
		if subtitle_label:
			var t1s = create_tween()
			t1s.tween_property(subtitle_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC)
		if arabic_label:
			var t2s = create_tween()
			t2s.tween_property(arabic_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_delay(0.15)
	).set_delay(2.6)

	# Phase 5: Progress bar appears
	t1.tween_callback(func():
		if progress_bar:
			var t = create_tween()
			t.tween_property(progress_bar, "modulate:a", 1.0, 0.5)
	).set_delay(3.5)


func _skip_intro() -> void:
	if not can_skip or is_transitioning:
		return
	_transition_to_menu()


func _transition_to_menu() -> void:
	if _transition_lock:
		return
	_transition_lock = true
	is_transitioning = true

	print("[Intro] Transitioning to Main Menu...")

	# Verify target scene exists before transitioning
	if not ResourceLoader.exists(NEXT_SCENE_PATH):
		push_error("[Intro] Scene not found: %s" % NEXT_SCENE_PATH)
		_transition_lock = false
		is_transitioning = false
		return

	# Method 1: Use SceneTreeTimer to ensure fade-out completes before transition
	# This avoids the race condition where Intro gets freed mid-fade
	var fade_tween = create_tween()
	if fade_tween:
		fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
		fade_tween.tween_callback(_do_scene_change)


func _do_scene_change() -> void:
	print("[Intro] Executing scene change...")
	var err = get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	if err != OK:
		push_error("[Intro] change_scene_to_file failed with error: %d" % err)
		# Fallback: defer to next frame
		call_deferred("_do_scene_change")


func _input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			if can_skip:
				_skip_intro()


func _exit_tree() -> void:
	# Cleanup on forced exit
	is_transitioning = false


func _tr(key: String, fallback: String) -> String:
	var loc = get_node_or_null("/root/Localization")
	if loc and loc.has_method("t"):
		var result = loc.t(key)
		if result and not result.begins_with("["):
			return result
	return fallback


func _apply_current_locale() -> void:
	if title_label:
		title_label.text = _tr("app.title", "ECHO//LINE")
	if subtitle_label:
		subtitle_label.text = _tr("app.subtitle", "Echoes Across Time")
	if arabic_label:
		arabic_label.text = "أَصْدَاء"


func _on_locale_changed(_new_locale: String, _is_rtl: bool) -> void:
	_apply_current_locale()

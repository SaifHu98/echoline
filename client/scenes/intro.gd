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

var intro_duration: float = 5.5
var elapsed_time: float = 0.0
var can_skip: bool = false

func _ready() -> void:
	# Hide everything initially
	modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	arabic_label.modulate.a = 0.0
	logo_past.modulate.a = 0.0
	logo_present.modulate.a = 0.0
	logo_future.modulate.a = 0.0
	logo_core.modulate.a = 0.0
	logo_echo_glow.modulate.a = 0.0
	progress_bar.modulate.a = 0.0
	skip_btn.modulate.a = 0.0

	skip_btn.pressed.connect(_skip_intro)

	# Start intro sequence
	_start_sequence()


func _process(delta: float) -> void:
	elapsed_time += delta

	# Update progress
	var progress = clamp(elapsed_time / intro_duration, 0.0, 1.0)
	progress_bar.value = progress * 100.0

	# Auto-transition when done
	if elapsed_time >= intro_duration:
		_transition_to_menu()

	# Enable skip after 1 second
	if not can_skip and elapsed_time > 1.0:
		can_skip = true
		var tween = create_tween()
		tween.tween_property(skip_btn, "modulate:a", 1.0, 0.5)


func _start_sequence() -> void:
	# Phase 1: Fade in background (0 - 0.5s)
	var t1 = create_tween()
	t1.tween_property(self, "modulate:a", 1.0, 0.5)

	# Phase 2: Logo arcs appear (0.5 - 1.5s)
	t1.tween_callback(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(logo_past, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC)
		t.tween_property(logo_present, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC).set_delay(0.15)
		t.tween_property(logo_future, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CIRC).set_delay(0.30)
	)

	# Phase 3: Core pulse + echo glow (1.5 - 2.2s)
	t1.tween_callback(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(logo_core, "modulate:a", 1.0, 0.5)
		t.tween_property(logo_echo_glow, "modulate:a", 1.0, 0.8)
		# Pulse animation for core
		var pulse = create_tween().set_loops()
		pulse.tween_property(logo_core, "scale", Vector2(1.15, 1.15), 0.8).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(logo_core, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)
	)

	# Phase 4: Title text appears (2.0 - 3.0s)
	t1.tween_callback(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(title_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_BACK)
		t.tween_property(title_label, "position:y", title_label.position.y - 20, 0.8).set_trans(Tween.TRANS_BACK)
	).set_delay(0.4)

	# Phase 5: Subtitle + Arabic (2.6 - 3.4s)
	t1.tween_callback(func():
		var t = create_tween().set_parallel(true)
		t.tween_property(subtitle_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC)
		t.tween_property(arabic_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_delay(0.15)
	).set_delay(0.3)

	# Phase 6: Progress bar appears (3.5 - 4.0s)
	t1.tween_callback(func():
		var t = create_tween()
		t.tween_property(progress_bar, "modulate:a", 1.0, 0.5)
	).set_delay(0.6)


func _skip_intro() -> void:
	if not can_skip:
		return
	_transition_to_menu()


func _transition_to_menu() -> void:
	# Fade out and switch scene
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			if can_skip:
				_skip_intro()

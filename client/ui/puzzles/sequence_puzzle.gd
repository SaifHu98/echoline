extends Control

# ECHO//LINE — Sequence Puzzle (Mini-game)
# Player must tap symbols in correct order

@onready var symbol_buttons: Array[Button] = []
@onready var progress_display: HBoxContainer = $Panel/VBox/ProgressDisplay
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var hint_label: Label = $Panel/VBox/HintLabel
@onready var close_btn: Button = $Panel/VBox/CloseButton

var puzzle_sequence: Array[int] = []
var player_sequence: Array[int] = []
var symbols: Array[String] = ["◆", "▲", "●", "★", "◯", "✦"]
var symbol_colors: Array[Color] = [
	Color(1, 0.84, 0.4), Color(0, 0.95, 1), Color(1, 0.5, 0.95),
	Color(0.5, 1, 0.5), Color(1, 0.7, 0.3), Color(0.8, 0.6, 1)
]
var is_showing_sequence: bool = false
var round: int = 0
var max_rounds: int = 5
var on_complete: Callable = Callable()


func _ready() -> void:
	modulate.a = 0.0
	for i in range(6):
		var btn_path = "Panel/VBox/Symbols/Symbol" + str(i)
		if has_node(btn_path):
			symbol_buttons.append(get_node(btn_path))

	for i in range(symbol_buttons.size()):
		if i < symbols.size():
			symbol_buttons[i].text = symbols[i]
		if symbol_buttons[i]:
			symbol_buttons[i].pressed.connect(_on_symbol_pressed.bind(i))

	if close_btn:
		close_btn.pressed.connect(_on_close)

	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func start_puzzle(round_count: int = 5, on_puzzle_complete: Callable = Callable()) -> void:
	max_rounds = round_count
	round = 0
	on_complete = on_puzzle_complete
	_next_round()


func _next_round() -> void:
	player_sequence.clear()
	if round >= max_rounds:
		_complete_puzzle(true)
		return
	round += 1

	# Generate sequence
	puzzle_sequence.clear()
	for i in range(round + 2):
		puzzle_sequence.append(randi() % 6)

	_show_sequence()


func _show_sequence() -> void:
	is_showing_sequence = true
	title_label.text = "Watch the sequence..."

	for child in progress_display.get_children():
		child.queue_free()
	for i in range(puzzle_sequence.size()):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(20, 20)
		dot.color = Color(0.3, 0.3, 0.4, 1)
		progress_display.add_child(dot)

	# Animate showing the sequence
	var timer = 0.0
	for i in range(puzzle_sequence.size()):
		var idx = puzzle_sequence[i]
		get_tree().create_timer(timer).timeout.connect(_highlight_symbol.bind(idx))
		timer += 0.7

	get_tree().create_timer(timer + 0.3).timeout.connect(_start_player_input)


func _highlight_symbol(idx: int) -> void:
	if idx >= symbol_buttons.size():
		return
	var btn = symbol_buttons[idx]
	var original_modulate = btn.modulate
	var original_scale = btn.scale
	btn.modulate = Color(2, 2, 2)
	btn.scale = Vector2(1.2, 1.2)
	get_tree().create_timer(0.4).timeout.connect(func():
		btn.modulate = original_modulate
		btn.scale = original_scale
	)


func _start_player_input() -> void:
	is_showing_sequence = false
	title_label.text = "Repeat the sequence!"
	hint_label.text = "Tap " + str(puzzle_sequence.size()) + " symbols"


func _on_symbol_pressed(idx: int) -> void:
	if is_showing_sequence:
		return

	player_sequence.append(idx)
	var pos = player_sequence.size() - 1

	# Highlight pressed
	_highlight_symbol(idx)

	# Update progress
	if pos < progress_display.get_child_count():
		var dot = progress_display.get_child(pos)
		if dot is ColorRect:
			dot.color = Color(0.3, 1, 0.5, 1)

	# Check sequence
	if pos >= puzzle_sequence.size():
		_check_sequence()


func _check_sequence() -> void:
	var correct = true
	for i in range(puzzle_sequence.size()):
		if i >= player_sequence.size() or player_sequence[i] != puzzle_sequence[i]:
			correct = false
			break

	if correct:
		title_label.text = "✓ Correct!"
		get_tree().create_timer(1.0).timeout.connect(_next_round)
	else:
		title_label.text = "� Wrong sequence"
		get_tree().create_timer(1.5).timeout.connect(func():
			_complete_puzzle(false)
		)


func _complete_puzzle(success: bool) -> void:
	if success:
		title_label.text = "🎉 Puzzle Complete!"
	else:
		title_label.text = "� Puzzle Failed"

	if on_complete.is_valid():
		on_complete.call(success)

	get_tree().create_timer(2.0).timeout.connect(_on_close)


func _on_close() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	get_tree().create_timer(0.3).timeout.connect(queue_free)

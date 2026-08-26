class_name TouchTargetValidator
extends Node

# ECHO//LINE — Touch Target Validator
# =====================================
# ضمان كل أزرار اللعبة ≥ 48dp (Material guideline)
# يعمل في development builds كـ validator، وفي release كـ enforcement

const MIN_TARGET_DP := 48  # Android accessibility minimum
const RECOMMENDED_TARGET_DP := 56  # أكثر راحة

# DPI scaling — يجب ضرب dp في dpi_scale_factor
# في Godot 4: get_window().content_scale_factor
static func get_scale_factor() -> float:
	if not is_instance_valid(Engine.get_main_loop()):
		return 1.0
	var root = Engine.get_main_loop().root
	if root and root.has_method("get_content_scale_factor"):
		return root.content_scale_factor
	return 1.0


# returns true if size is OK
static func validate(control: Control, strict: bool = false) -> bool:
	var min_px = (RECOMMENDED_TARGET_DP if strict else MIN_TARGET_DP) * get_scale_factor()
	if control.custom_minimum_size.y >= min_px:
		return true
	push_warning("[UX] Touch target too small on '%s': %.0fpx (need ≥%.0fpx = %ddp)" % [
		control.name,
		control.custom_minimum_size.y,
		min_px,
		RECOMMENDED_TARGET_DP if strict else MIN_TARGET_DP,
	])
	return false


# Force a control to meet minimum size
static func ensure_size(control: Control, strict: bool = false) -> void:
	var min_dp = RECOMMENDED_TARGET_DP if strict else MIN_TARGET_DP
	var min_px = min_dp * get_scale_factor()
	control.custom_minimum_size = Vector2(
		max(control.custom_minimum_size.x, min_px),
		max(control.custom_minimum_size.y, min_px),
	)


# Validate a tree of buttons
static func validate_tree(root: Node, strict: bool = false) -> Array[String]:
	var violations: Array[String] = []
	_walk(root, violations, strict)
	return violations


static func _walk(node: Node, violations: Array[String], strict: bool) -> void:
	if node is Button or node is BaseButton:
		if not validate(node, strict):
			violations.append(node.get_path())
	if node is LineEdit:
		var min_px = (RECOMMENDED_TARGET_DP if strict else MIN_TARGET_DP) * get_scale_factor()
		if node.custom_minimum_size.y < min_px:
			violations.append(String(node.get_path()) + " (LineEdit)")
	for child in node.get_children():
		_walk(child, violations, strict)


# Auto-fix: walk a tree and ensure all buttons meet minimum size
static func auto_fix_tree(root: Node, strict: bool = false) -> int:
	var fixed: int = 0
	_walk_fix(root, fixed, strict)
	return fixed


static func _walk_fix(node: Node, fixed: int, strict: bool) -> void:
	if node is Button or node is BaseButton or node is LineEdit:
		var min_px = (RECOMMENDED_TARGET_DP if strict else MIN_TARGET_DP) * get_scale_factor()
		if node.custom_minimum_size.y < min_px:
			ensure_size(node, strict)
			fixed += 1
	for child in node.get_children():
		_walk_fix(child, fixed, strict)

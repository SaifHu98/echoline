class_name EchoTrailRenderer
extends Node3D

# ECHO//LINE — Echo Trail Renderer
# Makes cause-and-effect visible across timelines.
# When player in Timeline A triggers an action that affects Timeline B,
# we spawn:
#   1. Ripple at the source (origin) in Timeline A
#   2. Trail beam from origin entity to a "gate" point
#   3. Ripple at the target (delayed) in Timeline B
# Each piece uses a timeline-specific shape grammar (arc/square/hex)

@export var ripple_template_past: PackedScene
@export var ripple_template_present: PackedScene
@export var ripple_template_future: PackedScene
@export var trail_template_past: PackedScene
@export var trail_template_present: PackedScene
@export var trail_template_future: PackedScene

var vfx_pool: Node = null
var active_trails: Array = []


func _ready() -> void:
	if not vfx_pool:
		vfx_pool = get_tree().get_first_node_in_group("vfx_pool")

	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)


func register_templates() -> void:
	# Will be called by main scene after VFXPool initialization
	pass


# === Public API ===

func play_echo_chain(source_pos: Vector3, target_pos: Vector3, source_timeline: String, target_timeline: String, propagation_delay_ms: int = 800) -> void:
	# 1. Spawn ripple at source (immediate)
	_spawn_ripple(source_pos, source_timeline, 0.0)

	# 2. Spawn trail beam (immediate)
	_spawn_trail(source_pos, target_pos, source_timeline, 0.0)

	# 3. Spawn ripple at target (delayed)
	_spawn_ripple(target_pos, target_timeline, float(propagation_delay_ms) / 1000.0)

	# 4. Optional: HUD icon flash (handled by HUD separately)


func _spawn_ripple(pos: Vector3, timeline: String, delay_sec: float) -> void:
	if delay_sec > 0:
		await get_tree().create_timer(delay_sec).timeout

	var template = _get_ripple_template(timeline)
	if template and vfx_pool and vfx_pool.has_method("acquire"):
		var ripple = vfx_pool.acquire("ripple_" + timeline)
		if ripple:
			ripple.global_position = pos
			ripple.visible = true
			if ripple.has_method("play"):
				ripple.play(_get_timeline_color(timeline))


func _spawn_trail(from: Vector3, to: Vector3, timeline: String, delay_sec: float) -> void:
	if delay_sec > 0:
		await get_tree().create_timer(delay_sec).timeout

	var template = _get_trail_template(timeline)
	if template and vfx_pool and vfx_pool.has_method("acquire"):
		var trail = vfx_pool.acquire("trail_" + timeline)
		if trail:
			trail.global_position = from
			# Orient the trail
			var dir = (to - from).normalized()
			if dir.length() > 0:
				trail.look_at(to, Vector3.UP)
			trail.visible = true
			if trail.has_method("play"):
				trail.play(from, to, _get_timeline_color(timeline))


# === Event-driven ===

func _on_echo_propagated(echo_id: String, _loc_key: String, _audio: String, visual: String, deltas: Array) -> void:
	# Find positions of source and target entities
	var world = get_tree().get_first_node_in_group("world")
	if not world:
		return

	var source_entity = _find_entity(world, echo_id)
	if not source_entity:
		return

	var source_timeline = _detect_timeline(world, source_entity)
	var source_pos = source_entity.global_position

	# Spawn ripple at source
	_spawn_ripple(source_pos, source_timeline, 0.0)

	# Process each delta (each effect target)
	for delta in deltas:
		var target_entity_name = delta.get("entity", "")
		var target_timeline = delta.get("timeline", "")
		var delay_ms = delta.get("propagation_delay_ms", 800)
		if not target_timeline or not target_entity_name:
			continue
		var target_entity = _find_entity_by_timeline(world, target_timeline, target_entity_name)
		if not target_entity:
			continue
		var target_pos = target_entity.global_position

		# Trail
		_spawn_trail(source_pos, target_pos, source_timeline, 0.0)

		# Delayed ripple at target
		_spawn_ripple(target_pos, target_timeline, float(delay_ms) / 1000.0)


# === Helpers ===

func _get_ripple_template(timeline: String) -> PackedScene:
	match timeline:
		"past": return ripple_template_past
		"present": return ripple_template_present
		"future": return ripple_template_future
	return null


func _get_trail_template(timeline: String) -> PackedScene:
	match timeline:
		"past": return trail_template_past
		"present": return trail_template_present
		"future": return trail_template_future
	return null


func _get_timeline_color(timeline: String) -> Color:
	match timeline:
		"past": return Color("#D4AF37")
		"present": return Color("#4FC3F7")
		"future": return Color("#B388FF")
	return Color.WHITE


func _find_entity(world: Node, entity_id: String) -> Node3D:
	for child in world.get_children():
		var found = _find_recursive(child, entity_id)
		if found:
			return found
	return null


func _find_entity_by_timeline(world: Node, timeline: String, entity_id: String) -> Node3D:
	# Search in specific timeline subtree
	for child in world.get_children():
		if "timeline" in child.name.to_lower() or timeline in child.name.to_lower():
			var found = _find_recursive(child, entity_id)
			if found:
				return found
	# Fallback: search everywhere
	return _find_entity(world, entity_id)


func _find_recursive(node: Node, name_to_find: String) -> Node3D:
	if node.name == name_to_find and node is Node3D:
		return node as Node3D
	for child in node.get_children():
		var found = _find_recursive(child, name_to_find)
		if found:
			return found
	return null


func _detect_timeline(world: Node, entity: Node3D) -> String:
	# Walk up parents looking for timeline indicator
	var current = entity
	while current and current != world:
		var parent = current.get_parent()
		if parent:
			var parent_name = parent.name.to_lower()
			if "past" in parent_name: return "past"
			if "present" in parent_name: return "present"
			if "future" in parent_name: return "future"
		current = parent
	return "past"

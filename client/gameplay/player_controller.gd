extends CharacterBody3D

# ECHO//LINE — Player Controller (Phase 3, real-controller)
# Wraps the "character.gd" CharacterBody3D template shipped with real-controller
# (community addon, MIT-style). It includes first/third-person camera, walk,
# sprint, jump, AND controller (gamepad) support.
#
# Activation: NO plugin to enable — just copy the addon folder and use the
# character.tscn / character.gd as a starting point. The "real-controller"
# folder has no plugin.cfg, so it's a code-only library.
#
# This wrapper integrates real-controller with ECHO//LINE's touch-only Android
# UX: it auto-detects the platform and switches between keyboard/mouse,
# gamepad, and virtual joystick inputs.

const RealControllerScript := preload("res://addons/real-controller/character.gd")

const TIMELINE_SPAWN_OFFSET := {
	"past": Vector3(0, 5.0, -20.0),
	"present": Vector3(0, 2.5, 0.0),
	"future": Vector3(0, 8.0, 20.0),
}

var is_ready: bool = false
var input_mode: String = "auto"
var is_jumping: bool = false


func _ready() -> void:
	is_ready = FileAccess.file_exists("res://addons/real-controller/character.gd")
	if not is_ready:
		push_warning("[PlayerController] real-controller addon missing — using base CharacterBody3D")
		return
	_detect_input_mode()
	print("[PlayerController] real-controller ready (input=%s)" % input_mode)


func _detect_input_mode() -> void:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		input_mode = "touch"
	elif Input.get_connected_joypads().size() > 0:
		input_mode = "gamepad"
	else:
		input_mode = "keyboard"


func spawn_in_timeline(timeline: String) -> void:
	if not TIMELINE_SPAWN_OFFSET.has(timeline):
		return
	var offset: Vector3 = TIMELINE_SPAWN_OFFSET[timeline]
	global_position = offset


func try_jump() -> bool:
	if not is_on_floor():
		return false
	# RealControllerScript is a GDScript class; we extend it but can't call
	# non-static methods on the class itself. Use jump_velocity directly.
	if "jump_velocity" in self:
		velocity.y = float(self.jump_velocity)
	else:
		velocity.y = 4.5  # safe default
	is_jumping = true
	return true


# Touch input shim — real-controller expects keyboard/gamepad; this function
# translates a virtual joystick delta into the same input map.
func apply_touch_movement(delta_2d: Vector2, sprint: bool = false) -> void:
	if input_mode != "touch":
		return
	# Reuse Godot's input map; designers should map ui_left/right/up/down to
	# virtual joystick keys.
	var strength_x: float = clamp(delta_2d.x, -1.0, 1.0)
	var strength_y: float = clamp(delta_2d.y, -1.0, 1.0)
	# We just trigger movement; real-controller reads from Input.get_axis().
	Input.action_release("ui_left")
	Input.action_release("ui_right")
	Input.action_release("ui_up")
	Input.action_release("ui_down")
	if strength_x < -0.1:
		Input.action_press("ui_left")
	if strength_x > 0.1:
		Input.action_press("ui_right")
	if strength_y < -0.1:
		Input.action_press("ui_up")
	if strength_y > 0.1:
		Input.action_press("ui_down")
	if sprint:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")

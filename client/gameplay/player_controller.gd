class_name PlayerController
extends CharacterBody3D

# ECHO//LINE — Player Controller (3D)
# Touch + keyboard controls, smooth movement, camera follow

@export var walk_speed: float = 4.5
@export var run_speed: float = 7.5
@export var acceleration: float = 12.0
@export var deceleration: float = 14.0
@export var jump_velocity: float = 6.0
@export var gravity: float = 18.0
@export var rotation_speed: float = 8.0
@export var camera_distance: float = 8.0
@export var camera_height: float = 4.0

var current_speed: float = 0.0
var is_running: bool = false
var is_jumping: bool = false
var is_grounded: bool = false
var input_direction: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO
var mouse_capture: bool = false

@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var spring_arm: SpringArm3D = $CameraRig/SpringArm3D
@onready var model: Node3D = $Model
@onready var interact_ray: RayCast3D = $InteractRay
@onready var footstep_audio: AudioStreamPlayer3D = $FootstepAudio
@onready var echo_emitter: Node3D = $EchoEmitter

var focused_interactable: Node3D = null
var nearby_interactables: Array = []

# Touch controls state
var touch_movement_vector: Vector2 = Vector2.ZERO
var touch_camera_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Setup spring arm
	if spring_arm:
		spring_arm.add_excluded_object(self.get_rid())
		spring_arm.spring_length = camera_distance

	# Connect signals
	if interact_ray:
		interact_ray.enabled = true


func _physics_process(delta: float) -> void:
	# Read input
	var raw_input = _get_input_direction()
	input_direction = raw_input

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
		is_grounded = false
	else:
		is_grounded = true

	# Handle jump
	if Input.is_action_just_pressed("ui_accept") or _jump_requested():
		if is_on_floor():
			velocity.y = jump_velocity
			is_jumping = true

	# Calculate movement direction relative to camera
	move_direction = Vector3.ZERO
	var cam_basis = camera.global_transform.basis if camera else global_transform.basis

	if input_direction.y < 0:
		move_direction -= cam_basis.z * abs(input_direction.y)
	elif input_direction.y > 0:
		move_direction += cam_basis.z * input_direction.y

	if input_direction.x < 0:
		move_direction -= cam_basis.x * abs(input_direction.x)
	elif input_direction.x > 0:
		move_direction += cam_basis.x * input_direction.x

	move_direction.y = 0
	move_direction = move_direction.normalized()

	# Determine speed
	var target_speed = run_speed if is_running else walk_speed
	if move_direction.length() > 0.1:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, deceleration * delta)

	# Apply horizontal velocity
	if move_direction.length() > 0.1:
		velocity.x = move_direction.x * current_speed
		velocity.z = move_direction.z * current_speed
		# Rotate model towards movement
		var target_rotation = atan2(move_direction.x, move_direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_rotation, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

	# Move character
	move_and_slide()

	# Footstep audio
	if is_on_floor() and move_direction.length() > 0.5 and footstep_audio:
		if not footstep_audio.playing:
			footstep_audio.play()

	# Update interact ray
	_update_focus()


func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO

	# Keyboard
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1

	# Touch (virtual joystick)
	dir += touch_movement_vector
	return dir.normalized() if dir.length() > 0.1 else Vector2.ZERO


func _jump_requested() -> bool:
	return false  # Touch button sets this externally


func _update_focus() -> void:
	if not interact_ray or not interact_ray.is_colliding():
		_focus_changed(null)
		return

	var collider = interact_ray.get_collider()
	if collider and collider.is_in_group("interactable"):
		_focus_changed(collider)
	else:
		_focus_changed(null)


func _focus_changed(new_focus: Node3D) -> void:
	if focused_interactable == new_focus:
		return

	# Unfocus previous
	if focused_interactable and is_instance_valid(focused_interactable):
		if focused_interactable.has_method("set_focused"):
			focused_interactable.set_focused(false)

	focused_interactable = new_focus

	# Focus new
	if focused_interactable:
		if focused_interactable.has_method("set_focused"):
			focused_interactable.set_focused(true)
		if focused_interactable.has_method("get_interaction_text"):
			var text = focused_interactable.get_interaction_text()
			EventBus.subtitle_requested.emit("[E] " + text, 3.0)


func interact() -> void:
	if focused_interactable and focused_interactable.has_method("interact"):
		focused_interactable.interact(self)


# Touch input handlers (called from UI)
func set_touch_movement(vector: Vector2) -> void:
	touch_movement_vector = vector


func set_touch_camera_delta(delta: Vector2) -> void:
	touch_camera_delta = delta
	if spring_arm:
		spring_arm.rotation.y -= delta.x * 0.01
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - delta.y * 0.01, -1.2, 0.5)

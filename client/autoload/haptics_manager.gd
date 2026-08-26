extends Node

# Mobile Haptics, Vibration, and Dynamic Screen Impulse Manager

signal screen_shake_requested(intensity: float, duration_sec: float)

var haptics_supported: bool = false

func _ready() -> void:
	# Check if running on mobile device with vibration support
	if OS.has_feature("mobile"):
		haptics_supported = true

func trigger_echo_pulse_haptic() -> void:
	screen_shake_requested.emit(0.35, 0.25)
	if haptics_supported:
		Input.vibrate_handheld(40) # 40ms light impulse

func trigger_anchor_lock_haptic() -> void:
	screen_shake_requested.emit(0.6, 0.4)
	if haptics_supported:
		Input.vibrate_handheld(120) # 120ms heavy click

func trigger_catastrophe_alarm_haptic() -> void:
	screen_shake_requested.emit(0.2, 0.15)
	if haptics_supported:
		Input.vibrate_handheld(60)


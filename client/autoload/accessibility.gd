extends Node

# Accessibility Manager for ECHO//LINE (أصداء)

var high_contrast: bool = false
var colorblind_mode: bool = false
var reduced_motion: bool = false
var screen_shake_enabled: bool = true
var text_scale: float = 1.0
var subtitles_enabled: bool = true

func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	EventBus.contrast_mode_changed.emit(high_contrast)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	EventBus.motion_mode_changed.emit(reduced_motion)

func set_text_scale(scale_val: float) -> void:
	text_scale = clamp(scale_val, 0.8, 1.6)
	EventBus.text_scale_changed.emit(text_scale)

func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled

func set_screen_shake(enabled: bool) -> void:
	screen_shake_enabled = enabled



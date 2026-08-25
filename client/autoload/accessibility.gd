extends Node

# Accessibility Manager for ECHO//LINE (أصداء)

var high_contrast: boolean = false
var colorblind_mode: boolean = false
var reduced_motion: boolean = false
var screen_shake_enabled: boolean = true
var text_scale: float = 1.0
var subtitles_enabled: boolean = true

func set_high_contrast(enabled: boolean) -> void:
	high_contrast = enabled
	EventBus.contrast_mode_changed.emit(high_contrast)

func set_reduced_motion(enabled: boolean) -> void:
	reduced_motion = enabled
	EventBus.motion_mode_changed.emit(reduced_motion)

func set_text_scale(scale_val: float) -> void:
	text_scale = clampf(scale_val, 0.8, 1.6)
	EventBus.text_scale_changed.emit(text_scale)

func set_colorblind_mode(enabled: boolean) -> void:
	colorblind_mode = enabled

func set_screen_shake(enabled: boolean) -> void:
	screen_shake_enabled = enabled

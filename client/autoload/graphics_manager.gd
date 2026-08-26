extends Node

# ECHO//LINE — Graphics Manager (stub)
# Auto-registered manager for graphics quality. Used by graphics_settings_view.gd.

var current_quality: int = 1  # 0=low, 1=med, 2=high, 3=ultra
var fullscreen: bool = false
var resolution_scale: float = 1.0
var vsync: bool = true
var fps_cap: int = 60

signal settings_changed


func _ready() -> void:
	print("[GraphicsManager] Loaded")


func set_quality(q: int) -> void:
	current_quality = q
	_apply()
	settings_changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	settings_changed.emit()


func set_resolution_scale(scale: float) -> void:
	resolution_scale = clamp(scale, 0.5, 2.0)
	_apply()
	settings_changed.emit()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply()
	settings_changed.emit()


func set_fps_cap(cap: int) -> void:
	fps_cap = cap
	_apply()
	settings_changed.emit()


func _apply() -> void:
	# Stub: actual implementation would change RenderingServer settings.
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap if fps_cap > 0 else 0

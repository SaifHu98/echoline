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
	call_deferred("load_from_disk")


func set_quality(q: int) -> void:
	current_quality = clamp(q, 0, 3)
	_apply()
	settings_changed.emit()
	save_to_disk()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply()
	settings_changed.emit()
	save_to_disk()


func set_resolution_scale(scale: float) -> void:
	resolution_scale = clamp(scale, 0.5, 2.0)
	_apply()
	settings_changed.emit()
	save_to_disk()


func set_vsync(value: bool) -> void:
	vsync = value
	_apply()
	settings_changed.emit()
	save_to_disk()


func set_fps_cap(cap: int) -> void:
	fps_cap = cap
	_apply()
	settings_changed.emit()
	save_to_disk()


func _apply() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_cap if fps_cap > 0 else 0


func save_to_disk() -> void:
	var file := FileAccess.open("user://graphics_settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({
			"current_quality": current_quality,
			"fullscreen": fullscreen,
			"resolution_scale": resolution_scale,
			"vsync": vsync,
			"fps_cap": fps_cap,
		}))


func load_from_disk() -> void:
	if not FileAccess.file_exists("user://graphics_settings.json"):
		_apply()
		return
	var file := FileAccess.open("user://graphics_settings.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text()) if file else null
	if data is Dictionary:
		current_quality = clamp(int(data.get("current_quality", current_quality)), 0, 3)
		fullscreen = bool(data.get("fullscreen", fullscreen))
		resolution_scale = clamp(float(data.get("resolution_scale", resolution_scale)), 0.5, 2.0)
		vsync = bool(data.get("vsync", vsync))
		fps_cap = max(0, int(data.get("fps_cap", fps_cap)))
	_apply()


func reset_to_defaults() -> void:
	current_quality = 1
	fullscreen = false
	resolution_scale = 1.0
	vsync = true
	fps_cap = 60
	_apply()
	save_to_disk()

extends Node

# ECHO//LINE — Quality Profile (stub)
# Settings for graphics quality. Used by graphics_settings_view.gd.

enum Quality { LOW, MEDIUM, HIGH, ULTRA }

var current_quality: int = Quality.MEDIUM
var shadow_quality: int = 1
var texture_quality: int = 1
var anti_aliasing: bool = true
var bloom_enabled: bool = true
var motion_blur_enabled: bool = false
var vsync: bool = true

signal quality_changed(quality: int)


func _ready() -> void:
	print("[QualityProfile] Loaded (quality=MEDIUM)")


func set_quality(q: int) -> void:
	current_quality = q
	quality_changed.emit(q)

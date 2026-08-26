extends Node

# ECHO//LINE — BlendKit Browser (Phase 3, BlendKit)
# BlendKit (Blendkit.com / Jakub Ruzicka, MIT) is an EDITOR-only asset browser
# that connects to https://blendkit.com and lets you download free/CC0
# Blender assets directly into the project.
#
# Activation: enable "Blendkit" in Project Settings → Plugins.
# A new "BlendKit" menu appears in the top editor bar; a dock appears in the
# editor sidebar.
#
# This wrapper is a documentation stub — BlendKit has no runtime API.
# It only needs to be enabled while developing; exported APKs do not need it.

const BLENDKIT_BASE := "res://addons/blendkit"
const BLENDKIT_MENU := "res://addons/blendkit/menu.tscn"

var is_ready: bool = false


func _ready() -> void:
	is_ready = FileAccess.file_exists(BLENDKIT_MENU)
	if not is_ready:
		push_warning("[BlendKitBrowser] BlendKit menu scene missing")
		return
	print("[BlendKitBrowser] BlendKit editor dock available after plugin enable")


# Convenience: returns the list of folders the BlendKit dock scans for assets.
static func scanned_folders() -> Array:
	return [
		"res://meshes/",
		"res://textures/",
		"res://materials/",
		"res://hdri/",
	]


# Convenience: returns the URL the plugin contacts (for documentation only).
static func get_server_url() -> String:
	return "https://blendkit.com"

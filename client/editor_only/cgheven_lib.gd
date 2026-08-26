extends Node

# ECHO//LINE — CGHEVEN VFX Library (Phase 3, CGHEVEN Asset Library)
# CGHEVEN (cgheven.com, MIT) is an EDITOR-only dock that browses/downloads
# CG/VFX assets (HDRI, materials, particle systems) from api.cgheven.com.
#
# Activation: enable "CGHEVEN Asset Library" in Project Settings → Plugins.
# A "CGHEVEN" dock appears in the editor sidebar (next to FileSystem, etc.).
#
# This wrapper is a documentation stub — CGHEVEN has no runtime API.
# It only needs to be enabled while developing; exported APKs do not need it.

const CGHEVEN_BASE := "res://addons/cgheven"

var is_ready: bool = false


func _ready() -> void:
	is_ready = DirAccess.dir_exists_absolute(CGHEVEN_BASE)
	if not is_ready:
		push_warning("[CGHEVENLib] CGHEVEN plugin folder missing")
		return
	print("[CGHEVENLib] CGHEVEN editor dock available after plugin enable")


static func get_api_url() -> String:
	return "https://api.cgheven.com"


static func recommended_folders_for_vfx() -> Array:
	return [
		"res://vfx/",
		"res://vfx/particles/",
		"res://vfx/materials/",
		"res://hdri/",
	]

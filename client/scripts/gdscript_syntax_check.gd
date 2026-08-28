extends SceneTree

# Parse every project GDScript so CI does not only validate the main scene.
var failures := 0
var checked := 0
const PROJECT_CODE_DIRS := ["autoload", "building", "core", "gameplay", "scenes", "scripts", "ui"]


func _init() -> void:
	call_deferred("_check_project")


func _check_project() -> void:
	_scan("res://")
	print("GDScript syntax check: %d files, %d failures" % [checked, failures])
	quit(1 if failures > 0 else 0)


func _scan(directory_path: String) -> void:
	if directory_path == "res://":
		for project_dir in PROJECT_CODE_DIRS:
			_scan(directory_path.path_join(project_dir))
		return
	for entry in DirAccess.get_directories_at(directory_path):
		if entry != ".godot" and entry != "build":
			_scan(directory_path.path_join(entry))
	for entry in DirAccess.get_files_at(directory_path):
		if not entry.ends_with(".gd"):
			continue
		var full_path := directory_path.path_join(entry)
		checked += 1
		if ResourceLoader.load(full_path, "Script") == null:
			push_error("Parse failed: %s" % full_path)
			failures += 1

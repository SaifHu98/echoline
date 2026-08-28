extends Node

## Persistent, offline-first campaign state for the long single-player journey.

const DATA_PATH := "res://data/single_player_campaign.json"
const SAVE_PATH := "user://single_player_campaign.json"

signal progress_changed(chapter_index: int, mission_id: String)

var campaign: Dictionary = {}
var completed_missions: Dictionary = {}
var active_chapter_index: int = -1


func _ready() -> void:
	_load_campaign()
	_load_progress()


func _load_campaign() -> void:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("[Campaign] Missing campaign data: %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		campaign = parsed


func get_chapters() -> Array:
	return campaign.get("chapters", [])


func get_chapter_count() -> int:
	return get_chapters().size()


func get_chapter(index: int) -> Dictionary:
	var chapters := get_chapters()
	if index < 0 or index >= chapters.size():
		return {}
	return chapters[index]


func get_campaign_title() -> String:
	return str(campaign.get("title", "The Last Chime"))


func get_campaign_subtitle() -> String:
	return str(campaign.get("subtitle", "A journey through twelve fractured chapters"))


func _chapter_key(index: int) -> String:
	var chapter := get_chapter(index)
	return str(chapter.get("id", "c%02d" % (index + 1)))


func _mission_key(chapter_index: int, mission_id: String) -> String:
	return "%s:%s" % [_chapter_key(chapter_index), mission_id]


func get_mission_id(mission: Dictionary, mission_index: int) -> String:
	var explicit_id := str(mission.get("id", ""))
	return explicit_id if not explicit_id.is_empty() else "m%02d" % (mission_index + 1)


func is_mission_complete(chapter_index: int, mission_id: String) -> bool:
	return bool(completed_missions.get(_mission_key(chapter_index, mission_id), false))


func get_chapter_progress(chapter_index: int) -> Dictionary:
	var chapter := get_chapter(chapter_index)
	var missions: Array = chapter.get("missions", [])
	var completed := 0
	for mission_index in range(missions.size()):
		var mission = missions[mission_index]
		if mission is Dictionary and is_mission_complete(chapter_index, get_mission_id(mission, mission_index)):
			completed += 1
	return {"completed": completed, "total": missions.size(), "complete": completed >= missions.size() and not missions.is_empty()}


func is_chapter_unlocked(index: int) -> bool:
	if index <= 0:
		return index == 0
	return bool(get_chapter_progress(index - 1).get("complete", false))


func begin_chapter(index: int) -> bool:
	if get_chapter(index).is_empty() or not is_chapter_unlocked(index):
		return false
	active_chapter_index = index
	_save_progress()
	return true


func has_active_chapter() -> bool:
	return active_chapter_index >= 0 and not get_chapter(active_chapter_index).is_empty()


func get_active_chapter() -> Dictionary:
	return get_chapter(active_chapter_index)


func record_echo_progress() -> String:
	if not has_active_chapter():
		return ""
	var chapter := get_active_chapter()
	var missions: Array = chapter.get("missions", [])
	for mission_index in range(missions.size()):
		var mission = missions[mission_index]
		if mission is Dictionary:
			var mission_id := get_mission_id(mission, mission_index)
			if not is_mission_complete(active_chapter_index, mission_id):
				complete_mission(active_chapter_index, mission_id)
				return mission_id
	return ""


func complete_mission(chapter_index: int, mission_id: String) -> void:
	if get_chapter(chapter_index).is_empty() or mission_id.is_empty():
		return
	var key := _mission_key(chapter_index, mission_id)
	if bool(completed_missions.get(key, false)):
		return
	completed_missions[key] = true
	_save_progress()
	progress_changed.emit(chapter_index, mission_id)


func exit_story() -> void:
	active_chapter_index = -1
	_save_progress()


func _save_progress() -> void:
	var payload := {"completed_missions": completed_missions, "active_chapter_index": active_chapter_index}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(payload))


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	completed_missions = parsed.get("completed_missions", {})
	active_chapter_index = int(parsed.get("active_chapter_index", -1))
	if active_chapter_index >= get_chapter_count():
		active_chapter_index = -1

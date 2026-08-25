extends Node

# ECHO//LINE — Achievement System
# Track player accomplishments, unlock rewards

signal achievement_unlocked(achievement: Dictionary)

var achievements: Array = []
var unlocked_ids: Array = []
var total_points: int = 0


func _ready() -> void:
	_initialize_achievements()
	_load_progress()

	# Subscribe to events
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)
	if EventBus.has_signal("match_concluded"):
		EventBus.match_concluded.connect(_on_match_concluded)
	if EventBus.has_signal("quest_completed"):
		EventBus.quest_completed.connect(_on_quest_completed)


func _initialize_achievements() -> void:
	achievements = [
		{
			"id": "first_echo",
			"title": "First Echo",
			"description": "Trigger your first echo propagation",
			"icon": "�",
			"points": 10,
			"rarity": "common"
		},
		{
			"id": "all_timelines",
			"title": "Time Traveler",
			"description": "Play all three timelines in one session",
			"icon": "�",
			"points": 50,
			"rarity": "rare"
		},
		{
			"id": "perfect_harmony",
			"title": "Perfect Harmony",
			"description": "Win a match with perfect harmony outcome",
			"icon": "✨",
			"points": 100,
			"rarity": "epic"
		},
		{
			"id": "speed_runner",
			"title": "Speed Runner",
			"description": "Complete a match in under 3 minutes",
			"icon": "⚡",
			"points": 75,
			"rarity": "rare"
		},
		{
			"id": "prop_master",
			"title": "Prop Master",
			"description": "Interact with 50 different props",
			"icon": "🔧",
			"points": 60,
			"rarity": "rare"
		},
		{
			"id": "social_butterfly",
			"title": "Social Butterfly",
			"description": "Send 100 quick messages",
			"icon": "💬",
			"points": 30,
			"rarity": "common"
		},
		{
			"id": "catastrophe_preventer",
			"title": "Catastrophe Preventer",
			"description": "Prevent 10 catastrophes",
			"icon": "🛡️",
			"points": 200,
			"rarity": "legendary"
		},
		{
			"id": "bot_commander",
			"title": "Bot Commander",
			"description": "Win a match with 3+ AI bots on your team",
			"icon": "🤖",
			"points": 80,
			"rarity": "epic"
		},
		{
			"id": "completionist",
			"title": "Completionist",
			"description": "Complete all quests in a match",
			"icon": "�",
			"points": 150,
			"rarity": "legendary"
		},
		{
			"id": "first_steps",
			"title": "First Steps",
			"description": "Play your first match",
			"icon": "�",
			"points": 5,
			"rarity": "common"
		}
	]


func _load_progress() -> void:
	# Load from save file
	if FileAccess.file_exists("user://achievements.json"):
		var file = FileAccess.open("user://achievements.json", FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			unlocked_ids = data.get("unlocked", [])
			total_points = data.get("points", 0)


func _save_progress() -> void:
	var file = FileAccess.open("user://achievements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"unlocked": unlocked_ids,
		"points": total_points
	}))


func unlock(achievement_id: String) -> bool:
	if achievement_id in unlocked_ids:
		return false

	for ach in achievements:
		if ach.id == achievement_id:
			unlocked_ids.append(achievement_id)
			total_points += ach.points
			_save_progress()
			achievement_unlocked.emit(ach)
			EventBus.subtitle_requested.emit("🏆 Achievement: " + ach.title, 4.0)
			return true
	return false


func _on_echo_propagated(echo_id: String, _loc_key: String, _audio: String, _visual: String, _deltas: Array) -> void:
	unlock("first_echo")


func _on_match_concluded(recap: Dictionary) -> void:
	unlock("first_steps")
	var outcome = recap.get("outcome", "")
	if outcome == "perfect_harmony":
		unlock("perfect_harmony")
	var duration = recap.get("durationSeconds", 0)
	if duration < 180:
		unlock("speed_runner")


func _on_quest_completed(_quest) -> void:
	# Track completions
	pass


func get_achievement(achievement_id: String) -> Dictionary:
	for ach in achievements:
		if ach.id == achievement_id:
			return ach
	return {}


func get_progress() -> Dictionary:
	return {
		"total": achievements.size(),
		"unlocked": unlocked_ids.size(),
		"points": total_points,
		"percentage": float(unlocked_ids.size()) / float(achievements.size())
	}

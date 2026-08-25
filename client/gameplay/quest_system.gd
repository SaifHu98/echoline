extends Node

# ECHO//LINE — Quest System
# Tracks main + side quests with objectives, progress, rewards

class QuestObjective:
	var description: String
	var type: String  # "interact", "collect", "solve", "echo"
	var target_id: String
	var required_count: int
	var current_count: int

	func _init(desc: String, t: String, target: String, count: int = 1) -> void:
		description = desc
		type = t
		target_id = target
		required_count = count
		current_count = 0

	func progress() -> float:
		return float(current_count) / float(required_count) if required_count > 0 else 1.0

	func is_complete() -> bool:
		return current_count >= required_count


class Quest:
	var id: String
	var title: String
	var description: String
	var timeline: String
	var objectives: Array[QuestObjective] = []
	var is_completed: bool = false
	var rewards: Dictionary = {}

	func _init(qid: String, qtitle: String, qdesc: String, tl: String = "") -> void:
		id = qid
		title = qtitle
		description = qdesc
		timeline = tl

	func add_objective(obj: QuestObjective) -> void:
		objectives.append(obj)

	func check_complete() -> bool:
		for obj in objectives:
			if not obj.is_complete():
				return false
		is_completed = true
		return true

	func progress_text() -> String:
		var completed = 0
		for obj in objectives:
			if obj.is_complete():
				completed += 1
		return str(completed) + "/" + str(objectives.size())


var active_quests: Dictionary = {}  # id → Quest
var completed_quests: Array[String] = []

signal quest_updated(quest_data: Dictionary)
signal quest_completed(quest: Quest)


func _ready() -> void:
	# Subscribe to events
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)


func start_quest(quest: Quest) -> void:
	active_quests[quest.id] = quest
	_emit_quest_update()


func _on_echo_propagated(echo_id: String, _loc_key: String, _audio: String, _visual: String, _deltas: Array) -> void:
	# Find quests with this objective
	for quest in active_quests.values():
		for obj in quest.objectives:
			if obj.type == "echo" and obj.target_id == echo_id:
				obj.current_count += 1
				_check_quest_completion(quest)


func _check_quest_completion(quest: Quest) -> void:
	if quest.check_complete():
		completed_quests.append(quest.id)
		active_quests.erase(quest.id)
		quest_completed.emit(quest)
		EventBus.subtitle_requested.emit("✓ Quest Complete: " + quest.title, 3.0)
	_emit_quest_update()


func _emit_quest_update() -> void:
	var data = {"quests": []}
	for q in active_quests.values():
		data.quests.append({
			"id": q.id,
			"title": q.title,
			"completed": q.is_completed,
			"progress": q.progress_text()
		})
	quest_updated.emit(data)


# Default quests for Clocktower District scenario
func setup_clocktower_quests() -> void:
	# Main quest: Restore the Clocktower
	var main = Quest.new("restore_clocktower", "Restore the Clocktower", "Repair the ancient mechanism to prevent the catastrophe", "present")
	main.add_objective(QuestObjective.new("Insert gear into mechanism", "interact", "clock_gear_mechanism", 1))
	main.add_objective(QuestObjective.new("Restore the manuscript", "interact", "archive_manuscript", 1))
	main.add_objective(QuestObjective.new("Activate the stabilizer", "interact", "gate_stabilizer_unit", 1))
	start_quest(main)

	# Side quest: Memory Garden (Past timeline)
	var memory = Quest.new("memory_garden", "Memory Garden", "Restore the heritage garden", "past")
	memory.add_objective(QuestObjective.new("Clear the canal", "interact", "canal_debris", 1))
	memory.add_objective(QuestObjective.new("Plant the seed", "interact", "courtyard_soil", 1))
	memory.add_objective(QuestObjective.new("Carve the tablet", "interact", "builder_archive_tablet", 1))
	start_quest(memory)

	# Side quest: Timeline Sync (Future timeline)
	var sync = Quest.new("timeline_sync", "Timeline Sync", "Synchronize the temporal frequencies", "future")
	sync.add_objective(QuestObjective.new("Tune the console frequency", "interact", "temporal_gate_console", 2))
	sync.add_objective(QuestObjective.new("Activate stabilizer", "interact", "gate_stabilizer_unit", 1))
	start_quest(sync)

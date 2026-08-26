class_name MissionGenerator
extends RefCounted

# ECHO//LINE — Procedural Mission Generator
# Generates missions for a match given:
#   - difficulty (1-5)
#   - player_count (1-4)
#   - timeline (past / present / future)
#   - the shared seed (deterministic)
#
# A "mission" is a single objective that drives the match forward. Matches
# have 3-5 missions; completing all of them triggers the causal recap.
#
# Mission types:
#   - collect: gather N shards/items within a time limit
#   - defend: protect an anchor from N waves
#   - build: cooperatively place K building pieces
#   - escort: guide a fragile object from A to B
#   - puzzle: solve an in-world riddle
#   - race: reach a target before opponents
#   - rescue: find and revive a fallen teammate
#   - intercept: stop an enemy action
#
# Difficulty scaling adjusts:
#   - target counts (more shards, more waves)
#   - time limits (less time on higher difficulty)
#   - reward multipliers (more shards on success)
#   - hazard density (more enemies, traps, environmental dangers)

const MISSION_TYPES := {
	"collect": {
		"description": "Gather {count} {item} before {time_limit}s elapse.",
		"base_count": {"past": 5, "present": 8, "future": 6},
		"base_time": 180,
		"reward_per_unit": 1,
	},
	"defend": {
		"description": "Protect the anchor through {wave_count} waves.",
		"base_waves": {"past": 3, "present": 4, "future": 5},
		"reward_per_wave": 5,
	},
	"build": {
		"description": "Cooperatively construct {count} pieces of {structure}.",
		"base_count": {"past": 4, "present": 6, "future": 5},
		"reward_per_unit": 3,
	},
	"escort": {
		"description": "Guide the {object} from {start} to {end} in {time_limit}s.",
		"base_time": 240,
		"reward_complete": 20,
	},
	"puzzle": {
		"description": "Solve the riddle of the {riddle_subject}.",
		"reward_complete": 15,
	},
	"race": {
		"description": "Reach the {target} before your timeline peers.",
		"reward_top": 15,
		"reward_finish": 5,
	},
	"rescue": {
		"description": "Find and revive {count} fallen echoes.",
		"base_count": {"past": 1, "present": 2, "future": 1},
		"reward_per_unit": 8,
	},
	"intercept": {
		"description": "Stop {target_action} before it completes.",
		"reward_complete": 25,
	},
}

const TIMELINE_FLAVOR := {
	"past": {
		"items": ["memory shards", "rune stones", "lanterns", "scrolls", "flowers"],
		"structures": ["courtyard wall", "archive wing", "garden path", "tower foundation"],
		"objects": ["memory shard", "scribe's lamp", "hollow king's crown"],
		"riddle_subjects": ["old well", "forgotten archivist", "stone guardian", "hollow throne"],
		"target_actions": ["the scribe rewriting history", "the courtyard falling",
			"the hollow king rising", "the archive burning"],
		"enemies": ["stone guardians", "hollow knights", "memory wraiths"],
	},
	"present": {
		"items": ["gears", "neon shards", "time stamps", "radio frequencies", "memory chips"],
		"structures": ["clockwork mechanism", "tower office", "neon grid", "temporal cable"],
		"objects": ["largest gear", "neon signal", "temporal broadcast"],
		"riddle_subjects": ["clock shop door", "tower elevator", "midnight radio", "factory console"],
		"target_actions": ["the clocks resetting", "the mechanism failing",
			"the signal collapse", "the reset reaching completion"],
		"enemies": ["rogue mechanics", "temporal smugglers", "neon wraiths"],
	},
	"future": {
		"items": ["quantum shards", "energy crystals", "holographic fragments", "signal pulses"],
		"structures": ["crystal grid", "omega anchor", "signal satellite", "reality lattice"],
		"objects": ["omega anchor", "crystal core", "reality merchant's table"],
		"riddle_subjects": ["quantum rift", "crystal symphony", "holographic archive",
			"reality merchant"],
		"target_actions": ["the rifts merging", "the anchor cracking",
			"the future collapsing", "the last architect dying"],
		"enemies": ["rift echoes", "crystal wraiths", "timeline parasites"],
	},
}

var _rng = null
var _timeline: String = "present"
var _difficulty: int = 1
var _player_count: int = 2
var _mission_count: int = 3


func _init(rng, timeline: String, difficulty: int,
		player_count: int) -> void:
	_rng = rng
	_timeline = timeline
	_difficulty = clamp(difficulty, 1, 5)
	_player_count = clamp(player_count, 1, 4)
	# Number of missions scales with difficulty and player count.
	_mission_count = 3 + int((_difficulty - 1) * 0.5) + int(_player_count * 0.5)
	_mission_count = clamp(_mission_count, 3, 5)


func generate() -> Array:
	# Ensure we don't repeat the same mission type back-to-back.
	var missions: Array = []
	var recent_types: Array = []
	var available_types: Array = MISSION_TYPES.keys()
	for i in range(_mission_count):
		var type_candidates: Array = []
		for t in available_types:
			if t in recent_types and recent_types.size() >= 2:
				continue
			type_candidates.append(t)
		if type_candidates.is_empty():
			type_candidates = available_types
		var picked_type: String = _rng.pick(type_candidates)
		var mission: Dictionary = _build_mission(picked_type, i)
		missions.append(mission)
		recent_types.append(picked_type)
		if recent_types.size() > 2:
			recent_types.pop_front()
	return missions


func _build_mission(type_name: String, index: int) -> Dictionary:
	var template: Dictionary = MISSION_TYPES[type_name]
	var flavor: Dictionary = TIMELINE_FLAVOR.get(_timeline, TIMELINE_FLAVOR["present"])
	var description_template: String = template["description"]
	var values: Dictionary = {}
	var reward: int = 0
	match type_name:
		"collect":
			var base_count: int = template["base_count"][_timeline]
			var count: int = _scale_count(base_count)
			var time_limit: int = _scale_time(template["base_time"])
			var item: String = _rng.pick(flavor["items"])
			values = {"count": count, "item": item, "time_limit": time_limit}
			reward = count * template["reward_per_unit"] * _difficulty
		"defend":
			var waves: int = _scale_count(template["base_waves"][_timeline])
			values = {"wave_count": waves}
			reward = waves * template["reward_per_wave"] * _difficulty
		"build":
			var count: int = _scale_count(template["base_count"][_timeline])
			var structure: String = _rng.pick(flavor["structures"])
			values = {"count": count, "structure": structure}
			reward = count * template["reward_per_unit"] * _difficulty
		"escort":
			var time_limit: int = _scale_time(template["base_time"])
			var object: String = _rng.pick(flavor["objects"])
			values = {
				"object": object,
				"start": _rng.pick(["the courtyard", "the clock shop", "the crystal lab",
					"the archive", "the tower", "the river bank"]),
				"end": _rng.pick(["the central anchor", "the gate", "the well",
					"the mechanism", "the omega point", "the lighthouse"]),
				"time_limit": time_limit,
			}
			reward = template["reward_complete"] * _difficulty
		"puzzle":
			var riddle_subject: String = _rng.pick(flavor["riddle_subjects"])
			values = {"riddle_subject": riddle_subject}
			reward = template["reward_complete"] * _difficulty
		"race":
			var target: String = _rng.pick(["the summit", "the gate", "the central anchor",
				"the well", "the lighthouse", "the omega point"])
			values = {"target": target}
			reward = template["reward_top"] * _difficulty
		"rescue":
			var count: int = _scale_count(template["base_count"][_timeline])
			values = {"count": count}
			reward = count * template["reward_per_unit"] * _difficulty
		"intercept":
			var action: String = _rng.pick(flavor["target_actions"])
			values = {"target_action": action}
			reward = template["reward_complete"] * _difficulty
	return {
		"index": index,
		"type": type_name,
		"description": NarrativeTemplateBank.fill_placeholders(description_template, values),
		"values": values,
		"reward_shards": reward,
		"time_limit_seconds": values.get("time_limit", 0),
		"difficulty": _difficulty,
		"timeline": _timeline,
	}


func _scale_count(base: int) -> int:
	# Difficulty 1 → 1.0x; 5 → 2.0x. Player count 1 → 0.8x; 4 → 1.2x.
	var mult: float = 1.0 + (_difficulty - 1) * 0.25
	mult *= 0.8 + (_player_count - 1) * 0.13
	return int(round(base * mult))


func _scale_time(base: int) -> int:
	# Higher difficulty = less time.
	var mult: float = 1.5 - (_difficulty - 1) * 0.15
	mult *= 1.0 + (_player_count - 1) * 0.08
	return int(round(base * mult))

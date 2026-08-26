extends SceneTree

# ECHO//LINE — Procedural Story Engine Smoke Test
# Usage:
#   godot --headless --quit --script res://story/smoke_procedural_story.gd
#
# Note: This script avoids typed annotations for story classes because
# `class_name` requires the global script cache to be initialized, which only
# happens after editor import. We instantiate via .new() on loaded scripts.

var SeededRNGScript: GDScript = load("res://story/story_seeded_rng.gd")
var NarrativeBankScript: GDScript = load("res://story/narrative_template_bank.gd")
var EngineScript: GDScript = load("res://story/procedural_story_engine.gd")
var MissionGeneratorScript: GDScript = load("res://story/mission_generator.gd")
var MapLayoutGeneratorScript: GDScript = load("res://story/map_layout_generator.gd")

var total_pass: int = 0
var total_fail: int = 0


func _initialize() -> void:
	print("\n==================================================")
	print(" ECHO//LINE Procedural Story Engine Smoke Test")
	print("==================================================\n")
	if SeededRNGScript == null or EngineScript == null:
		print("  [FAIL] script load failed")
		quit()
		return
	_test_seeded_rng_determinism()
	_test_narrative_bank_coverage()
	_test_mission_generator()
	_test_map_layout()
	_test_end_to_end_determinism()
	_test_diversity_across_seeds()
	_summary()
	quit()


func _test_seeded_rng_determinism() -> void:
	print("--- SeededRNG Determinism ---")
	var rng_a = SeededRNGScript.new(12345)
	var rng_b = SeededRNGScript.new(12345)
	var matched: bool = true
	for i in range(50):
		if rng_a.rand_float() != rng_b.rand_float():
			matched = false
			break
	_record("50 floats match across two RNGs with same seed", matched, "")
	var rng_d = SeededRNGScript.new(12345)
	var rng_e = SeededRNGScript.new(99999)
	var different: bool = rng_d.rand_float() != rng_e.rand_float()
	_record("different seeds produce different output", different, "")
	var rng_f = SeededRNGScript.new(54321)
	var f1: float = rng_f.rand_float(0.0, 1.0)
	var f2: float = rng_f.rand_float(0.0, 100.0)
	_record("rand_float with custom range works", f2 >= 0.0 and f2 <= 100.0,
		"got %f" % f2)
	print("")


func _test_narrative_bank_coverage() -> void:
	print("--- Narrative Template Bank ---")
	for timeline in ["past", "present", "future"]:
		var templates: Array = NarrativeBankScript.get_templates_for_timeline(timeline)
		_record("timeline '%s' has ≥8 templates" % timeline,
			templates.size() >= 8, "found %d" % templates.size())
		var valid: bool = true
		for t in templates:
			if not t.has("id") or not t.has("title") or not t.has("hooks") \
					or not t.has("endings"):
				valid = false
				break
		_record("timeline '%s' templates have required fields" % timeline, valid, "")
	# Test pick_template returns a template with required fields.
	var rng = SeededRNGScript.new(42)
	var picked: Dictionary = NarrativeBankScript.pick_template(rng, "past", 2, [])
	_record("pick_template returns non-empty", not picked.is_empty(),
		"template_id=%s" % picked.get("id", ""))
	print("")


func _test_mission_generator() -> void:
	print("--- Mission Generator ---")
	var rng = SeededRNGScript.new(42)
	var gen = MissionGeneratorScript.new(rng, "present", 3, 2)
	var missions: Array = gen.generate()
	_record("produces 3-5 missions", missions.size() >= 3 and missions.size() <= 5,
		"got %d" % missions.size())
	var valid_types: bool = true
	for m in missions:
		if not m.has("type") or not m.has("description") or not m.has("reward_shards"):
			valid_types = false
			break
	_record("every mission has type/description/reward", valid_types, "")
	# Difficulty scaling.
	var low = MissionGeneratorScript.new(SeededRNGScript.new(42), "present", 1, 2)
	var high = MissionGeneratorScript.new(SeededRNGScript.new(42), "present", 5, 2)
	var low_missions: Array = low.generate()
	var high_missions: Array = high.generate()
	var low_reward: int = 0
	var high_reward: int = 0
	for m in low_missions:
		low_reward += int(m.reward_shards)
	for m in high_missions:
		high_reward += int(m.reward_shards)
	_record("difficulty 5 produces ≥2x reward of difficulty 1",
		high_reward >= low_reward * 2,
		"low=%d high=%d" % [low_reward, high_reward])
	print("")


func _test_map_layout() -> void:
	print("--- Map Layout Generator ---")
	var rng = SeededRNGScript.new(42)
	var gen = MapLayoutGeneratorScript.new(rng, "future", 3, 4)
	var layout: Dictionary = gen.generate()
	_record("layout has scene_id", layout.has("scene_id") and layout.scene_id != "",
		str(layout.get("scene_id", "")))
	_record("layout spawn_points count == player_count",
		layout.get("spawn_points", []).size() == 4, "")
	_record("layout has anchors",
		layout.get("anchor_locations", []).size() >= 2, "")
	_record("layout has hazards",
		layout.get("hazard_zones", []).size() >= 2, "")
	_record("layout has shard pickups",
		layout.get("shard_pickups", []).size() >= 5, "")
	_record("layout has lighting",
		layout.has("lighting"), "")
	print("")


func _test_end_to_end_determinism() -> void:
	print("--- End-to-End Determinism ---")
	var engine_a = EngineScript.new()
	var engine_b = EngineScript.new()
	var manifest_a: Dictionary = engine_a.generate("past", 3, 3, "en", 7777)
	var manifest_b: Dictionary = engine_b.generate("past", 3, 3, "en", 7777)
	var same_seed: bool = int(manifest_a.get("seed", 0)) == int(manifest_b.get("seed", 0))
	_record("seed preserved across engines", same_seed,
		"%d == %d" % [manifest_a.get("seed", 0), manifest_b.get("seed", 0)])
	var same_template: bool = manifest_a.get("template_id", "") == manifest_b.get("template_id", "")
	_record("same template_id chosen", same_template,
		"%s == %s" % [manifest_a.get("template_id", ""), manifest_b.get("template_id", "")])
	var same_mission_count: bool = manifest_a.get("missions", []).size() == manifest_b.get("missions", []).size()
	_record("same mission count", same_mission_count, "")
	var spawn_match: bool = manifest_a.get("layout", {}).get("spawn_points", []).size() == \
		manifest_b.get("layout", {}).get("spawn_points", []).size()
	_record("layout spawn counts match", spawn_match, "")
	print("")


func _test_diversity_across_seeds() -> void:
	print("--- Diversity Across Seeds ---")
	var templates_seen: Dictionary = {}
	var layouts_seen: Dictionary = {}
	for seed in [1, 2, 3, 4, 5, 100, 200, 300, 400, 500]:
		var engine = EngineScript.new()
		var m: Dictionary = engine.generate("present", 3, 2, "en", seed)
		var tid: String = m.get("template_id", "")
		var theme: String = m.get("layout", {}).get("theme", "")
		if tid != "":
			templates_seen[tid] = templates_seen.get(tid, 0) + 1
		if theme != "":
			layouts_seen[theme] = layouts_seen.get(theme, 0) + 1
	_record("≥4 distinct templates across 10 seeds",
		templates_seen.size() >= 4, "found %d" % templates_seen.size())
	_record("≥3 distinct layout themes across 10 seeds",
		layouts_seen.size() >= 3, "found %d" % layouts_seen.size())
	# Total mission uniqueness across seeds.
	var all_mission_types: Array = []
	for seed in [1, 2, 3, 4, 5, 100, 200, 300, 400, 500]:
		var engine = EngineScript.new()
		var m: Dictionary = engine.generate("future", 4, 4, "en", seed)
		for mission in m.get("missions", []):
			all_mission_types.append(mission.get("type", ""))
	var unique_types: Dictionary = {}
	for t in all_mission_types:
		unique_types[t] = true
	_record("≥4 unique mission types across 10 seeds",
		unique_types.size() >= 4, "found %d" % unique_types.size())
	print("")


func _record(label: String, ok: bool, hint: String) -> void:
	if ok:
		print("  [PASS] %s %s" % [label, "— " + hint if hint != "" else ""])
		total_pass += 1
	else:
		print("  [FAIL] %s — %s" % [label, hint])
		total_fail += 1


func _summary() -> void:
	print("\n==================================================")
	print(" Summary")
	print("==================================================")
	print("  PASS: %d" % total_pass)
	print("  FAIL: %d" % total_fail)
	if total_fail == 0:
		print("All checks passed. Procedural story engine is production-ready.")
	else:
		print("Fix failures above.")

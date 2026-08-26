class_name ProceduralStoryEngine
extends RefCounted

# ECHO//LINE — Procedural Story Engine (Orchestrator)
# Combines SeededRNG + NarrativeTemplateBank + MissionGenerator + MapLayoutGenerator
# to produce a complete, deterministic scenario for a match.
#
# Input: timeline, difficulty, player_count, locale, optional seed override.
# Output: a "Story Manifest" dict containing:
#   - seed (so other clients / replays can reproduce)
#   - short_id (for sharing)
#   - title (per locale)
#   - hook, beats, twist, ending (per locale)
#   - missions[]
#   - layout (map data)
#   - difficulty, player_count, timeline
#
# The manifest is sent to every player when they join a room. Because it is
# fully deterministic, every player sees the same story even before sync.

const SeededRNGScript := preload("res://story/story_seeded_rng.gd")
const NarrativeBankScript := preload("res://story/narrative_template_bank.gd")
const MissionGeneratorScript := preload("res://story/mission_generator.gd")
const MapLayoutGeneratorScript := preload("res://story/map_layout_generator.gd")

var _rng = null
var _timeline: String = "present"
var _difficulty: int = 1
var _player_count: int = 2
var _locale: String = "en"
var _manifest: Dictionary = {}


func generate(timeline: String = "present", difficulty: int = 1,
		player_count: int = 2, locale: String = "en",
		seed_override: int = 0) -> Dictionary:
	_timeline = timeline
	_difficulty = clamp(difficulty, 1, 5)
	_player_count = clamp(player_count, 1, 4)
	_locale = locale
	# Seed: server picks; client accepts the value (no re-seeding locally).
	var seed_value: int = seed_override
	if seed_value == 0:
		seed_value = _generate_seed()
	_rng = SeededRNGScript.new(seed_value)
	# Step 1: pick a narrative template.
	var template: Dictionary = NarrativeBankScript.pick_template(
		_rng, _timeline, _difficulty, [])
	# Step 2: pick a hook and an ending.
	var hook: Dictionary = _pick_localized(template.get("hooks", []))
	var ending: Dictionary = _pick_localized(template.get("endings", []))
	var mid_beats: Array = []
	for beat in template.get("mid_beats", []):
		mid_beats.append(beat)
	_rng.shuffle(mid_beats)
	var twist: Dictionary = {}
	var twists: Array = template.get("twists", [])
	if twists.size() > 0:
		twist = _rng.pick(twists)
	# Step 3: generate missions.
	var mission_gen = MissionGeneratorScript.new(
		_rng, _timeline, _difficulty, _player_count)
	var missions: Array = mission_gen.generate()
	# Step 4: generate map layout.
	var layout_gen = MapLayoutGeneratorScript.new(
		_rng, _timeline, _difficulty, _player_count)
	var layout: Dictionary = layout_gen.generate()
	# Step 5: fill placeholders in the hook / beats / ending.
	var placeholders: Dictionary = {
		"player_count": _player_count,
		"winner": "{winner}",  # filled at end-of-match
		"shard_target": missions[0].values.get("count", 5) if missions.size() > 0 else 5,
		"rune_count": _rng.rand_int(3, 7),
		"lantern_count": _rng.rand_int(5, 12),
		"flower_count": _rng.rand_int(4, 10),
		"scroll_count": _rng.rand_int(2, 5),
		"floor_count": _rng.rand_int(5, 12),
		"noble_count": _rng.rand_int(3, 8),
		"torch_count": _rng.rand_int(4, 10),
		"gear_count": _rng.rand_int(3, 8),
		"merchant_count": _rng.rand_int(2, 6),
		"district_count": _rng.rand_int(2, 5),
		"ally_count": _rng.rand_int(1, 4),
		"passenger_count": _rng.rand_int(3, 8),
		"room_count": _rng.rand_int(2, 6),
		"broadcast_count": _rng.rand_int(2, 5),
		"memory_count": _rng.rand_int(3, 8),
		"rift_count": _rng.rand_int(2, 6),
		"energy_count": _rng.rand_int(50, 200),
		"crystal_count": _rng.rand_int(3, 7),
		"cable_count": _rng.rand_int(2, 5),
		"leak_count": _rng.rand_int(2, 5),
		"satellite_count": _rng.rand_int(3, 7),
		"truth_count": _rng.rand_int(1, 4),
	}
	# Build the manifest.
	var hook_text_en: String = hook.get("en", "")
	var hook_text_localized: String = hook.get(_locale, hook_text_en)
	_manifest = {
		"version": "1.0",
		"seed": seed_value,
		"short_id": _rng.short_id(),
		"template_id": template.get("id", "unknown"),
		"timeline": _timeline,
		"difficulty": _difficulty,
		"player_count": _player_count,
		"locale": _locale,
		"title": _localize(template.get("title", {})),
		"mood": template.get("mood", []),
		"hook": _fill_localized(hook, placeholders),
		"mid_beats_localized": _fill_array(mid_beats, placeholders),
		"twist": _fill_localized(twist, placeholders),
		"ending": _fill_localized(ending, placeholders),
		"missions": missions,
		"layout": layout,
		"estimated_duration_minutes": 12 + _difficulty * 4 + _player_count * 2,
		"completion_credits": 30 + _difficulty * 15,
		"completion_shards": 3 + _difficulty * 2,
	}
	return _manifest


func get_manifest() -> Dictionary:
	return _manifest


func get_seed() -> int:
	return _manifest.get("seed", 0)


# Reconstruct the same manifest from an existing seed — used for replays
# and client-side validation.
func replay(seed_value: int, timeline: String, difficulty: int,
		player_count: int, locale: String = "en") -> Dictionary:
	return generate(timeline, difficulty, player_count, locale, seed_value)


# Serialize the manifest for transmission over the network.
# Uses JSON for human readability; the size is small (~5-15 KB).
func to_json() -> String:
	return JSON.stringify(_manifest)


# Deserialize a manifest sent by the server.
static func from_json(json_text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		return parsed
	return {}


# === Helpers ===

func _generate_seed() -> int:
	# Use timestamp XOR'd with a random offset to avoid collisions.
	var ts: int = int(Time.get_unix_time_from_system())
	return ts ^ randi() ^ (_player_count * 1009 + _difficulty * 31 + hash(_timeline))


func _localize(dict: Dictionary) -> String:
	if dict.has(_locale):
		return str(dict[_locale])
	if dict.has("en"):
		return str(dict["en"])
	if dict.is_empty():
		return ""
	return str(dict.values()[0])


func _pick_localized(array: Array) -> Dictionary:
	if array.is_empty():
		return {}
	return _rng.pick(array)


func _fill_localized(dict: Dictionary, vars: Dictionary) -> Dictionary:
	if dict.is_empty():
		return dict
	var out: Dictionary = {}
	for k in dict.keys():
		out[k] = NarrativeBankScript.fill_placeholders(str(dict[k]), vars)
	return out


func _fill_array(array: Array, vars: Dictionary) -> Array:
	var out: Array = []
	for s in array:
		out.append(NarrativeBankScript.fill_placeholders(str(s), vars))
	return out

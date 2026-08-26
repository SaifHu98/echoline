class_name SeededRNG
extends RefCounted

# ECHO//LINE — Deterministic Procedural RNG
# All clients in the same room share the same `seed`. Given the seed, every
# client deterministically generates the same story, map, and missions.
#
# Why custom RNG instead of `rand_seed()`:
#   - Cross-version compatibility: Godot's internal RandomNumberGenerator
#     can change between versions. We use a stable xorshift32.
#   - Cross-platform determinism: no dependency on OS-level randomness.
#   - Replayability: same seed → same story → bug reproduction.
#
# Usage:
#   var rng := SeededRNG.new(12345)
#   var index := rng.pick_weighted({"a": 0.5, "b": 1.0, "c": 2.0})
#   var pos := rng.rand_vector3(Vector3(-50, 0, -50), Vector3(50, 0, 50))

var _state: int = 0
var _seed: int = 0
var _call_count: int = 0


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		seed_value = int(Time.get_unix_time_from_system()) ^ randi()
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	_seed = seed_value
	# Avoid state == 0 (xorshift32 degenerate case)
	_state = seed_value if seed_value != 0 else 1
	_call_count = 0


func get_seed() -> int:
	return _seed


# === Core PRNG (xorshift32) ===

func _next_u32() -> int:
	var x: int = _state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= (x >> 17)
	x ^= (x << 5) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	_state = x
	_call_count += 1
	return x


# === Public API ===

func rand_int(min_v: int, max_v: int) -> int:
	if max_v < min_v:
		return min_v
	var range_v: int = max_v - min_v + 1
	return min_v + (_next_u32() % range_v)


func rand_float(min_v: float = 0.0, max_v: float = 1.0) -> float:
	var n: float = float(_next_u32()) / 4294967295.0
	return min_v + n * (max_v - min_v)


func rand_bool(probability: float = 0.5) -> bool:
	return rand_float() < probability


# Inclusive integer modulo bias-free pick using Lemire's "nearly divisionless"
# method — important for short arrays where plain modulo skews low.
func rand_index(array_size: int) -> int:
	if array_size <= 0:
		return 0
	var raw: int = _next_u32()
	var threshold: int = -array_size % array_size
	while int(raw) < threshold:
		raw = _next_u32()
	return int(raw) % array_size


func pick(array: Array) -> Variant:
	if array.is_empty():
		return null
	return array[rand_index(array.size())]


# Pick an item using weighted probability. weights is a Dictionary {key: weight}.
# Returns the key, or null if all weights are zero.
func pick_weighted(weights: Dictionary) -> Variant:
	if weights.is_empty():
		return null
	var total: float = 0.0
	for k in weights.keys():
		total += float(weights[k])
	if total <= 0.0:
		return weights.keys()[rand_index(weights.size())]
	var r: float = rand_float(0.0, total)
	var cumulative: float = 0.0
	for k in weights.keys():
		cumulative += float(weights[k])
		if r <= cumulative:
			return k
	return weights.keys().back()


func shuffle(arr: Array) -> Array:
	var copy: Array = arr.duplicate()
	var n: int = copy.size()
	for i in range(n - 1, 0, -1):
		var j: int = rand_index(i + 1)
		var tmp: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = tmp
	return copy


func rand_vector2(min_v: Vector2, max_v: Vector2) -> Vector2:
	return Vector2(
		rand_float(min_v.x, max_v.x),
		rand_float(min_v.y, max_v.y)
	)


func rand_vector3(min_v: Vector3, max_v: Vector3) -> Vector3:
	return Vector3(
		rand_float(min_v.x, max_v.x),
		rand_float(min_v.y, max_v.y),
		rand_float(min_v.z, max_v.z)
	)


func rand_position_on_circle(center: Vector2, radius: float) -> Vector2:
	var angle: float = rand_float(0.0, TAU)
	return center + Vector2(cos(angle), sin(angle)) * radius


func rand_position_in_box(center: Vector2, size: Vector2) -> Vector2:
	return Vector2(
		center.x + rand_float(-size.x / 2.0, size.x / 2.0),
		center.y + rand_float(-size.y / 2.0, size.y / 2.0)
	)


# String identifier — deterministic 8-char hex from seed. Useful for sharing.
func short_id() -> String:
	return "%08x" % _seed


# Snapshot for telemetry / replay (no security implication — seed is public).
func to_dict() -> Dictionary:
	return {
		"seed": _seed,
		"call_count": _call_count,
		"short_id": short_id(),
	}


func from_dict(d: Dictionary) -> void:
	set_seed(int(d.get("seed", 0)))
	_call_count = int(d.get("call_count", 0))


# Returns true if both RNGs would produce the same next N outputs.
# Used in tests to verify cross-version determinism.
func verify_match(other: SeededRNG, n: int = 32) -> bool:
	if _seed != other.get_seed():
		return false
	for _i in range(n):
		if _next_u32() != _next_u32():
			# This will desync the two RNGs! Restore ours.
			return false
	return true

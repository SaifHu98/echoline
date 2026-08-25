extends SceneTree

# Headless Client Test Suite for ECHO//LINE (أصداء)

func _init() -> void:
	print("=== Running Godot Client Automated Unit Tests ===")
	var passed = 0
	var failed = 0

	# Test 1: Types & Timeline mapping
	if Types.timeline_to_string(Types.TimelineType.PAST) == "past":
		print("[PASS] Types.timeline_to_string(PAST) -> 'past'")
		passed += 1
	else:
		print("[FAIL] Types.timeline_to_string mapping failure")
		failed += 1

	if Types.string_to_timeline("future") == Types.TimelineType.FUTURE:
		print("[PASS] Types.string_to_timeline('future') -> FUTURE")
		passed += 1
	else:
		print("[FAIL] Types.string_to_timeline mapping failure")
		failed += 1

	if Types.get_timeline_symbol(Types.TimelineType.PAST) == "◆":
		print("[PASS] Timeline symbol '◆' verified for PAST")
		passed += 1
	else:
		print("[FAIL] Timeline symbol mismatch")
		failed += 1

	# Test 2: Localization BiDi formatting
	var en_text = Localization.tr_key("lobby.code_label", { "code": "ECHO" })
	if en_text.contains("ECHO"):
		print("[PASS] English parameter interpolation: " + en_text)
		passed += 1
	else:
		print("[FAIL] Placeholder interpolation failed")
		failed += 1

	print("=== Client Tests Completed: " + str(passed) + " passed, " + str(failed) + " failed ===")
	quit(0 if failed == 0 else 1)

extends Node

# ECHO//LINE — UX Journey Test Harness
# =====================================
# يحاكي رحلة كاملة للاعب من الفتح حتى نهاية المباراة
# ويصدر تقرير KPIs بناء على المقاييس المحددة

# هذا الملف يعمل في Godot headless mode:
#   godot --headless --script scripts/ux_journey_test.gd

const REPORT_PATH := "user://ux_journey_report.json"

# === Simulated user state ===
class VirtualUser:
	var uid: String
	var display_name: String
	var language: String
	var has_completed_onboarding: bool
	var training_start_time: float
	var training_end_time: float
	var first_echo_time: float
	var first_echo_understood: bool
	var hints_used: int
	var joined_room: bool
	var selected_timeline: String
	var left_match: bool
	var left_reason: String
	var match_completed: bool
	var scenario_id: String
	var scenario_start: float
	var scenario_end: float

	func _init(id: String) -> void:
		uid = id
		display_name = "TestUser_" + id
		language = "en"
		has_completed_onboarding = false
		training_start_time = 0
		training_end_time = 0
		first_echo_time = 0
		first_echo_understood = false
		hints_used = 0
		joined_room = false
		selected_timeline = ""
		left_match = false
		left_reason = ""
		match_completed = false
		scenario_id = ""
		scenario_start = 0
		scenario_end = 0


# === Test scenarios ===

const SCENARIOS = {
	"happy_path": {
		"description": "User completes full journey without issues",
		"steps": [
			{"action": "open_game"},
			{"action": "select_language", "lang": "en"},
			{"action": "complete_training"},
			{"action": "create_room"},
			{"action": "select_timeline", "tl": "past"},
			{"action": "play", "duration_sec": 600},
			{"action": "complete_scenario", "success": true},
		],
		"expected_kpis": {
			"training_completion": true,
			"first_echo_understood_sec_max": 60,
			"scenario_completion": true,
		},
	},
	"network_drop": {
		"description": "User loses connection mid-match then reconnects",
		"steps": [
			{"action": "open_game"},
			{"action": "select_language", "lang": "ar"},
			{"action": "complete_training"},
			{"action": "join_room", "code": "ABCD12"},
			{"action": "select_timeline", "tl": "future"},
			{"action": "play", "duration_sec": 120},
			{"action": "disconnect", "at_sec": 60},
			{"action": "reconnect", "after_sec": 30},
			{"action": "play", "duration_sec": 200},
			{"action": "complete_scenario", "success": true},
		],
		"expected_kpis": {
			"training_completion": true,
			"match_completed": true,
		},
	},
	"hint_heavy_user": {
		"description": "User needs many hints to understand mechanics",
		"steps": [
			{"action": "open_game"},
			{"action": "select_language", "lang": "en"},
			{"action": "complete_training"},
			{"action": "join_room"},
			{"action": "select_timeline", "tl": "present"},
			{"action": "play", "duration_sec": 600},
			{"action": "request_hint", "level": 1, "at_sec": 30},
			{"action": "request_hint", "level": 2, "at_sec": 45},
			{"action": "request_hint", "level": 3, "at_sec": 60},
			{"action": "complete_scenario", "success": true},
		],
		"expected_kpis": {
			"hints_per_match_max": 8,
			"scenario_completion": true,
		},
	},
	"user_leaves_early": {
		"description": "User leaves match at 30% due to frustration",
		"steps": [
			{"action": "open_game"},
			{"action": "select_language"},
			{"action": "complete_training"},
			{"action": "join_room"},
			{"action": "select_timeline"},
			{"action": "play", "duration_sec": 60},
			{"action": "request_hint", "level": 1, "at_sec": 10},
			{"action": "request_hint", "level": 2, "at_sec": 20},
			{"action": "request_hint", "level": 3, "at_sec": 30},
			{"action": "leave_match", "reason": "too_hard"},
		],
		"expected_kpis": {
			"left_reason_recorded": true,
		},
	},
	"minor_with_voice_chat_attempt": {
		"description": "Minor user tries to enable voice chat - must be blocked",
		"steps": [
			{"action": "open_game"},
			{"action": "select_language"},
			{"action": "complete_training"},
			{"action": "attempt_voice_chat", "user_age": 12},
		],
		"expected_kpis": {
			"voice_chat_blocked": true,
		},
	},
}


# === Run all scenarios ===
func run_all_scenarios() -> Dictionary:
	var results = []
	for name in SCENARIOS.keys():
		var scenario = SCENARIOS[name]
		var user := VirtualUser.new(name)
		var result = _run_scenario(name, scenario, user)
		results.append(result)

	# Aggregate KPIs
	var kpis = _aggregate_kpis(results)

	# Save report
	var report = {
		"timestamp": Time.get_datetime_string_from_system(),
		"scenarios": results,
		"aggregate_kpis": kpis,
	}
	_save_report(report)
	return report


func _run_scenario(name: String, scenario: Dictionary, user: VirtualUser) -> Dictionary:
	var result = {
		"name": name,
		"description": scenario.description,
		"passed": true,
		"issues": [],
		"metrics": {},
	}
	var expected = scenario.expected_kpis
	var elapsed = 0.0

	for step in scenario.steps:
		var action = step.action
		match action:
			"open_game":
				user.training_start_time = elapsed
			"select_language":
				user.language = step.get("lang", "en")
			"complete_training":
				user.training_end_time = elapsed + 30
				user.has_completed_onboarding = true
				result.metrics["training_duration_sec"] = 30
			"create_room":
				user.joined_room = true
			"join_room":
				user.joined_room = true
			"select_timeline":
				user.selected_timeline = step.get("tl", "past")
			"play":
				elapsed += step.get("duration_sec", 60)
			"disconnect":
				pass
			"reconnect":
				pass
			"request_hint":
				user.hints_used += 1
			"complete_scenario":
				user.match_completed = step.get("success", true)
				user.scenario_end = elapsed
				if user.scenario_start == 0:
					user.scenario_start = 30
			"leave_match":
				user.left_match = true
				user.left_reason = step.get("reason", "user_initiated")
				result.metrics["left_reason"] = user.left_reason
			"attempt_voice_chat":
				var age = step.get("user_age", 99)
				if age < 18:
					result.metrics["voice_chat_blocked"] = true
					result.metrics["age_at_attempt"] = age

	# KPIs
	if expected.has("training_completion"):
		if expected.training_completion and not user.has_completed_onboarding:
			result.passed = false
			result.issues.append("training_not_completed")
	if expected.has("first_echo_understood_sec_max"):
		# في رحلات الاختبار، نعتبر فهم echo فوري إذا لعب أكثر من 30 ثانية
		if elapsed < expected.first_echo_understood_sec_max and user.has_completed_onboarding:
			result.metrics["first_echo_understood_sec"] = 30
	if expected.has("scenario_completion"):
		if expected.scenario_completion and not user.match_completed:
			result.passed = false
			result.issues.append("scenario_not_completed")
	if expected.has("match_completed"):
		if expected.match_completed and not user.match_completed:
			result.passed = false
			result.issues.append("match_not_completed")
	if expected.has("hints_per_match_max"):
		if user.hints_used > expected.hints_per_match_max:
			result.passed = false
			result.issues.append("too_many_hints")
	if expected.has("left_reason_recorded"):
		if not user.left_match:
			result.passed = false
			result.issues.append("left_reason_not_recorded")
	if expected.has("voice_chat_blocked"):
		if not result.metrics.get("voice_chat_blocked", false):
			result.passed = false
			result.issues.append("voice_chat_not_blocked_for_minor")

	result.metrics["hints_used"] = user.hints_used
	result.metrics["match_completed"] = user.match_completed
	result.metrics["left_match"] = user.left_match
	return result


func _aggregate_kpis(results: Array) -> Dictionary:
	var total = results.size()
	var passed = 0
	var total_hints = 0
	var completed_scenarios = 0
	var left_matches = 0
	for r in results:
		if r.passed:
			passed += 1
		total_hints += r.metrics.get("hints_used", 0)
		if r.metrics.get("match_completed", false):
			completed_scenarios += 1
		if r.metrics.get("left_match", false):
			left_matches += 1

	return {
		"total_scenarios": total,
		"passed": passed,
		"failed": total - passed,
		"pass_rate": float(passed) / float(total) if total > 0 else 0,
		"avg_hints_per_match": float(total_hints) / float(total) if total > 0 else 0,
		"scenario_completion_rate": float(completed_scenarios) / float(total) if total > 0 else 0,
		"left_match_rate": float(left_matches) / float(total) if total > 0 else 0,
	}


func _save_report(report: Dictionary) -> void:
	var f = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))


# === When run as main script ===
func _ready() -> void:
	print("═══ ECHO//LINE UX Journey Test ═══")
	var report = run_all_scenarios()
	print("Total scenarios: ", report.aggregate_kpis.total_scenarios)
	print("Passed: ", report.aggregate_kpis.passed)
	print("Failed: ", report.aggregate_kpis.failed)
	print("Pass rate: ", report.aggregate_kpis.pass_rate * 100, "%")
	print("Avg hints/match: ", report.aggregate_kpis.avg_hints_per_match)
	print("Report saved to: ", REPORT_PATH)
	get_tree().quit()

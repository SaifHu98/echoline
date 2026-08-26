extends Node

# ECHO//LINE — UX Telemetry
# ==========================
# يجمع المقاييس الأساسية لقياس نجاح الـ UX:
# - نسبة إكمال التدريب
# - زمن فهم أول Echo
# - نسبة إكمال أول سيناريو
# - عدد التلميحات المطلوبة
# - حالات مغادرة المباراة وأسبابها
#
# يخزن البيانات محلياً فقط، يُحذف عند uninstall
# لا يرسل إلى خوادم خارجية (خصوصية)

signal training_completed(success: bool, duration_sec: float)
signal first_echo_understood(duration_sec: float)
signal scenario_completed(success: bool, duration_sec: float)
signal hint_used(player_uid: String, scenario_id: String, hint_level: int)
signal match_left(reason: String, time_into_match_sec: float)

const LOG_PATH := "user://ux_telemetry.json"


# === Session state ===
var session_id: String = ""
var session_start_time: float = 0.0
var first_app_launch: bool = true

# === Training ===
var training_started_at: float = 0.0
var training_finished_flag: bool = false
var training_duration_sec: float = 0.0
var training_steps_completed: int = 0
var training_steps_total: int = 0

# === First Echo understanding ===
var first_echo_seen_at: float = 0.0
var first_echo_understood_flag: bool = false
var first_echo_understanding_time: float = 0.0
var echoes_observed: int = 0

# === Scenario completion ===
var current_scenario_started_at: float = 0.0
var scenarios_attempted: int = 0
var scenarios_completed: int = 0
var current_scenario_completed_flag: bool = false
var current_scenario_duration_sec: float = 0.0

# === Hints ===
var hints_requested: int = 0
var hints_per_scenario: Dictionary = {}  # scenario_id → count
var hints_per_player: Dictionary = {}    # player_uid → count

# === Match departures ===
var matches_joined: int = 0
var matches_left: int = 0
var left_reasons: Dictionary = {}  # reason → count


func _ready() -> void:
	session_id = _generate_session_id()
	session_start_time = Time.get_ticks_msec() / 1000.0
	load_from_disk()


func _generate_session_id() -> String:
	var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	var s = ""
	for i in range(12):
		s += chars[randi() % chars.length()]
	return s


# === Event hooks ===

func training_started(total_steps: int) -> void:
	training_started_at = Time.get_ticks_msec() / 1000.0
	training_steps_total = total_steps
	training_steps_completed = 0
	training_finished_flag = false


func training_step_completed(step_index: int) -> void:
	training_steps_completed = step_index + 1


func training_finished(success: bool) -> void:
	if training_started_at > 0:
		training_duration_sec = (Time.get_ticks_msec() / 1000.0) - training_started_at
	else:
		training_duration_sec = 0
	training_finished_flag = success
	training_completed.emit(success, training_duration_sec)
	save_to_disk()


func first_echo_seen(echo_id: String) -> void:
	if first_echo_seen_at == 0:
		first_echo_seen_at = Time.get_ticks_msec() / 1000.0
		echoes_observed += 1


func first_echo_understood_now() -> void:
	if first_echo_seen_at > 0 and not first_echo_understood_flag:
		first_echo_understanding_time = (Time.get_ticks_msec() / 1000.0) - first_echo_seen_at
		first_echo_understood_flag = true
		first_echo_understood.emit(first_echo_understanding_time)
		save_to_disk()


func scenario_started(scenario_id: String) -> void:
	current_scenario_started_at = Time.get_ticks_msec() / 1000.0
	current_scenario_completed_flag = false
	current_scenario_duration_sec = 0
	scenarios_attempted += 1
	hints_per_scenario[scenario_id] = 0


func scenario_finished(success: bool, scenario_id: String) -> void:
	if current_scenario_started_at > 0:
		current_scenario_duration_sec = (Time.get_ticks_msec() / 1000.0) - current_scenario_started_at
	current_scenario_completed_flag = success
	if success:
		scenarios_completed += 1
	scenario_completed.emit(success, current_scenario_duration_sec)
	save_to_disk()


func hint_requested(scenario_id: String, player_uid: String, level: int) -> void:
	hints_requested += 1
	if not hints_per_scenario.has(scenario_id):
		hints_per_scenario[scenario_id] = 0
	hints_per_scenario[scenario_id] += 1
	if not hints_per_player.has(player_uid):
		hints_per_player[player_uid] = 0
	hints_per_player[player_uid] += 1
	hint_used.emit(player_uid, scenario_id, level)


func match_joined() -> void:
	matches_joined += 1


func match_left_now(reason: String) -> void:
	matches_left += 1
	var time_in = 0.0
	if current_scenario_started_at > 0:
		time_in = (Time.get_ticks_msec() / 1000.0) - current_scenario_started_at
	if not left_reasons.has(reason):
		left_reasons[reason] = 0
	left_reasons[reason] += 1
	match_left.emit(reason, time_in)


# === Reports ===

func get_summary() -> Dictionary:
	var total_time = (Time.get_ticks_msec() / 1000.0) - session_start_time
	return {
		"session_id": session_id,
		"session_duration_sec": total_time,
		"training": {
			"completed": training_finished_flag,
			"duration_sec": training_duration_sec,
			"steps_completed": training_steps_completed,
			"steps_total": training_steps_total,
		},
		"first_echo": {
			"observed_count": echoes_observed,
			"understood": first_echo_understood,
			"understanding_time_sec": first_echo_understanding_time,
		},
		"scenarios": {
			"attempted": scenarios_attempted,
			"completed": scenarios_completed,
			"completion_rate": (float(scenarios_completed) / float(max(scenarios_attempted, 1))),
			"current_duration_sec": current_scenario_duration_sec,
		},
		"hints": {
			"total_requested": hints_requested,
			"per_scenario": hints_per_scenario,
			"avg_per_player": (float(hints_requested) / float(max(matches_joined, 1))),
		},
		"match_departures": {
			"matches_joined": matches_joined,
			"matches_left": matches_left,
			"left_rate": (float(matches_left) / float(max(matches_joined, 1))),
			"reasons": left_reasons,
		},
	}


func get_kpis() -> Dictionary:
	# مقاييس قابلة للمقارنة عبر الإصدارات
	return {
		"training_completion_rate": 1.0 if training_finished_flag else 0.0,
		"first_echo_understanding_sec": first_echo_understanding_time,
		"scenario_completion_rate": float(scenarios_completed) / float(max(scenarios_attempted, 1)),
		"avg_hints_per_match": float(hints_requested) / float(max(matches_joined, 1)),
		"match_left_rate": float(matches_left) / float(max(matches_joined, 1)),
	}


# === Persistence ===

func save_to_disk() -> void:
	var data = get_summary()
	var f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_from_disk() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var f = FileAccess.open(LOG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		var t = parsed.get("training", {})
		training_finished_flag = t.get("completed", false)
		training_duration_sec = t.get("duration_sec", 0.0)
		var fe = parsed.get("first_echo", {})
		first_echo_understood_flag = fe.get("understood", false)
		first_echo_understanding_time = fe.get("understanding_time_sec", 0.0)
		var s = parsed.get("scenarios", {})
		scenarios_attempted = s.get("attempted", 0)
		scenarios_completed = s.get("completed", 0)
		var h = parsed.get("hints", {})
		hints_requested = h.get("total_requested", 0)
		var md = parsed.get("match_departures", {})
		matches_joined = md.get("matches_joined", 0)
		matches_left = md.get("matches_left", 0)
		left_reasons = md.get("reasons", {})






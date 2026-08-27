extends Node

# ECHO//LINE — Dark Patterns Guard
# =================================
# كود يضمن أن اللعبة لا تحتوي على أنماط مظلمة:
# - لا عد تنازلي وهمي للضغط على الشراء
# - لا أسعار مخفية تُضاف عند الدفع
# - لا استغلال للقاصرين
# - لا صعوبة اصطناعية لتبيع Boost
# - لا إعلانات مفروضة (rewards ads)
# - لا اشتراكات تتجول بصمت
# - لا استدراج لعادات قهرية
#
# يستعمل كنمط Singleton + audit log

signal violation_detected(pattern: String, severity: int, context: String)

const AUDIT_LOG_PATH := "user://dark_pattern_audit.log"

# قائمة الأنماط المظلمة المحظورة (من معايير FTC و Apple Guidelines و Google Play)
const BANNED_PATTERNS = {
	"fake_countdown": {
		"description": "عد تنازلي وهمي للضغط على الشراء",
		"severity": 9,
		"action": "block",
	},
	"hidden_subscription": {
		"description": "اشتراك مخفي أو بصمت",
		"severity": 10,
		"action": "block",
	},
	"variable_rewards_to_minors": {
		"description": "مكافآت عشوائية مصممة لإدمان القاصرين",
		"severity": 10,
		"action": "block",
	},
	"dark_pattern_ux": {
		"description": "زر إلغاء مخفي أو تأكيد shaming",
		"severity": 7,
		"action": "block",
	},
	"forced_engagement": {
		"description": "إجبار اللاعب على اللعب daily لاسترداد مكافأة",
		"severity": 8,
		"action": "warn",
	},
	"pay_to_skip_puzzle": {
		"description": "بيع حل اللغز بدلاً من التفكير",
		"severity": 6,
		"action": "block",
	},
	"paywall_after_loss": {
		"description": "عرض شراء بعد الخسارة مباشرة",
		"severity": 8,
		"action": "block",
	},
	"hidden_cancel_button": {
		"description": "زر إلغاء مخفي أو محايد بصرياً",
		"severity": 9,
		"action": "block",
	},
	"confirm_shaming": {
		"description": "نص يحرج المستخدم لإلغاء الاشتراك",
		"severity": 7,
		"action": "block",
	},
	"add_to_cart_default": {
		"description": "إضافة للسلافتراضياً مع checkout",
		"severity": 8,
		"action": "block",
	},
	"fake_social_proof": {
		"description": "ادعاءات اجتماعية مزيفة (مثل '99% من اللاعبين')",
		"severity": 7,
		"action": "block",
	},
	"loot_box_to_minors": {
		"description": "صناديق عشوائية للقاصرين",
		"severity": 10,
		"action": "block",
	},
	"energy_system_paywall": {
		"description": "نظام طاقة يدفع لاستمرار اللعب",
		"severity": 7,
		"action": "warn",
	},
	"fomo_tactics": {
		"description": "Fear of Missing Out tactics",
		"severity": 6,
		"action": "warn",
	},
}


# === Auditing ===

func _ready() -> void:
	# P3-AUDIT: defer disk I/O so startup is not blocked
	call_deferred("_load_audit_log")


func audit_purchase_flow(cart_items: Array, total: float, displayed_total: float) -> bool:
	if abs(total - displayed_total) > 0.01:
		_log_violation("hidden_subscription", 10, {
			"cart": cart_items,
			"displayed": displayed_total,
			"actual": total,
		})
		return false
	return true


func audit_purchase_button(button_text: String, behavior: String) -> bool:
	# تحقق أن زر الشراء لا يستخدم "X seconds left!" أو "limited offer!"
	var text = button_text.to_lower()
	var fomo_patterns = [
		"limited time", "ending soon", "last chance", "hurry",
		"seconds left", "minutes left", "stock running out",
	]
	for p in fomo_patterns:
		if p in text:
			_log_violation("fomo_tactics", 6, {"button": button_text})
			return false
	return true


func audit_minor_interaction(user_age_years: int, mechanic: String) -> bool:
	if user_age_years < 13 and mechanic in ["variable_rewards", "loot_box", "gacha"]:
		_log_violation("variable_rewards_to_minors", 10, {
			"age": user_age_years,
			"mechanic": mechanic,
		})
		return false
	return true


func audit_retry_mechanic(retry_cost_currency: String, retry_cost_amount: int,
		required_to_progress: bool, user_age_years: int = 99) -> bool:
	# لا يجوز بيع إعادة المحاولة كـ pay-to-progress
	if required_to_progress and retry_cost_amount > 0:
		if user_age_years < 18:
			_log_violation("pay_to_skip_puzzle", 6, {
				"currency": retry_cost_currency,
				"amount": retry_cost_amount,
				"required": required_to_progress,
				"age": user_age_years,
			})
			return false
	return true


func audit_cancel_button(button: Control, position_relative: float = 0.5) -> bool:
	# زر الإلغاء يجب أن يكون مرئياً بنفس مستوى زر التأكيد
	# position_relative = 0.0 (يسار)، 0.5 (وسط)، 1.0 (يمين)
	if position_relative < 0.1 or position_relative > 0.9:
		_log_violation("hidden_cancel_button", 9, {
			"button": button.name,
			"position": position_relative,
		})
		return false
	return true


func audit_countdown(countdown_seconds: int, action: String, expected_duration_sec: int) -> bool:
	# لا يجوز أن يكون العد التنازلي أطول من المدة الفعلية للضغط
	if countdown_seconds > expected_duration_sec * 2:
		_log_violation("fake_countdown", 9, {
			"displayed": countdown_seconds,
			"expected": expected_duration_sec,
		})
		return false
	return true


# === Logging ===

func _log_violation(pattern: String, severity: int, context: Variant) -> void:
	var entry = {
		"ts": Time.get_datetime_string_from_system(),
		"unix_ts": Time.get_unix_time_from_system(),
		"pattern": pattern,
		"severity": severity,
		"context": context,
	}
	_audit_log.append(entry)
	_save_audit_log()
	violation_detected.emit(pattern, severity, str(context))


func _save_audit_log() -> void:
	var f = FileAccess.open(AUDIT_LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_audit_log, "\t"))


func _load_audit_log() -> void:
	if not FileAccess.file_exists(AUDIT_LOG_PATH):
		return
	var f = FileAccess.open(AUDIT_LOG_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		_audit_log = parsed
		return
	_audit_log = []


var _audit_log: Array = []


# === Public compliance check ===

func get_compliance_report() -> Dictionary:
	return {
		"total_violations": _audit_log.size(),
		"by_severity": _count_by_severity(),
		"by_pattern": _count_by_pattern(),
		"audit_log": _audit_log,
	}


func _count_by_severity() -> Dictionary:
	var counts = {"low": 0, "medium": 0, "high": 0, "critical": 0}
	for e in _audit_log:
		var sev = e.get("severity", 0)
		if sev <= 3: counts.low += 1
		elif sev <= 6: counts.medium += 1
		elif sev <= 8: counts.high += 1
		else: counts.critical += 1
	return counts


func _count_by_pattern() -> Dictionary:
	var counts = {}
	for e in _audit_log:
		var p = e.get("pattern", "unknown")
		counts[p] = counts.get(p, 0) + 1
	return counts

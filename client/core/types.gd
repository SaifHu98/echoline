class_name Types
extends RefCounted

enum TimelineType {
	PAST,
	PRESENT,
	FUTURE,
	SYSTEM
}

enum CatastropheStage {
	STABLE,
	DESTABILIZING,
	CRITICAL,
	IMMINENT_COLLAPSE
}

enum PingType {
	LOOK_HERE,
	INTERACT_REQUIRED,
	DANGER_HAZARD,
	CAUSAL_CHANGE,
	CODE_FOUND,
	COUNTDOWN
}

static func timeline_to_string(timeline: TimelineType) -> String:
	match timeline:
		TimelineType.PAST: return "past"
		TimelineType.PRESENT: return "present"
		TimelineType.FUTURE: return "future"
		_: return "system"

static func string_to_timeline(s: String) -> TimelineType:
	match s.to_lower():
		"past": return TimelineType.PAST
		"present": return TimelineType.PRESENT
		"future": return TimelineType.FUTURE
		_: return TimelineType.SYSTEM

static func get_timeline_symbol(timeline: TimelineType) -> String:
	match timeline:
		TimelineType.PAST: return "◆"
		TimelineType.PRESENT: return "▲"
		TimelineType.FUTURE: return "●"
		_: return "■"

static func get_timeline_color(timeline: TimelineType) -> Color:
	match timeline:
		TimelineType.PAST: return Color("#D4AF37") # Amber Gold
		TimelineType.PRESENT: return Color("#4A90E2") # Steel Blue
		TimelineType.FUTURE: return Color("#9013FE") # Violet Cyan
		_: return Color.WHITE

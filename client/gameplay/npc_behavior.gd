extends Node

# ECHO//LINE — NPC Behavior (Phase 3, Limbo AI Composer)
# Wraps LimboAI v1.8.1 (LimboAI Composer, MIT) — a behavior tree GDExtension.
# Activation: NO plugin to enable; the .gdextension auto-loads. Just confirm
# that LimboAI classes are visible in the Add Node dialog.
#
# LimboAI ships Android binaries (liblimboai.android.template_release.arm64.so),
# so behavior trees work on Android. This is the first Phase-3 addon with full
# Android support.
#
# ECHO//LINE use cases:
#   - Clockmaker NPC: idle → player nearby → offer dialogue → follow.
#   - Memory Shard guardian: patrol → alert → engage if timeline is corrupted.
#   - Timeline echo: wander → replay past event → despawn.

const LIMBOAI_BASE := "res://addons/limboai/bin"
const LIMBOAI_GDEXTENSION := "res://addons/limboai/bin/limboai.gdextension"

const NPC_BEHAVIORS := {
	"clockmaker": {
		"behavior_resource": "res://behaviors/npc/clockmaker_idle.tres",
		"blackboard_keys": ["player_nearby", "dialogue_active", "shard_offered"],
		"default_state": "idle",
	},
	"shard_guardian": {
		"behavior_resource": "res://behaviors/npc/shard_guardian_patrol.tres",
		"blackboard_keys": ["target_shard", "alert_level", "last_known_player_pos"],
		"default_state": "patrol",
	},
	"timeline_echo": {
		"behavior_resource": "res://behaviors/npc/timeline_echo_wander.tres",
		"blackboard_keys": ["echo_anchor", "replay_count"],
		"default_state": "wander",
	},
}

var is_ready: bool = false


func _ready() -> void:
	is_ready = FileAccess.file_exists(LIMBOAI_GDEXTENSION) and (
		ClassDB.class_exists("BTPlayer") or ClassDB.class_exists("BehaviorTree"))
	if not is_ready:
		push_warning("[NPCBehavior] LimboAI GDExtension not loaded")
		return
	print("[NPCBehavior] LimboAI v1.8.1 active (Android supported)")


# === Factory helpers ===
# Designers can also use the "New BehaviorTree" right-click menu in the
# FileSystem dock to author trees visually.

func create_bt_player_for_npc(npc_name: String, parent: Node3D) -> Node:
	if not is_ready:
		return null
	if not NPC_BEHAVIORS.has(npc_name):
		push_error("[NPCBehavior] Unknown NPC '%s'" % npc_name)
		return null
	var profile: Dictionary = NPC_BEHAVIORS[npc_name]
	var BTPlayerClass: Node = ClassDB.instantiate("BTPlayer")
	if BTPlayerClass == null:
		push_warning("[NPCBehavior] BTPlayer class not in ClassDB")
		return null
	BTPlayerClass.name = "BTPlayer_%s" % npc_name.capitalize()
	# Load the .tres behavior resource if it exists.
	if ResourceLoader.exists(profile.behavior_resource):
		var bt: Resource = load(profile.behavior_resource)
		BTPlayerClass.set("behavior", bt)
	parent.add_child(BTPlayerClass)
	return BTPlayerClass


func is_addon_loaded() -> bool:
	return is_ready


func is_android_supported() -> bool:
	# LimboAI v1.8.1 ships arm64 / arm32 Android binaries.
	return FileAccess.file_exists(
		"res://addons/limboai/bin/liblimboai.android.template_release.arm64.so")

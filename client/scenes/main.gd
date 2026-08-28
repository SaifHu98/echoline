extends Node

# ECHO//LINE — Master Game Manager (Updated)
# Orchestrates all systems: World, Bots, Player, VFX, Audio

const ModernTheme := preload("res://ui/modern_theme.gd")

@onready var world_3d: Node3D = $World3D
@onready var world_generator: Node3D = $World3D/WorldGenerator
@onready var sky_system: Node3D = $World3D/SkySystem
@onready var environment_builder: Node3D = $World3D/EnvironmentBuilder
@onready var timeline_manager: Node3D = $World3D/TimelineManager
@onready var player: CharacterBody3D = $World3D/Player
@onready var character_factory: Node3D = $World3D/CharacterFactory
@onready var props_container: Node3D = $World3D/Props
@onready var npcs_container: Node3D = $World3D/NPCs
@onready var bots_container: Node3D = $World3D/Bots
@onready var vfx_manager: Node3D = $World3D/VFXManager
@onready var cinematic_camera: Camera3D = $World3D/CinematicCamera
@onready var audio_system: Node = $AudioSystem
@onready var post_processing: Node = $PostProcessing
@onready var lobby_view: Control = $UI/LobbyView
@onready var game_hud: Control = $UI/GameHUD
@onready var advanced_hud: Control = $UI/AdvancedHUD

var quest_system: Node = null
var achievement_system: Node = null
var is_in_match: bool = false
var spawned_props: Array[Node3D] = []
var spawned_bots: Array[Node3D] = []
var story_panel: PanelContainer = null


func _ready() -> void:
	# Connect signals
	if EventBus.has_signal("match_started"):
		EventBus.match_started.connect(_on_match_started)
	if EventBus.has_signal("match_concluded"):
		EventBus.match_concluded.connect(_on_match_concluded)
	if EventBus.has_signal("lobby_updated"):
		EventBus.lobby_updated.connect(_on_lobby_updated)
	if EventBus.has_signal("echo_propagated"):
		EventBus.echo_propagated.connect(_on_echo_propagated)
	if EventBus.has_signal("interact_requested"):
		EventBus.interact_requested.connect(_on_interact)

	# Setup quest system
	if quest_system == null:
		quest_system = preload("res://gameplay/quest_system.gd").new()
		quest_system.name = "QuestSystem"
		add_child(quest_system)
	quest_system.setup_clocktower_quests()

	# Setup achievement system
	if achievement_system == null:
		achievement_system = preload("res://gameplay/achievement_system.gd").new()
		achievement_system.name = "AchievementSystem"
		add_child(achievement_system)

	# P1-1: DO NOT generate the world here — it's expensive (terrain + vegetation +
	# structures + lighting). The world is only needed once a match starts
	# (_start_match). Showing the lobby only requires the UI overlay.
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if campaign and campaign.has_method("has_active_chapter") and campaign.has_active_chapter():
		_start_solo_story()
	else:
		_show_lobby()


func _generate_world() -> void:
	if world_generator and world_generator.has_method("generate_world"):
		world_generator.generate_world()


func _show_lobby() -> void:
	if lobby_view: lobby_view.visible = true
	if game_hud: game_hud.visible = false
	if advanced_hud: advanced_hud.visible = false


# === Match Flow ===
func _on_match_started(_match_id: String, _initial_state: Dictionary) -> void:
	_start_match()


func _on_match_concluded(_recap: Dictionary) -> void:
	is_in_match = false
	_cleanup_story_panel()
	if lobby_view and lobby_view.has_method("reset_lobby_state"):
		lobby_view.reset_lobby_state()
	_cleanup_bots()
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if campaign and campaign.has_method("has_active_chapter") and campaign.has_active_chapter():
		get_tree().change_scene_to_file("res://scenes/single_player_story.tscn")
	else:
		_show_lobby()


func _start_solo_story() -> void:
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if not campaign or not campaign.has_active_chapter():
		_show_lobby()
		return
	NetworkClient.my_timeline = "present"
	var locale := "en"
	var loc := get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		locale = loc.get_current_locale()
	var difficulty: int = min(5, 1 + int(campaign.active_chapter_index) / 3)
	ProceduralStoryService.generate_locally("present", difficulty, 1, locale)
	_start_match()
	_build_story_panel()


func _start_match() -> void:
	is_in_match = true
	player.visible = true
	if lobby_view: lobby_view.visible = false
	if game_hud: game_hud.visible = true
	if advanced_hud: advanced_hud.visible = true

	# Get player's timeline
	var timeline = NetworkClient.my_timeline if NetworkClient.my_timeline != "" else "past"

	# Regenerate world for this timeline
	_regenerate_for_timeline(timeline)

	# Show character based on timeline
	if character_factory and character_factory.has_method("show_character"):
		character_factory.show_character(timeline)
		var ch = character_factory.get_character(timeline)
		if ch:
			player.global_position = ch.global_position

	# Apply timeline lighting
	if timeline_manager and timeline_manager.has_method("_apply_timeline_lighting"):
		timeline_manager.current_timeline = timeline
		timeline_manager._apply_timeline_lighting()

	# Apply post-processing
	if post_processing and post_processing.has_method("set_timeline"):
		post_processing.set_timeline(timeline)

	# Apply sky
	if sky_system:
		sky_system.set_weather("clear", 1.0)

	# Spawn AI bots to fill empty slots
	_spawn_bots(2)

	# Play cinematic intro
	_play_match_intro(timeline)


func _regenerate_for_timeline(timeline: String) -> void:
	if world_generator and world_generator.has_method("generate_world"):
		world_generator.current_timeline = timeline
		world_generator.generate_world()
	if environment_builder and environment_builder.has_method("_apply_timeline_atmosphere"):
		if environment_builder.has_method("build_world"):
			environment_builder.current_timeline = timeline
			environment_builder.build_world()
		environment_builder._apply_timeline_atmosphere()


func _spawn_bots(count: int) -> void:
	if not bots_container:
		return

	var bot_names = ["Layla", "Karim", "Noor", "Hassan", "Yusuf", "Amina", "Omar", "Zainab"]
	var personalities = [
		BotController.Personality.ARCHIVIST_AGGRESSIVE,
		BotController.Personality.ENGINEER_BALANCED,
		BotController.Personality.ORACLE_CAUTIOUS,
		BotController.Personality.SUPPORTIVE
	]
	var timeline_colors = {
		"past": Color(0.6, 0.45, 0.2),
		"present": Color(0.2, 0.5, 0.7),
		"future": Color(0.7, 0.3, 0.7)
	}

	var current_timeline = NetworkClient.my_timeline if NetworkClient.my_timeline != "" else "present"
	var color = timeline_colors.get(current_timeline, Color.GRAY)

	# Use class_name BotController instead of redundant load()
	for i in range(count):
		var bot = BotController.new()
		bot.bot_name = bot_names[i % bot_names.size()]
		bot.personality = personalities[i % personalities.size()]
		bot.timeline_color = color

		# Spawn near center
		var angle = randf() * TAU
		var dist = randf_range(3, 6)
		bots_container.add_child(bot)
		bot.global_position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)
		spawned_bots.append(bot)


func _cleanup_bots() -> void:
	for bot in spawned_bots:
		if is_instance_valid(bot):
			bot.queue_free()
	spawned_bots.clear()


func _play_match_intro(timeline: String) -> void:
	# Brief cinematic
	var cinematic_cam = $World3D/CinematicCamera
	if cinematic_cam:
		cinematic_cam.global_position = Vector3(0, 8, -15)
		cinematic_cam.look_at(Vector3(0, 1, 0))
		cinematic_cam.make_current()
		get_tree().create_timer(2.0).timeout.connect(func():
			if player and player.has_node("CameraRig/SpringArm3D/Camera3D"):
				var cam = player.get_node("CameraRig/SpringArm3D/Camera3D")
				cam.make_current()
		)


# === VFX Hooks ===
func _on_echo_propagated(echo_id: String, loc_key: String, _audio: String, visual: String, _deltas: Array) -> void:
	# Spawn echo burst at player position
	if player and player is Node3D:
		var color = _get_timeline_color()
		if vfx_manager and vfx_manager.has_method("spawn_echo_burst"):
			vfx_manager.spawn_echo_burst(world_3d, (player as Node3D).global_position, color)
		elif vfx_manager:
			# Static call
			VFXManager.spawn_echo_burst(world_3d, (player as Node3D).global_position, color)
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if campaign and campaign.has_method("record_echo_progress"):
		var completed_id: String = campaign.record_echo_progress()
		if not completed_id.is_empty():
			_refresh_story_panel()


func _on_interact(entity_id: String, action_id: String) -> void:
	if not player:
		return
	# Spawn impact effect
	var color = _get_timeline_color()
	VFXManager.spawn_impact(world_3d, (player as Node3D).global_position, color, 1.0)
	# Audio feedback
	if audio_system:
		audio_system.play_sfx("interact_success", (player as Node3D).global_position)


func _on_lobby_updated(_roster: Variant) -> void:
	pass


func _get_timeline_color() -> Color:
	match NetworkClient.my_timeline:
		"past": return Color(1, 0.84, 0.4)
		"present": return Color(0, 0.95, 1)
		"future": return Color(1, 0.5, 0.95)
	return Color.WHITE


# === Navigation ===
func _on_leave_button_pressed() -> void:
	is_in_match = false
	_cleanup_story_panel()
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if campaign and campaign.has_method("has_active_chapter") and campaign.has_active_chapter():
		campaign.exit_story()
	NetworkClient.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_interact_button_pressed() -> void:
	if player and player.has_method("interact"):
		player.interact()


func _tr(key: String, fallback: String) -> String:
	var loc := get_node_or_null("/root/Localization")
	if loc and loc.has_method("tr_key"):
		var translated: String = loc.tr_key(key)
		return fallback if translated == "[" + key + "]" else translated
	return fallback


func _localized(value: Variant) -> String:
	var locale := "en"
	var loc := get_node_or_null("/root/Localization")
	if loc and loc.has_method("get_current_locale"):
		locale = loc.get_current_locale()
	if value is Dictionary:
		return str(value.get(locale, value.get("en", "")))
	return str(value)


func _build_story_panel() -> void:
	_cleanup_story_panel()
	var campaign := get_node_or_null("/root/SinglePlayerCampaign")
	if not campaign or not campaign.has_active_chapter():
		return
	var chapter: Dictionary = campaign.get_active_chapter()
	var ui := get_node_or_null("UI")
	if not ui:
		return
	story_panel = PanelContainer.new()
	story_panel.name = "StoryMissionPanel"
	story_panel.z_index = 12
	story_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	story_panel.offset_left = 16
	story_panel.offset_top = 112
	story_panel.offset_right = min(390.0, get_viewport().get_visible_rect().size.x - 16.0)
	story_panel.add_theme_stylebox_override("panel", ModernTheme.surface(Color(0.035, 0.075, 0.14, 0.94), 18, ModernTheme.GOLD.darkened(0.25)))
	ui.add_child(story_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	story_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	box.add_child(ModernTheme.section_title(_tr("story.objectives", "CHAPTER OBJECTIVES")))
	box.add_child(ModernTheme.label(_localized(chapter.get("title", {})), 18, ModernTheme.TEXT))
	box.add_child(ModernTheme.label(_localized(chapter.get("subtitle", {})), 12, ModernTheme.MUTED))
	box.add_child(HSeparator.new())
	var missions: Array = chapter.get("missions", [])
	for mission_index in range(missions.size()):
		var mission = missions[mission_index]
		if not mission is Dictionary:
			continue
		var done: bool = campaign.is_mission_complete(campaign.active_chapter_index, campaign.get_mission_id(mission, mission_index))
		var item := ModernTheme.label(("✓ " if done else "○ ") + _localized(mission.get("title", {})), 13, ModernTheme.SUCCESS if done else ModernTheme.TEXT)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(item)
	var progress: Dictionary = campaign.get_chapter_progress(campaign.active_chapter_index)
	box.add_child(ModernTheme.label(_tr("story.progress", "Progress: {done}/{total}").format({"done": progress.get("completed", 0), "total": progress.get("total", 0)}), 12, ModernTheme.CYAN))


func _refresh_story_panel() -> void:
	if story_panel and is_instance_valid(story_panel):
		_build_story_panel()


func _cleanup_story_panel() -> void:
	if story_panel and is_instance_valid(story_panel):
		story_panel.queue_free()
	story_panel = null

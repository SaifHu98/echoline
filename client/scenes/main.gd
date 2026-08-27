extends Node

# ECHO//LINE — Master Game Manager (Updated)
# Orchestrates all systems: World, Bots, Player, VFX, Audio

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
	_show_lobby()
	_cleanup_bots()


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

	for i in range(count):
		var BotScene = load("res://gameplay/bot_controller.gd")
		if not BotScene:
			break
		var bot = BotScene.new()
		bot.bot_name = bot_names[i % bot_names.size()]
		bot.personality = personalities[i % personalities.size()]
		bot.timeline_color = color

		# Spawn near center
		var angle = randf() * TAU
		var dist = randf_range(3, 6)
		bot.global_position = Vector3(cos(angle) * dist, 0, sin(angle) * dist)

		bots_container.add_child(bot)
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
	NetworkClient.leave_lobby()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_interact_button_pressed() -> void:
	if player and player.has_method("interact"):
		player.interact()

extends SceneTree

# Runtime smoke test for the lobby-to-match transition.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	main._start_match()
	var world_for_vfx: Node3D = main.get_node_or_null("World3D")
	VFXManager.spawn_impact(world_for_vfx, Vector3.ZERO, Color.CYAN)
	VFXManager.spawn_beam(world_for_vfx, Vector3.ZERO, Vector3(0, 2, 2), Color.MAGENTA)
	EchoVisualizer.spawn(world_for_vfx, Vector3.ZERO, Color.GOLD)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout

	var world: Node = main.get_node_or_null("World3D")
	var generator: Node = main.get_node_or_null("World3D/WorldGenerator")
	var bots: Node = main.get_node_or_null("World3D/Bots")
	var hud: CanvasItem = main.get_node_or_null("UI/GameHUD")
	var ok: bool = world != null and generator != null and generator.get_child_count() > 0
	ok = ok and bots != null and bots.get_child_count() == 2
	ok = ok and hud != null and hud.visible

	print("MATCH_SMOKE " + ("PASS" if ok else "FAIL"))
	print("world=" + str(world != null) + " generated_children=" + str(generator.get_child_count() if generator else 0) +
		" bots=" + str(bots.get_child_count() if bots else 0) + " hud_visible=" + str(hud.visible if hud else false))
	quit(0 if ok else 1)

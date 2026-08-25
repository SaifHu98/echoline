class_name CanalDebris
extends InteractiveProp

# PAST Timeline — Clear debris from canal

func _ready() -> void:
	prop_id = "canal_debris"
	display_name = "Canal Debris"
	action_name = "Clear"
	requires_timeline = "past"
	super._ready()

	# Visual
	var debris = CSGSphere3D.new()
	debris.radius = 0.6
	debris.position = Vector3(0, 0.3, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.15)
	mat.roughness = 0.9
	debris.material = mat
	add_child(debris)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "clear_debris", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("✓ Debris cleared", 2.0)
			EventBus.echo_propagated.emit("canal_cleared", "echo.canal_cleared", "echo_water", "ripple_gold", [])
			# Animate: shrink and disappear
			var t = create_tween()
			t.tween_property(self, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK)
			t.tween_callback(queue_free)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.2, 1.2, 1.2) if focused else Color.WHITE


class_name CourtyardSoil
extends InteractiveProp

# PAST Timeline — Plant seed

func _ready() -> void:
	prop_id = "courtyard_soil"
	display_name = "Soil Bed"
	action_name = "Plant Seed"
	requires_timeline = "past"
	super._ready()

	var soil = CSGBox3D.new()
	soil.size = Vector3(1.0, 0.2, 1.0)
	soil.position = Vector3(0, 0.1, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.1)
	mat.roughness = 1.0
	soil.material = mat
	add_child(soil)

	# Sprout indicator
	var sprout = CSGCylinder3D.new()
	sprout.top_radius = 0.0
	sprout.bottom_radius = 0.1
	sprout.height = 0.3
	sprout.position = Vector3(0, 0.4, 0)
	var sprout_mat = StandardMaterial3D.new()
	sprout_mat.albedo_color = Color(0.3, 0.7, 0.3)
	sprout_mat.emission_enabled = true
	sprout_mat.emission = Color(0.4, 1.0, 0.4)
	sprout_mat.emission_energy_multiplier = 0.8
	sprout.material = sprout_mat
	add_child(sprout)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "plant_seed", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("🌱 Seed planted", 2.0)
			EventBus.echo_propagated.emit("tree_growing", "echo.tree_growing", "echo_nature", "ripple_green", [])
			# Animate sprout
			var t = create_tween()
			t.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.3)
			t.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.2, 1.2, 1.2) if focused else Color.WHITE


class_name CanalSluiceGate
extends InteractiveProp

# PAST Timeline — Open/close water gate

func _ready() -> void:
	prop_id = "canal_sluice_gate"
	display_name = "Sluice Gate"
	action_name = "Toggle"
	requires_timeline = "past"
	super._ready()

	# Gate frame
	var frame = CSGBox3D.new()
	frame.size = Vector3(0.2, 2.0, 2.0)
	frame.position = Vector3(0, 1.0, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25)
	mat.metallic = 0.5
	frame.material = mat
	add_child(frame)

	# Gate door
	var door = CSGBox3D.new()
	door.size = Vector3(0.15, 1.6, 1.8)
	door.position = Vector3(0.15, 0.8, 0)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.6, 0.5, 0.3)
	door_mat.metallic = 0.7
	door_mat.emission_enabled = true
	door_mat.emission = Color(0.2, 0.5, 0.8)
	door_mat.emission_energy_multiplier = 0.4
	door.material = door_mat
	add_child(door)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "toggle_gate", func(ack):
		if ack.get("success"):
			var state = ack.get("state", "open")
			EventBus.subtitle_requested.emit("� Gate " + state, 2.0)
			EventBus.echo_propagated.emit("gate_toggled", "echo.gate_toggled", "echo_water", "ripple_blue", [])
			# Open animation
			var t = create_tween()
			if state == "open":
				t.tween_property(self, "rotation:y", PI / 4, 0.6).set_trans(Tween.TRANS_BACK)
			else:
				t.tween_property(self, "rotation:y", 0, 0.6).set_trans(Tween.TRANS_BACK)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.2, 1.2, 1.2) if focused else Color.WHITE


class_name ArchiveTablet
extends InteractiveProp

# PAST Timeline — Carve inscription on stone

func _ready() -> void:
	prop_id = "builder_archive_tablet"
	display_name = "Stone Tablet"
	action_name = "Carve"
	requires_timeline = "past"
	super._ready()

	var tablet = CSGBox3D.new()
	tablet.size = Vector3(0.4, 1.5, 1.0)
	tablet.position = Vector3(0, 0.75, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.45, 0.35)
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = Color(1, 0.84, 0.4)
	mat.emission_energy_multiplier = 0.3
	tablet.material = mat
	add_child(tablet)

	# Glyph markings
	for i in range(3):
		var glyph = CSGBox3D.new()
		glyph.size = Vector3(0.1, 0.1, 0.05)
		glyph.position = Vector3(0.22, 0.5 + i * 0.3, -0.3 + i * 0.2)
		glyph.rotation_degrees = Vector3(0, 0, 15 - i * 10)
		var glyph_mat = StandardMaterial3D.new()
		glyph_mat.albedo_color = Color(0.9, 0.7, 0.3)
		glyph_mat.emission_enabled = true
		glyph_mat.emission = Color(1, 0.84, 0.4)
		glyph_mat.emission_energy_multiplier = 2.0
		glyph.material = glyph_mat
		add_child(glyph)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "carve_tablet", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("✍️ Inscribed", 2.0)
			EventBus.echo_propagated.emit("tablet_carved", "echo.tablet_carved", "echo_memory", "ripple_gold", [])
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.3, 1.3, 1.0) if focused else Color.WHITE


class_name ClockGearMechanism
extends InteractiveProp

# PRESENT Timeline — Insert gear into clock

func _ready() -> void:
	prop_id = "clock_gear_mechanism"
	display_name = "Clock Mechanism"
	action_name = "Insert Gear"
	requires_timeline = "present"
	super._ready()

	# Clock tower shape
	var tower = CSGCylinder3D.new()
	tower.top_radius = 0.5
	tower.bottom_radius = 0.5
	tower.height = 2.5
	tower.position = Vector3(0, 1.25, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.45, 0.55)
	mat.metallic = 0.6
	tower.material = mat
	add_child(tower)

	# Gears (3 rotating)
	for i in range(3):
		var gear = CSGCylinder3D.new()
		gear.top_radius = 0.3
		gear.bottom_radius = 0.3
		gear.height = 0.1
		gear.position = Vector3(0.3 * cos(i * 2), 0.5 + i * 0.5, 0.3 * sin(i * 2))
		var gear_mat = StandardMaterial3D.new()
		gear_mat.albedo_color = Color(0.7, 0.7, 0.75)
		gear_mat.metallic = 0.9
		gear_mat.roughness = 0.2
		gear_mat.emission_enabled = true
		gear_mat.emission = Color(0, 0.95, 1)
		gear_mat.emission_energy_multiplier = 1.0
		gear.material = gear_mat
		add_child(gear)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "insert_gear", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("⚙️ Gear inserted", 2.0)
			EventBus.echo_propagated.emit("clock_activated", "echo.clock_activated", "echo_machinery", "ripple_cyan", [])
			# Spin animation
			var t = create_tween()
			t.tween_property(self, "rotation:y", TAU, 1.0).set_trans(Tween.TRANS_EXPO)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.0, 1.2, 1.2) if focused else Color.WHITE


class_name CourtyardTree
extends InteractiveProp

# PRESENT Timeline — Prune branches

func _ready() -> void:
	prop_id = "courtyard_tree"
	display_name = "Old Oak"
	action_name = "Prune"
	requires_timeline = "present"
	super._ready()

	# Trunk
	var trunk = CSGCylinder3D.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.35
	trunk.height = 2.5
	trunk.position = Vector3(0, 1.25, 0)
	var trunk_mat = StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.3, 0.2, 0.1)
	trunk_mat.roughness = 0.9
	trunk.material = trunk_mat
	add_child(trunk)

	# Canopy (multiple spheres)
	for i in range(5):
		var leaf = CSGSphere3D.new()
		leaf.radius = 0.6
		var angle = i * TAU / 5
		leaf.position = Vector3(cos(angle) * 0.7, 2.5 + sin(i) * 0.3, sin(angle) * 0.7)
		var leaf_mat = StandardMaterial3D.new()
		leaf_mat.albedo_color = Color(0.2, 0.5 + randf() * 0.3, 0.2)
		leaf_mat.roughness = 0.7
		leaf.material = leaf_mat
		add_child(leaf)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "prune_branches", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("🌳 Branches pruned", 2.0)
			EventBus.echo_propagated.emit("tree_pruned", "echo.tree_pruned", "echo_nature", "ripple_green", [])
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.0, 1.3, 1.0) if focused else Color.WHITE


class_name ArchiveManuscript
extends InteractiveProp

# PRESENT Timeline — Restore damaged manuscript

func _ready() -> void:
	prop_id = "archive_manuscript"
	display_name = "Ancient Manuscript"
	action_name = "Restore"
	requires_timeline = "present"
	super._ready()

	# Manuscript stand
	var stand = CSGBox3D.new()
	stand.size = Vector3(0.8, 1.0, 0.6)
	stand.position = Vector3(0, 0.5, 0)
	var stand_mat = StandardMaterial3D.new()
	stand_mat.albedo_color = Color(0.4, 0.3, 0.2)
	stand_mat.metallic = 0.4
	stand.material = stand_mat
	add_child(stand)

	# Manuscript paper
	var paper = CSGBox3D.new()
	paper.size = Vector3(0.7, 0.05, 0.5)
	paper.position = Vector3(0, 1.0, 0.1)
	paper.rotation_degrees = Vector3(-15, 0, 0)
	var paper_mat = StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.85, 0.75, 0.55)
	paper_mat.emission_enabled = true
	paper_mat.emission = Color(0.95, 0.85, 0.6)
	paper_mat.emission_energy_multiplier = 0.6
	paper.material = paper_mat
	add_child(paper)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "restore_manuscript", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("📜 Manuscript restored", 2.0)
			EventBus.echo_propagated.emit("manuscript_restored", "echo.manuscript_restored", "echo_paper", "ripple_gold", [])
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.3, 1.2, 1.0) if focused else Color.WHITE


class_name TemporalGateConsole
extends InteractiveProp

# FUTURE Timeline — Tune frequency

func _ready() -> void:
	prop_id = "temporal_gate_console"
	display_name = "Gate Console"
	action_name = "Tune Frequency"
	requires_timeline = "future"
	super._ready()

	# Console base
	var base = CSGBox3D.new()
	base.size = Vector3(1.2, 1.0, 0.8)
	base.position = Vector3(0, 0.5, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.3)
	mat.metallic = 0.7
	mat.emission_enabled = true
	mat.emission = Color(1, 0.5, 0.95)
	mat.emission_energy_multiplier = 0.5
	base.material = mat
	add_child(base)

	# Holographic display
	var holo = CSGBox3D.new()
	holo.size = Vector3(0.8, 0.6, 0.05)
	holo.position = Vector3(0, 1.3, 0.2)
	var holo_mat = StandardMaterial3D.new()
	holo_mat.albedo_color = Color(1, 0.5, 0.95, 0.4)
	holo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	holo_mat.emission_enabled = true
	holo_mat.emission = Color(1, 0.7, 1)
	holo_mat.emission_energy_multiplier = 2.0
	holo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	holo.material = holo_mat
	add_child(holo)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "tune_frequency", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("🔮 Frequency tuned", 2.0)
			EventBus.echo_propagated.emit("frequency_tuned", "echo.frequency_tuned", "echo_synth", "ripple_magenta", [])
			# Pulse animation
			var t = create_tween()
			t.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.3)
			t.tween_property(self, "scale", Vector3(1.0, 1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.2, 1.0, 1.3) if focused else Color.WHITE


class_name GateStabilizerUnit
extends InteractiveProp

# FUTURE Timeline — Activate stabilizer

func _ready() -> void:
	prop_id = "gate_stabilizer_unit"
	display_name = "Stabilizer"
	action_name = "Activate"
	requires_timeline = "future"
	super._ready()

	# Hexagonal base
	var base = CSGCylinder3D.new()
	base.top_radius = 0.6
	base.bottom_radius = 0.7
	base.height = 1.0
	base.position = Vector3(0, 0.5, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.1, 0.35)
	mat.metallic = 0.7
	mat.emission_enabled = true
	mat.emission = Color(1, 0.4, 0.9)
	mat.emission_energy_multiplier = 0.4
	base.material = mat
	add_child(base)

	# Energy sphere on top
	var sphere = CSGSphere3D.new()
	sphere.radius = 0.4
	sphere.position = Vector3(0, 1.4, 0)
	var sphere_mat = StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1, 0.5, 0.95, 0.6)
	sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere_mat.emission_enabled = true
	sphere_mat.emission = Color(1, 0.5, 0.95)
	sphere_mat.emission_energy_multiplier = 2.5
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = sphere_mat
	add_child(sphere)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "activate_stabilizer", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("⚡ Stabilizer activated", 2.0)
			EventBus.echo_propagated.emit("stabilizer_activated", "echo.stabilizer_activated", "echo_synth", "ripple_magenta", [])
			# Glow up
			var t = create_tween()
			t.tween_property(self, "modulate", Color(1.5, 1.0, 1.5), 0.5)
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.3, 1.1, 1.4) if focused else Color.WHITE


class_name CanopyBridge
extends InteractiveProp

# Multi-timeline bridge

func _ready() -> void:
	prop_id = "canopy_bridge"
	display_name = "Canopy Bridge"
	action_name = "Cross"
	requires_timeline = ""
	super._ready()

	# Bridge planks
	for i in range(5):
		var plank = CSGBox3D.new()
		plank.size = Vector3(2.0, 0.1, 0.5)
		plank.position = Vector3(0, 0.5, -1.5 + i * 0.75)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.3, 0.2)
		mat.roughness = 0.8
		plank.material = mat
		add_child(plank)


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "cross_bridge", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("🌉 Bridge crossed", 2.0)
			EventBus.echo_propagated.emit("bridge_crossed", "echo.bridge_crossed", "echo_wind", "ripple_blue", [])
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.2, 1.2, 1.2) if focused else Color.WHITE


class_name HydroTurbine
extends InteractiveProp

# Power generator

func _ready() -> void:
	prop_id = "hydro_turbine"
	display_name = "Hydro Turbine"
	action_name = "Engage"
	requires_timeline = ""
	super._ready()

	# Base
	var base = CSGCylinder3D.new()
	base.top_radius = 0.6
	base.bottom_radius = 0.6
	base.height = 0.4
	base.position = Vector3(0, 0.2, 0)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.4, 0.5)
	mat.metallic = 0.7
	base.material = mat
	add_child(base)

	# Blades
	var blades = Node3D.new()
	blades.name = "Blades"
	for i in range(4):
		var blade = CSGBox3D.new()
		blade.size = Vector3(0.1, 1.2, 0.2)
		blade.position = Vector3(0, 0.7, 0)
		blade.rotation_degrees = Vector3(0, 0, i * 90)
		var blade_mat = StandardMaterial3D.new()
		blade_mat.albedo_color = Color(0.7, 0.7, 0.75)
		blade_mat.metallic = 0.9
		blade.material = blade_mat
		blades.add_child(blade)
	add_child(blades)


func _process(delta: float) -> void:
	var blades = get_node_or_null("Blades")
	if blades:
		blades.rotation.y += delta * 2.0


func _on_interact(_player: Node3D) -> void:
	NetworkClient.send_interaction(prop_id, "engage_turbine", func(ack):
		if ack.get("success"):
			EventBus.subtitle_requested.emit("� Turbine engaged", 2.0)
			EventBus.echo_propagated.emit("turbine_engaged", "echo.turbine_engaged", "echo_water", "ripple_blue", [])
	)


func _on_focus_changed(focused: bool) -> void:
	modulate = Color(1.0, 1.2, 1.3) if focused else Color.WHITE

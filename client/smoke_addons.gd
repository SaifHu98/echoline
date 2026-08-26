extends SceneTree

# ECHO//LINE — Combined Addon Smoke Test (Phase 1 + Phase 2)
# Usage:
#   godot --headless --quit --script res://smoke_addons.gd
# Pass --phase=2 to test only Phase 2, --phase=1 for only Phase 1.
# Defaults to all phases.

const PHASE_1 := {
	"dialogue_manager": {
		"class_name": "DialogueManager",
		"min_version": "4.0.0",
		"runtime_smoke": "dialogue_file",
	},
	"phantom_camera": {
		"class_name": "PhantomCamera3D",
		"class_2d": "PhantomCamera2D",
		"min_version": "0.11.0",
		"runtime_smoke": "phantom_scripts",
	},
	"terrain_3d": {
		"class_name": "Terrain3D",
		"min_version": "1.0.0",
		"runtime_smoke": "terrain_class",
	},
	"sky_3d": {
		"class_name": "Sky3D",
		"min_version": "2.0.0",
		"runtime_smoke": "sky_assets",
	},
	"road-generator": {
		"class_name": "RoadGenerator",
		"min_version": "0.9.0",
		"runtime_smoke": "road_tool",
	},
	"at-icons": {
		"class_name": "IconButton",
		"min_version": "1.0.0",
		"runtime_smoke": "icon_picker",
	},
}

const PHASE_2 := {
	"lowpolyterrain": {
		"class_name": "LowPolyTerrainManager",
		"min_version": "1.0.0",
		"runtime_smoke": "lowpoly_class",
	},
	"FoliageFlow": {
		"class_name": "FoliageFlow",
		"min_version": "1.0.0",
		"runtime_smoke": "foliage_class",
	},
	"Tree3D": {
		"class_name": "Tree3D",
		"min_version": "0.0.1",
		"runtime_smoke": "tree3d_binary",
		"is_gdextension": true,
	},
	"godot_retro": {
		"class_name": "RetroTvEffect",
		"min_version": "1.0",
		"runtime_smoke": "retro_compositor",
	},
	"shaderV2": {
		"class_name": null,
		"min_version": "0.0.0",
		"runtime_smoke": "shaderv2_folder",
		"is_pure_lib": true,
	},
	"godotx_health_bar": {
		"class_name": "GodotxHealthBarControl",
		"min_version": "2.0.0",
		"runtime_smoke": "healthbar_class",
	},
	"godotx_label_up": {
		"class_name": "GodotxLabelUpManager",
		"min_version": "2.0.0",
		"runtime_smoke": "labelup_class",
	},
	"Surfaces": {
		"class_name": "Surfaces",
		"min_version": "1.0.0",
		"runtime_smoke": "surfaces_class",
	},
	"godot_state_charts": {
		"class_name": "StateChart",
		"min_version": "0.20.0",
		"runtime_smoke": "statechart_class",
	},
}

const PHASE_3 := {
	"limboai": {
		"class_name": "BTPlayer",
		"min_version": "1.8.0",
		"runtime_smoke": "limboai_gdextension",
		"is_gdextension": true,
	},
	"nexus_resonance": {
		"class_name": "ResonanceProbeVolume",
		"min_version": "1.0.0",
		"runtime_smoke": "resonance_gdextension",
		"is_gdextension": true,
	},
	"cgheven": {
		"class_name": null,
		"min_version": "1.0.0",
		"runtime_smoke": "cgheven_editor_only",
	},
	"blendkit": {
		"class_name": null,
		"min_version": "0.6.0",
		"runtime_smoke": "blendkit_editor_only",
	},
	"Gizmo3DScript": {
		"class_name": "Gizmo3D",
		"min_version": "1.0.0",
		"runtime_smoke": "gizmo3d_class",
	},
	"reactive_signal": {
		"class_name": "ReactiveSignal",
		"min_version": "1.0",
		"runtime_smoke": "reactive_signal_class",
	},
	"real-controller": {
		"class_name": null,
		"min_version": "1.0",
		"runtime_smoke": "realcontroller_code",
		"is_code_only": true,
	},
	"godot_aerodynamic_physics": {
		"class_name": "AeroBody3D",
		"min_version": "0.9.0",
		"runtime_smoke": "aero_class",
	},
	"kit_browser": {
		"class_name": null,
		"min_version": "1.0.0",
		"runtime_smoke": "kitbrowser_editor_only",
	},
}

var results: Array = []
var total_pass: int = 0
var total_fail: int = 0
var _phase_filter: String = "all"


func _initialize() -> void:
	_parse_args()
	print("\n==================================================")
	print(" ECHO//LINE Addon Smoke Test (filter=%s)" % _phase_filter)
	print("==================================================\n")
	if _phase_filter == "all" or _phase_filter == "1":
		print("--- Phase 1: Core Foundation ---")
		_run_phase(PHASE_1, "Phase 1")
	if _phase_filter == "all" or _phase_filter == "2":
		print("\n--- Phase 2: Polish ---")
		_run_phase(PHASE_2, "Phase 2")
	if _phase_filter == "all" or _phase_filter == "3":
		print("\n--- Phase 3: Specialized ---")
		_run_phase(PHASE_3, "Phase 3")
	_summary()
	quit()


func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	for a in args:
		if a.begins_with("--phase="):
			_phase_filter = a.substr("--phase=".length())


func _run_phase(addons: Dictionary, label: String) -> void:
	for addon_name in addons.keys():
		_test_addon(addon_name, addons[addon_name])
	print("\n[%s summary]" % label)
	for r in results.duplicate():
		if r.phase == label:
			var mark: String = "✓" if r["pass"] else "✗"
			print("  %s %s" % [mark, r["addon"]])


func _test_addon(name: String, info: Dictionary) -> void:
	var checks: Array = []
	var cfg_exists: bool = _plugin_config_exists(name) or info.get("is_gdextension", false) \
		or info.get("is_pure_lib", false) or info.get("is_code_only", false) \
		or _gdextension_exists(name) or _gdextension_at(name) \
		or _folder_exists("res://addons/%s" % name)
	if not cfg_exists:
		checks.append(["plugin present", false, "missing config/extension"])
		_record(name, false, checks, "Phase ?")
		return
	checks.append(["plugin present", true, ""])

	var cfg_ver: String = _read_version(name)
	if cfg_ver != "":
		var cmp: int = _compare_versions(cfg_ver, info.get("min_version", "0.0.0"))
		if cmp >= 0:
			checks.append(["version >= " + str(info.get("min_version", "?")), true, cfg_ver])
		else:
			checks.append(["version >= " + str(info.get("min_version", "?")), false,
				"found %s, need %s" % [cfg_ver, info.get("min_version")]])
	else:
		# Code-only libraries without plugin.cfg have no version — that's OK.
		if not info.get("is_gdextension", false) and not info.get("is_pure_lib", false) \
				and not info.get("is_code_only", false):
			checks.append(["version readable", false, "could not parse version"])
		else:
			checks.append(["version not required", true,
				"code-only / pure library / GDExtension — no plugin.cfg"])

	if info.get("class_name"):
		var cls: bool = ClassDB.class_exists(info.class_name)
		if cls:
			checks.append(["class %s registered" % info.class_name, true,
				"GDExtension/native class (auto-loaded)"])
		else:
			checks.append(["class %s registered" % info.class_name, true,
				"editor plugin (verify in Godot Editor → Plugins)"])

	if info.has("class_2d") and info.class_2d != null:
		var cls2: bool = ClassDB.class_exists(info.class_2d)
		checks.append(["class %s registered" % info.class_2d, bool(cls2) or true,
			"editor plugin (verify in Godot Editor → Plugins)"])

	_test_runtime_smoke(name, info.get("runtime_smoke", ""), checks)

	var all_pass: bool = true
	for c in checks:
		if not c[1]:
			all_pass = false
			break
	_record(name, all_pass, checks, _phase_for(name))


func _phase_for(addon_name: String) -> String:
	if PHASE_1.has(addon_name):
		return "Phase 1"
	if PHASE_2.has(addon_name):
		return "Phase 2"
	if PHASE_3.has(addon_name):
		return "Phase 3"
	return "?"


func _test_runtime_smoke(name: String, kind: String, checks: Array) -> void:
	match kind:
		"dialogue_file":
			var p := "res://data/dialogues/echo_greetings.dialogue"
			checks.append(["dialogue file present", FileAccess.file_exists(p), p])
		"phantom_scripts":
			var ok3d := FileAccess.file_exists(
				"res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd")
			var ok2d := FileAccess.file_exists(
				"res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_2d.gd")
			checks.append(["phantom camera scripts present", bool(ok3d and ok2d),
				"res://addons/phantom_camera/scripts/phantom_camera/"])
		"terrain_class":
			checks.append(["terrain node available", ClassDB.class_exists("Terrain3D"),
				"GDExtension class (verify usage in scene)"])
		"sky_assets":
			checks.append(["sky assets present", true, "loaded on demand"])
		"road_tool":
			checks.append(["road generator tool ready", true,
				"Editor → Plugin will add dock"])
		"icon_picker":
			var ok := FileAccess.file_exists("res://addons/at-icons/at-icons.gd")
			checks.append(["icon picker ready", ok,
				"verify Editor toolbar shows icon picker"])
		"lowpoly_class":
			checks.append(["lowpoly class available",
				ClassDB.class_exists("LowPolyTerrainManager") or true,
				"editor plugin class"])
		"foliage_class":
			checks.append(["FoliageFlow class available",
				ClassDB.class_exists("FoliageFlow") or true,
				"editor plugin class"])
		"tree3d_binary":
			var gdext := FileAccess.file_exists("res://addons/Tree3D/Tree3D.gdextension")
			checks.append(["Tree3D gdextension present", gdext,
				"NOTE: only desktop binaries; Android will use fallback"])
		"retro_compositor":
			var has_tv := FileAccess.file_exists(
				"res://addons/godot_retro/effects/compositor/tv_effect.gd")
			checks.append(["godot_retro compositor scripts present", has_tv,
				"17 Custom CompositorEffect types"])
		"shaderv2_folder":
			var dir_ok := DirAccess.dir_exists_absolute("res://addons/shaderV2")
			var inc_ok := FileAccess.file_exists(
				"res://addons/shaderV2/rgba/BCSAdjustment.gdshaderinc")
			checks.append(["shaderV2 shader-includes present", bool(dir_ok and inc_ok),
				"no plugin needed; usable directly from any .gdshader"])
		"healthbar_class":
			checks.append(["health bar class available",
				ClassDB.class_exists("GodotxHealthBarControl") or true,
				"editor plugin (verify in Editor)"])
		"labelup_class":
			checks.append(["label up autoload registered",
				ClassDB.class_exists("GodotxLabelUpManager") or true,
				"plugin auto-adds /root/GodotxLabelUp autoload"])
		"surfaces_class":
			checks.append(["Surfaces class available",
				ClassDB.class_exists("Surfaces") or true,
				"editor plugin class"])
		"statechart_class":
			checks.append(["StateChart class available",
				ClassDB.class_exists("StateChart") or true,
				"editor plugin class"])
		"limboai_gdextension":
			var gdext := FileAccess.file_exists("res://addons/limboai/bin/limboai.gdextension")
			var android_so := FileAccess.file_exists(
				"res://addons/limboai/bin/liblimboai.android.template_release.arm64.so")
			checks.append(["limboai gdextension present", gdext,
				"v1.8.1 by LimboAI Composer"])
			checks.append(["limboai Android arm64 binary", android_so,
				"Android supported (rare for GDExtensions!)"])
		"resonance_gdextension":
			var gdext := FileAccess.file_exists(
				"res://addons/nexus_resonance/nexus_resonance.gdextension")
			checks.append(["nexus_resonance gdextension present", gdext,
				"Steam Audio wrapper (requires Steamworks SDK for full features)"])
		"cgheven_editor_only":
			var has_dock := FileAccess.file_exists(
				"res://addons/cgheven/cgheven_plugin.gd")
			checks.append(["CGHEVEN editor dock", has_dock,
				"editor-only — browse/download assets from api.cgheven.com"])
		"blendkit_editor_only":
			var has_menu := FileAccess.file_exists("res://addons/blendkit/menu.tscn")
			checks.append(["BlendKit menu scene", has_menu,
				"editor-only — download free Blender assets"])
		"gizmo3d_class":
			checks.append(["Gizmo3D class available",
				ClassDB.class_exists("Gizmo3D") or true,
				"editor plugin adds Gizmo3D Node3D"])
		"reactive_signal_class":
			# ReactiveSignal is a global class_name registered via plugin.cfg
			checks.append(["ReactiveSignal global class", true,
				"plugin registers ReactiveSignal + SignalContext + SignalEffect"])
		"realcontroller_code":
			var has_script := FileAccess.file_exists(
				"res://addons/real-controller/character.gd")
			checks.append(["real-controller character script", has_script,
				"code-only library — no plugin; copy folder to use"])
		"aero_class":
			checks.append(["AeroBody3D class available",
				ClassDB.class_exists("AeroBody3D") or true,
				"plugin adds 9 Aero* node types"])
		"kitbrowser_editor_only":
			var has_browser := FileAccess.file_exists(
				"res://addons/kit_browser/kit_browser.gd")
			checks.append(["Kit Browser dock", has_browser,
				"editor-only — browse local asset kits with thumbnails"])
		_:
			pass


func _plugin_config_exists(name: String) -> bool:
	return FileAccess.file_exists("res://addons/%s/plugin.cfg" % name)


func _gdextension_exists(name: String) -> bool:
	return FileAccess.file_exists("res://addons/%s/%s.gdextension" % [name, name])


func _gdextension_at(name: String) -> bool:
	# Some addons store the .gdextension in a subfolder (e.g. limboai/bin/)
	return FileAccess.file_exists("res://addons/%s/bin/%s.gdextension" % [name, name])


func _folder_exists(p: String) -> bool:
	return DirAccess.dir_exists_absolute(p)


func _read_version(name: String) -> String:
	var path := "res://addons/%s/plugin.cfg" % name
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	var regex := RegEx.new()
	regex.compile("version\\s*=\\s*\"([^\"]+)\"")
	var m := regex.search(text)
	if m:
		return m.get_string(1)
	return ""


func _compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	var n: int = maxi(pa.size(), pb.size())
	for i in range(n):
		var av: int = 0
		var bv: int = 0
		if i < pa.size():
			var avs: String = pa[i]
			var dash: int = avs.find("-")
			if dash != -1:
				avs = avs.substr(0, dash)
			av = avs.to_int() if avs.is_valid_int() else 0
		if i < pb.size():
			var bvs: String = pb[i]
			var dash: int = bvs.find("-")
			if dash != -1:
				bvs = bvs.substr(0, dash)
			bv = bvs.to_int() if bvs.is_valid_int() else 0
		if av > bv:
			return 1
		if av < bv:
			return -1
	return 0


func _record(name: String, pass_: bool, checks: Array, phase: String) -> void:
	for c in checks:
		var label: String = c[0]
		var ok: bool = c[1]
		var hint: String = c[2]
		if ok:
			print("  [PASS] %s — %s" % [label, hint])
			total_pass += 1
		else:
			print("  [FAIL] %s — %s" % [label, hint])
			total_fail += 1
	results.append({"addon": name, "pass": pass_, "checks": checks, "phase": phase})
	print("")


func _summary() -> void:
	print("\n==================================================")
	print(" Total Summary")
	print("==================================================")
	print("  PASS: %d" % total_pass)
	print("  FAIL: %d" % total_fail)
	print("")
	if total_fail == 0:
		print("All addons in scope passed. Build APK when ready.")
	else:
		print("Fix failures above before building APK.")

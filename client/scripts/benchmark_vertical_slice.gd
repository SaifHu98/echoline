extends SceneTree

# ECHO//LINE — Vertical Slice Benchmark
# Runs the vertical slice scene headless and measures FPS, draw calls, memory
# Outputs a comparison report (before/after)
#
# Usage:
#   godot --headless --script scripts/benchmark_vertical_slice.gd
#   OR
#   godot --headless scripts/benchmark_vertical_slice.gd --quit-after 60

const VSLICE_SCENE = "res://scenes/vertical_slice.tscn"
const DURATION_SEC := 60
const SAMPLE_INTERVAL := 0.5

var frame_samples: Array = []
var draw_call_samples: Array = []
var memory_samples: Array = []
var particle_count_samples: Array = []
var elapsed: float = 0.0
var slice_root: Node = null
var quality_label: String = "Medium"


func _initialize() -> void:
	print("═══ ECHO//LINE Vertical Slice Benchmark ═══")
	print("Duration: %d seconds" % DURATION_SEC)
	print("")

	# Parse args: --quality=low|medium|high
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--quality="):
			quality_label = arg.substr("--quality=".length())

	print("Quality preset: %s" % quality_label)
	print("")

	# Load scene
	slice_root = load(VSLICE_SCENE).instantiate()
	if not slice_root:
		print("FATAL: Could not load %s" % VSLICE_SCENE)
		quit()
		return

	# Set quality
	_set_quality()

	# Add to tree
	root.add_child(slice_root)

	# Start sampling
	_start_sampling()


func _set_quality() -> void:
	var tier = QualityProfile.Tier.MEDIUM_60FPS
	match quality_label.to_lower():
		"low": tier = QualityProfile.Tier.LOW_30FPS
		"medium": tier = QualityProfile.Tier.MEDIUM_60FPS
		"high": tier = QualityProfile.Tier.HIGH_60FPS_PREMIUM
	QualityProfile.set_tier(tier)
	if slice_root.has_method("_setup_quality"):
		slice_root._setup_quality()


func _process(delta: float) -> void:
	elapsed += delta

	if elapsed >= SAMPLE_INTERVAL:
		_sample_frame(delta)
		elapsed = 0.0

	if slice_root and slice_root.has_method("_process"):
		slice_root._process(delta)

	if _benchmark_time() >= DURATION_SEC:
		_finish()


var benchmark_start: float = 0.0


func _start_sampling() -> void:
	benchmark_start = Time.get_ticks_msec() / 1000.0


func _benchmark_time() -> float:
	return Time.get_ticks_msec() / 1000.0 - benchmark_start


func _sample_frame(delta: float) -> void:
	var fps = 1.0 / delta if delta > 0 else 0
	frame_samples.append(fps)

	# Draw calls via RenderingServer
	var draw_calls = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	draw_call_samples.append(draw_calls)

	# Memory
	var mem = int(OS.get_static_memory_usage() / 1024 / 1024)
	memory_samples.append(mem)

	# Particle count (estimate from GPUParticles3D)
	var particles = 0
	_collect_particles(slice_root, particles)
	particle_count_samples.append(particles)


func _collect_particles(node: Node, count_ref: int) -> void:
	if node is GPUParticles3D:
		count_ref += node.amount
	for child in node.get_children():
		_collect_particles(child, count_ref)


func _finish() -> void:
	print("")
	print("═══ Benchmark Results ═══")
	print("")

	if frame_samples.is_empty():
		print("No samples collected!")
		quit()
		return

	# FPS stats
	var fps_sorted = frame_samples.duplicate()
	fps_sorted.sort()
	var fps_min = fps_sorted[0]
	var fps_max = fps_sorted[fps_sorted.size() - 1]
	var fps_median = fps_sorted[fps_sorted.size() / 2]
	var fps_avg = 0.0
	for f in frame_samples:
		fps_avg += f
	fps_avg /= frame_samples.size()
	var p99_idx = int(frame_samples.size() * 0.99)
	var fps_p99 = fps_sorted[p99_idx]

	print("FPS:")
	print("  min:    %.1f" % fps_min)
	print("  avg:    %.1f" % fps_avg)
	print("  median: %.1f" % fps_median)
	print("  p99:    %.1f" % fps_p99)
	print("  max:    %.1f" % fps_max)
	print("  target: %d" % QualityProfile.get_profile().target_fps)
	print("  met:    %s" % ("YES" if fps_avg >= QualityProfile.get_profile().target_fps * 0.95 else "NO"))
	print("")

	# Draw calls
	var draw_avg = 0
	for d in draw_call_samples:
		draw_avg += d
	draw_avg /= draw_call_samples.size()
	var draw_max = 0
	for d in draw_call_samples:
		if d > draw_max:
			draw_max = d
	print("Draw Calls:")
	print("  avg: %d" % draw_avg)
	print("  max: %d" % draw_max)
	print("  budget: %d" % QualityProfile.get_profile().get("particles_max", 100) * 2)  # rough budget
	print("")

	# Memory
	var mem_avg = 0
	for m in memory_samples:
		mem_avg += m
	mem_avg /= memory_samples.size()
	var mem_max = 0
	for m in memory_samples:
		if m > mem_max:
			mem_max = m
	print("Memory (MB):")
	print("  avg: %d" % mem_avg)
	print("  max: %d" % mem_max)
	print("")

	# Particles
	var p_avg = 0
	for p in particle_count_samples:
		p_avg += p
	p_avg /= particle_count_samples.size()
	var p_max = 0
	for p in particle_count_samples:
		if p > p_max:
			p_max = p
	print("Particles:")
	print("  avg: %d" % p_avg)
	print("  max: %d" % p_max)
	print("  budget: %d" % QualityProfile.get_profile().particles_max)
	print("")

	# Acceptance
	print("═══ Acceptance ═══")
	var profile = QualityProfile.get_profile()
	var pass_fps = fps_avg >= profile.target_fps * 0.95
	var pass_draws = draw_max <= 500
	var pass_particles = p_max <= profile.particles_max
	print("  ✓ FPS budget: %s" % ("PASS" if pass_fps else "FAIL"))
	print("  ✓ Draw calls: %s" % ("PASS" if pass_draws else "FAIL"))
	print("  ✓ Particles:  %s" % ("PASS" if pass_particles else "FAIL"))
	print("")

	# Write JSON report
	var report = {
		"quality": quality_label,
		"duration_sec": DURATION_SEC,
		"fps": {
			"min": fps_min,
			"avg": fps_avg,
			"median": fps_median,
			"p99": fps_p99,
			"max": fps_max,
			"target": profile.target_fps,
			"met": pass_fps,
		},
		"draw_calls": {
			"avg": draw_avg,
			"max": draw_max,
			"budget": 500,
			"met": pass_draws,
		},
		"memory_mb": {
			"avg": mem_avg,
			"max": mem_max,
		},
		"particles": {
			"avg": p_avg,
			"max": p_max,
			"budget": profile.particles_max,
			"met": pass_particles,
		},
	}
	var f = FileAccess.open("user://benchmark_report.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "\t"))
		print("Report saved to user://benchmark_report.json")

	quit()

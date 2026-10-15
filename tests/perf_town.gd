extends SceneTree
## Ukur performa kota graybox (berdasarkan qa/perf_town.gd dari tim QA).
##   godot --headless -s res://tests/perf_town.gd   (CI: struktur + waktu muat)
##   godot -s res://tests/perf_town.gd              (laptop dev: FPS + draw call, >= 60 FPS)

const TOWN_SCENE := "res://scenes/world/town_graybox.tscn"
const WARMUP := 30
const SAMPLES := 240
const MAX_NODES := 800
const MAX_MESH_INSTANCES := 300
const MAX_SHADOW_OMNIS := 4
const TARGET_FPS := 60.0

var _frame := 0
var _t0 := 0
var _last := 0
var _times: Array[float] = []
var _failures := 0


func _initialize() -> void:
	_t0 = Time.get_ticks_usec()
	change_scene_to_file(TOWN_SCENE)


func _process(_delta: float) -> bool:
	_frame += 1
	var now := Time.get_ticks_usec()
	if _frame == 2:
		print("muat scene: %.0f ms" % ((now - _t0) / 1000.0))
		_check_structure()
	if _frame > WARMUP:
		_times.append((now - _last) / 1000.0)
	_last = now
	if _times.size() >= SAMPLES:
		_report()
		print("SELESAI: %d gagal" % _failures)
		quit(1 if _failures > 0 else 0)
	return false


func _check_structure() -> void:
	var town := current_scene
	var meshes := town.find_children("*", "MeshInstance3D", true, false)
	var shadows := 0
	for light in town.find_children("*", "OmniLight3D", true, false):
		if (light as OmniLight3D).shadow_enabled:
			shadows += 1
	var surfaces := 0
	var unmerged := 0
	for mi: MeshInstance3D in meshes:
		if mi.mesh is PrimitiveMesh:
			unmerged += 1
		elif mi.mesh != null:
			surfaces += mi.mesh.get_surface_count()
	print("node: %d, MeshInstance3D: %d, surface: %d" % [get_node_count(), meshes.size(), surfaces])
	_check(get_node_count() <= MAX_NODES, "node <= %d" % MAX_NODES)
	_check(meshes.size() <= MAX_MESH_INSTANCES, "MeshInstance3D <= %d" % MAX_MESH_INSTANCES)
	_check(unmerged == 0, "semua primitif sudah digabung (sisa %d)" % unmerged)
	_check(shadows <= MAX_SHADOW_OMNIS, "lentera ber-shadow %d <= %d" % [shadows, MAX_SHADOW_OMNIS])
	_check(
		not town.get_tree().get_nodes_in_group(&"lit_windows").is_empty(), "jendela masih di group"
	)


func _report() -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var sum := 0.0
	for t in sorted:
		sum += t
	var avg := sum / sorted.size()
	print(
		(
			"frame ms rata-rata %.2f, median %.2f, p95 %.2f"
			% [avg, sorted[sorted.size() / 2], sorted[int(sorted.size() * 0.95)]]
		)
	)
	print("draw call: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("objek: ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	print("primitif: ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if DisplayServer.get_name() == "headless":
		print("headless: FPS tidak diukur (tanpa GPU)")
		return
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	print("FPS: %.0f" % fps)
	_check(fps >= TARGET_FPS, "FPS %.0f >= %.0f" % [fps, TARGET_FPS])


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)

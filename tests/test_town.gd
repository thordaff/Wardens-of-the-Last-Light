extends SceneTree
## Tes headless: referensi node di kota graybox terisi (bukan null).
##   godot --headless -s res://tests/test_town.gd

const TOWN_SCENE := "res://scenes/world/town_graybox.tscn"

var _failures := 0


func _initialize() -> void:
	var town: Node = load(TOWN_SCENE).instantiate()
	var tod = town.get_node("TimeOfDay")
	var cam = town.get_node("FieldCamera")
	print("Referensi node kota")
	_check(tod.sun != null, "TimeOfDay.sun terisi")
	_check(tod.world_environment != null, "TimeOfDay.world_environment terisi")
	_check(cam.target != null, "FieldCamera.target terisi")
	_check(cam.target == town.get_node("Player"), "FieldCamera.target = Player")
	town.free()
	_test_merger()
	print("SELESAI: %d gagal" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)


func _test_merger() -> void:
	print("MeshMerger")
	var red := StandardMaterial3D.new()
	var blue := StandardMaterial3D.new()
	var merger := MeshMerger.new()
	var group := Node3D.new()
	group.position = Vector3(2, 0, 0)
	merger.add_child(group)
	for i in 3:
		group.add_child(_box(Vector3(i, 0, 0), red))
	merger.add_child(_box(Vector3(0, 5, 0), blue))
	var lit := _box(Vector3(0, 9, 0), red)
	lit.add_to_group(&"lit_windows")
	merger.add_child(lit)
	var nested := MeshMerger.new()
	nested.add_child(_box(Vector3.ZERO, red))
	merger.add_child(nested)
	merger.merge()
	var merged: Array[MeshInstance3D] = []
	for child in merger.get_children():
		if child is MeshInstance3D:
			merged.append(child)
	_check(merged.size() == 3, "3 mesh: merah, biru, merah lit_windows (dapat %d)" % merged.size())
	_check(group.get_child_count() == 0, "primitif asli dihapus")
	_check(nested.get_child_count() == 1, "MeshMerger bersarang tidak disentuh")
	var red_mesh: MeshInstance3D = null
	var lit_count := 0
	for m in merged:
		if m.is_in_group(&"lit_windows"):
			lit_count += 1
		elif m.material_override == red:
			red_mesh = m
	_check(lit_count == 1, "mesh lit_windows tetap di group")
	if red_mesh != null:
		var aabb := red_mesh.get_aabb()
		# 3 kotak 1 m di x = 2, 3, 4 (posisi grup ikut dihitung).
		_check(
			is_equal_approx(aabb.position.x, 1.5), "AABB mulai x=1.5 (dapat %.2f)" % aabb.position.x
		)
		_check(is_equal_approx(aabb.end.x, 4.5), "AABB sampai x=4.5 (dapat %.2f)" % aabb.end.x)
	else:
		_check(false, "mesh merah ada")
	merger.free()


func _box(pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	mi.material_override = material
	mi.position = pos
	return mi

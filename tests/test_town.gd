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
	print("SELESAI: %d gagal" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)

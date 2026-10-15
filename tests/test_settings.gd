extends SceneTree
## Tes headless pengaturan (volume, layar, simpan/muat).
##   godot --headless -s res://tests/test_settings.gd

const SETTINGS_SCRIPT := "res://scripts/autoload/settings.gd"
const TEST_PATH := "user://test_settings.cfg"

var _failures := 0


func _initialize() -> void:
	_test_defaults()
	_test_clamping()
	_test_roundtrip()
	_test_bad_file()
	_test_missing_file()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("SELESAI: %d gagal" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)


func _make() -> Node:
	var s: Node = load(SETTINGS_SCRIPT).new()
	s.path = TEST_PATH
	return s


func _test_defaults() -> void:
	print("Default")
	var s = _make()
	_check(is_equal_approx(s.master_volume, 1.0), "master 1.0")
	_check(is_equal_approx(s.music_volume, 0.8), "music 0.8")
	_check(is_equal_approx(s.sfx_volume, 0.8), "sfx 0.8")
	_check(not s.fullscreen, "windowed")
	_check(s.resolution_scale == 3, "skala 3")
	_check(s.window_size() == Vector2i(1920, 1080), "jendela 1920x1080")
	s.free()


func _test_clamping() -> void:
	print("Batas nilai")
	var s = _make()
	s.set_volume(&"music", 1.7)
	_check(is_equal_approx(s.get_volume(&"music"), 1.0), "volume > 1 jadi 1")
	s.set_volume(&"sfx", -0.5)
	_check(is_equal_approx(s.get_volume(&"sfx"), 0.0), "volume < 0 jadi 0")
	s.set_resolution_scale(9)
	_check(s.resolution_scale == 4, "skala > 4 jadi 4")
	s.set_resolution_scale(0)
	_check(s.resolution_scale == 1, "skala < 1 jadi 1")
	_check(s.window_size() == Vector2i(640, 360), "skala 1 = 640x360")
	s.free()


func _test_roundtrip() -> void:
	print("Simpan lalu muat")
	var s = _make()
	var emitted := [0]
	s.changed.connect(func(): emitted[0] += 1)
	s.set_volume(&"master", 0.25)
	s.set_volume(&"music", 0.5)
	s.set_volume(&"sfx", 0.0)
	s.set_fullscreen(true)
	s.set_resolution_scale(2)
	_check(emitted[0] == 5, "sinyal changed tiap perubahan")
	_check(FileAccess.file_exists(TEST_PATH), "file tersimpan otomatis")
	var t = _make()
	t.load_settings()
	_check(is_equal_approx(t.master_volume, 0.25), "master dimuat")
	_check(is_equal_approx(t.music_volume, 0.5), "music dimuat")
	_check(is_equal_approx(t.sfx_volume, 0.0), "sfx dimuat")
	_check(t.fullscreen, "fullscreen dimuat")
	_check(t.resolution_scale == 2, "skala dimuat")
	s.free()
	t.free()


func _test_bad_file() -> void:
	print("Nilai rusak di file")
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", 5.0)
	cfg.set_value("audio", "music", -3.0)
	cfg.set_value("video", "resolution_scale", 99)
	cfg.save(TEST_PATH)
	var s = _make()
	s.load_settings()
	_check(is_equal_approx(s.master_volume, 1.0), "master di-clamp ke 1")
	_check(is_equal_approx(s.music_volume, 0.0), "music di-clamp ke 0")
	_check(is_equal_approx(s.sfx_volume, 0.8), "kunci hilang = default")
	_check(s.resolution_scale == 4, "skala di-clamp ke 4")
	s.free()


func _test_missing_file() -> void:
	print("File tidak ada")
	var s = _make()
	s.set_volume(&"master", 0.1)
	s.load_settings("user://tidak_ada.cfg")
	_check(is_equal_approx(s.master_volume, 1.0), "kembali ke default")
	s.free()

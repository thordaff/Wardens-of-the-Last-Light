extends Node
## Pengaturan pemain. Autoload: Settings. Disimpan di user://settings.cfg.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
const BASE_SIZE := Vector2i(640, 360)
const MIN_SCALE := 1
const MAX_SCALE := 4
const BUSES := {&"master": &"Master", &"music": &"Music", &"sfx": &"SFX"}

## Volume linear 0..1.
var master_volume := 1.0
var music_volume := 0.8
var sfx_volume := 0.8
var fullscreen := false
## Ukuran jendela = 640x360 x skala (1..4).
var resolution_scale := 3

var path := DEFAULT_PATH


func _ready() -> void:
	load_settings()
	apply()


func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 0.8
	sfx_volume = 0.8
	fullscreen = false
	resolution_scale = 3


func set_volume(bus: StringName, value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	match bus:
		&"master":
			master_volume = value
		&"music":
			music_volume = value
		&"sfx":
			sfx_volume = value
		_:
			push_warning("Bus volume tidak dikenal: %s" % bus)
			return
	_changed()


func get_volume(bus: StringName) -> float:
	match bus:
		&"master":
			return master_volume
		&"music":
			return music_volume
		&"sfx":
			return sfx_volume
	return 0.0


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_changed()


func set_resolution_scale(value: int) -> void:
	resolution_scale = clampi(value, MIN_SCALE, MAX_SCALE)
	_changed()


func window_size() -> Vector2i:
	return BASE_SIZE * resolution_scale


## Baca file; nilai rusak atau di luar batas di-clamp, file tidak ada = default.
func load_settings(from_path: String = path) -> void:
	reset_to_defaults()
	var cfg := ConfigFile.new()
	if cfg.load(from_path) != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	resolution_scale = clampi(
		int(cfg.get_value("video", "resolution_scale", resolution_scale)), MIN_SCALE, MAX_SCALE
	)


func save_settings(to_path: String = path) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "resolution_scale", resolution_scale)
	return cfg.save(to_path)


## Terapkan ke AudioServer dan jendela.
func apply() -> void:
	for key in BUSES:
		var index := AudioServer.get_bus_index(BUSES[key])
		if index != -1:
			var v := get_volume(key)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(v, 0.0001)))
			AudioServer.set_bus_mute(index, v <= 0.0)
	if DisplayServer.get_name() == "headless":
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size := window_size()
		var screen := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)


func _changed() -> void:
	apply()
	save_settings()
	changed.emit()

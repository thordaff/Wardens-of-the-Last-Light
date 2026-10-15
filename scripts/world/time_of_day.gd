class_name TimeOfDay
extends Node
## Menerapkan preset lighting sesuai GameClock (art-direction.md §5b, "Napas Suar").
## Cahaya utama selalu datang dari arah Ashspire; bayangan menunjuk menjauhi gunung.

## Cahaya langit dari Last Light.
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
## 4 preset, urut pagi, siang, sore, malam (sama dengan GameClock.Phase).
@export var presets: Array[TimeOfDayPreset] = []
## Arah ke Ashspire dilihat dari region ini, derajat yaw (0 = -Z / ke dalam layar).
@export_range(-180.0, 180.0) var ashspire_yaw_deg: float = 30.0
## Region jauh (Saruna, Ranggawa) mendapat cahaya utama lebih redup.
@export_range(0.0, 2.0) var sun_energy_scale: float = 1.0
## Tabel encounter area ini: kepadatan Pudar (kabut) ikut fase yang sama.
@export var pudar_table: EncounterTable
## Update cukup tiap 0.1 detik, bukan tiap frame.
@export var update_interval: float = 0.1

var _accum := 0.0


func _ready() -> void:
	apply_now()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= update_interval:
		_accum = 0.0
		apply_now()


func apply_now() -> void:
	if presets.size() < 4 or sun == null:
		return
	var blend: Dictionary = GameClock.get_phase_blend()
	var a: TimeOfDayPreset = presets[blend["from"]]
	var b: TimeOfDayPreset = presets[blend["to"]]
	var t: float = blend["weight"]

	sun.light_color = a.sun_color.lerp(b.sun_color, t)
	sun.light_energy = lerpf(a.sun_energy, b.sun_energy, t) * sun_energy_scale
	var elevation := lerpf(a.sun_elevation_deg, b.sun_elevation_deg, t)
	# Cahaya bergerak menjauhi Ashspire: yaw node = arah Ashspire + 180.
	sun.rotation_degrees = Vector3(-elevation, ashspire_yaw_deg + 180.0, 0.0)

	if world_environment != null and world_environment.environment != null:
		var env := world_environment.environment
		env.ambient_light_color = a.ambient_color.lerp(b.ambient_color, t)
		env.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
		var fog := lerpf(a.fog_density, b.fog_density, t)
		if pudar_table != null:
			fog *= lerpf(
				pudar_table.fog_density_scale(a.phase), pudar_table.fog_density_scale(b.phase), t
			)
		env.volumetric_fog_density = fog
		env.volumetric_fog_albedo = a.fog_albedo.lerp(b.fog_albedo, t)
		env.glow_intensity = lerpf(a.glow_intensity, b.glow_intensity, t)
		env.adjustment_saturation = lerpf(a.saturation, b.saturation, t)

	var tree := get_tree()
	tree.call_group(&"lanterns", &"set_strength", lerpf(a.lantern_strength, b.lantern_strength, t))
	var lit := a.windows_lit if t < 0.5 else b.windows_lit
	for w in tree.get_nodes_in_group(&"lit_windows"):
		(w as Node3D).visible = lit

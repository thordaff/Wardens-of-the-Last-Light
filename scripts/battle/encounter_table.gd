class_name EncounterTable
extends Resource
## Tabel random encounter satu area, dibagi per fase GameClock.
## Dipakai EncounterZone (formasi + laju encounter) dan TimeOfDay (kepadatan kabut).

@export var id: StringName
@export var sets: Array[PhaseEncounterSet] = []


func get_set(phase: int) -> PhaseEncounterSet:
	for s in sets:
		if s.phase == phase:
			return s
	return null


func rate_multiplier(phase: int) -> float:
	var s := get_set(phase)
	return s.rate_multiplier if s != null else 1.0


func fog_density_scale(phase: int) -> float:
	var s := get_set(phase)
	return s.fog_density_scale if s != null else 1.0


## Undi formasi untuk fase ini. Null bila fase tidak punya isi.
func pick(phase: int, rng: RandomNumberGenerator) -> EncounterData:
	var s := get_set(phase)
	if s == null:
		return null
	if not s.rare.is_empty() and rng.randf() < s.rare_chance:
		return _pick_weighted(s.rare, rng)
	return _pick_weighted(s.common, rng)


static func _pick_weighted(
	entries: Array[EncounterEntry], rng: RandomNumberGenerator
) -> EncounterData:
	var total := 0
	for e in entries:
		total += e.weight
	if total <= 0:
		return null
	var roll := rng.randi_range(1, total)
	for e in entries:
		roll -= e.weight
		if roll <= 0:
			return e.encounter
	return null

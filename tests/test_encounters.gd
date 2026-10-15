extends SceneTree
## Tes headless encounter per fase Napas Suar.
##   godot --headless -s res://tests/test_encounters.gd

const TABLE_PATH := "res://data/encounter_tables/kota_awal.tres"
const PAGI := 0
const SIANG := 1
const SORE := 2
const MALAM := 3
const SAMPLES := 2000

var _failures := 0


func _initialize() -> void:
	var table: EncounterTable = load(TABLE_PATH)
	_test_table_shape(table)
	_test_rates_and_fog(table)
	_test_strength_by_phase(table)
	_test_rare_only_at_night(table)
	_test_stat_scale()
	print("SELESAI: %d gagal" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)


func _test_table_shape(table: EncounterTable) -> void:
	print("Tabel")
	for phase in [PAGI, SIANG, SORE, MALAM]:
		var s := table.get_set(phase)
		_check(s != null and not s.common.is_empty(), "fase %d punya encounter" % phase)


func _test_rates_and_fog(table: EncounterTable) -> void:
	print("Laju dan kabut")
	var siang := table.rate_multiplier(SIANG)
	var malam := table.rate_multiplier(MALAM)
	_check(siang < table.rate_multiplier(PAGI), "siang lebih jarang dari pagi")
	_check(malam > table.rate_multiplier(SORE), "malam paling sering")
	_check(
		table.fog_density_scale(SIANG) < table.fog_density_scale(MALAM),
		"Pudar tipis siang, tebal malam"
	)


## Rata-rata total HP musuh per encounter (setelah stat_scale) naik dari siang ke malam.
func _test_strength_by_phase(table: EncounterTable) -> void:
	print("Kekuatan")
	var avg := {}
	for phase in [SIANG, MALAM]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		var total := 0.0
		for i in SAMPLES:
			total += _total_hp(table.pick(phase, rng))
		avg[phase] = total / SAMPLES
	_check(avg[SIANG] < avg[MALAM], "HP musuh siang %.0f < malam %.0f" % [avg[SIANG], avg[MALAM]])


func _test_rare_only_at_night(table: EncounterTable) -> void:
	print("Musuh langka")
	var rare_enc: EncounterData = table.get_set(MALAM).rare[0].encounter
	for phase in [PAGI, SIANG, SORE, MALAM]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var hits := 0
		for i in SAMPLES:
			if table.pick(phase, rng) == rare_enc:
				hits += 1
		var ratio := float(hits) / SAMPLES
		if phase == MALAM:
			_check(
				ratio > 0.05 and ratio < 0.15, "malam: langka %.1f%% (target 10%%)" % (ratio * 100)
			)
		else:
			_check(hits == 0, "fase %d: tanpa musuh langka" % phase)


func _test_stat_scale() -> void:
	print("Varian kuat")
	var enc: EncounterData = load("res://data/encounters/05_malam_hampa.tres")
	var hampa: EnemyData = load("res://data/enemies/hampa.tres")
	var s := BattleSystem.new()
	s.setup([], [], enc, 1)
	var b: Battler = s.enemies[0]
	_check(
		b.max_hp == roundi(hampa.max_hp * enc.stat_scale), "HP Hampa malam x%.2f" % enc.stat_scale
	)
	_check(b.phys_atk > hampa.phys_atk, "serangan Hampa malam lebih kuat")
	_check(b.speed == hampa.speed and b.max_shield == hampa.shield, "speed dan shield tetap")


func _total_hp(enc: EncounterData) -> float:
	var total := 0.0
	for e in enc.enemies:
		total += e.max_hp * enc.stat_scale
	return total

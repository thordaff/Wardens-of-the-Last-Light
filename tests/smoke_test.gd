extends SceneTree
## Smoke test QA: godot --headless -s res://tests/smoke_test.gd

var _fail := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)


func _initialize() -> void:
	var clock_script = load("res://scripts/autoload/game_clock.gd")
	var phase = clock_script.Phase
	_check(clock_script.phase_at(6.0) == phase.PAGI, "06:00 pagi")
	_check(clock_script.phase_at(9.99) == phase.PAGI, "09:59 pagi")
	_check(clock_script.phase_at(10.0) == phase.SIANG, "10:00 siang")
	_check(clock_script.phase_at(16.0) == phase.SORE, "16:00 sore")
	_check(clock_script.phase_at(19.0) == phase.MALAM, "19:00 malam")
	_check(clock_script.phase_at(5.99) == phase.MALAM, "05:59 malam")
	_check(clock_script.phase_at(30.0) == phase.PAGI, "30 -> 06:00 pagi (wrap)")

	var clock = clock_script.new()
	clock.set_hour(25.0)
	_check(is_equal_approx(clock.hour, 1.0), "set_hour wrap 25 -> 1")
	clock.begin_battle()
	clock.pause(&"menu")
	clock.end_battle()
	_check(clock.is_paused(), "masih pause oleh menu setelah end_battle")
	clock.resume(&"menu")
	_check(not clock.is_paused(), "resume semua alasan")
	clock.set_hour(9.5)
	var b: Dictionary = clock.get_phase_blend()
	_check(b.to == phase.SIANG and b.weight > 0.0 and b.weight < 1.0, "blend pagi->siang di 09:30")
	clock.set_hour(7.0)
	_check(clock.get_phase_blend().weight == 0.0, "tanpa blend di 07:00")
	clock.free()

	var party_script = load("res://scripts/autoload/party_manager.gd")
	var char_script = load("res://scripts/battle/character_data.gd")
	var pm = party_script.new()
	var chars := []
	for i in 9:
		var c = char_script.new()
		c.id = StringName("c%d" % i)
		chars.append(c)
	for i in 8:
		_check(pm.add_member(chars[i]), "tambah anggota %d" % i)
	_check(not pm.add_member(chars[8]), "anggota ke-9 ditolak")
	_check(not pm.add_member(chars[0]), "duplikat ditolak")
	_check(
		pm.get_active_in_slot(0) == chars[0] and pm.get_reserve_in_slot(0) == chars[4],
		"slot 0 = c0 / c4"
	)
	_check(pm.swap_slot(0) and pm.get_active_in_slot(0) == chars[4], "swap slot 0")
	_check(not pm.swap_slot(4) and not pm.swap_slot(-1), "swap slot di luar batas ditolak")
	_check(
		pm.remove_member(chars[4]) and pm.get_active_in_slot(0) == chars[0],
		"hapus aktif, cadangan naik"
	)
	_check(not pm.swap_slot(0), "slot tanpa cadangan tidak bisa swap")
	_check(pm.member_count() == 7, "jumlah 7")
	pm.free()

	print("\n%s (%d gagal)" % ["OK" if _fail == 0 else "GAGAL", _fail])
	quit(1 if _fail else 0)

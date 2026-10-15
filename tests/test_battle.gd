extends SceneTree
## Tes headless logika battle dan PartyManager.
## Jalankan dari folder proyek:
##   godot --headless --import
##   godot --headless -s res://tests/test_battle.gd
## Keluar dengan kode 0 bila semua lulus.

const PartyManagerScript := preload("res://scripts/autoload/party_manager.gd")
const GameClockScript := preload("res://scripts/autoload/game_clock.gd")

var _failures := 0


func _initialize() -> void:
	_test_game_clock()
	_test_party_manager()
	_test_break()
	_test_boost_attack_hits()
	_test_swap_rules()
	_test_full_battles()
	print("SELESAI: %d gagal" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		_failures += 1
		printerr("  GAGAL ", msg)


func _chars() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for f in [
		"01_aldric",
		"02_seren",
		"03_kael",
		"04_mirela",
		"05_torvan",
		"06_liora",
		"07_bram",
		"08_nyx"
	]:
		out.append(load("res://data/characters/%s.tres" % f))
	return out


func _new_system(encounter_path: String, rng_seed: int = 1234) -> BattleSystem:
	var c := _chars()
	var s := BattleSystem.new()
	s.setup(c.slice(0, 4), c.slice(4, 8), load(encounter_path), rng_seed)
	s.start()
	return s


func _test_game_clock() -> void:
	print("GameClock")
	var clock: Node = GameClockScript.new()
	_check(GameClockScript.phase_at(6.0) == GameClockScript.Phase.PAGI, "06:00 pagi")
	_check(GameClockScript.phase_at(12.0) == GameClockScript.Phase.SIANG, "12:00 siang")
	_check(GameClockScript.phase_at(17.5) == GameClockScript.Phase.SORE, "17:30 sore")
	_check(GameClockScript.phase_at(2.0) == GameClockScript.Phase.MALAM, "02:00 malam")
	clock.set_hour(9.5)
	var blend: Dictionary = clock.get_phase_blend()
	var to_siang: bool = blend["to"] == GameClockScript.Phase.SIANG and blend["weight"] > 0.0
	_check(to_siang, "09:30 mulai blend ke siang")
	clock.begin_battle()
	clock.pause(&"menu")
	clock.end_battle()
	_check(clock.is_paused(), "masih pause karena menu setelah battle selesai")
	clock.resume(&"menu")
	_check(not clock.is_paused(), "jam jalan lagi")
	clock.free()


func _test_party_manager() -> void:
	print("PartyManager")
	var pm: Node = PartyManagerScript.new()
	var c := _chars()
	for ch in c:
		pm.add_member(ch)
	_check(pm.member_count() == 8, "roster 8")
	_check(not pm.add_member(c[0]), "anggota ganda ditolak")
	var pair_ok: bool = pm.get_active_in_slot(0) == c[0] and pm.get_reserve_in_slot(0) == c[4]
	_check(pair_ok, "slot 1 = Aldric/Torvan")
	pm.swap_slot(0)
	_check(pm.get_active_in_slot(0) == c[4], "swap slot 1: Torvan aktif")
	pm.remove_member(c[4])
	_check(pm.get_active_in_slot(0) == c[0], "hapus aktif: cadangan naik")
	pm.free()


func _test_break() -> void:
	print("Break")
	var s := _new_system("res://data/encounters/01_rute_serigala.tres")
	var wolf: Battler = s.enemies[0]
	_check(wolf.display_name == "Serigala Pudar A", "nama musuh kembar diberi huruf")
	# Paksa giliran Aldric (pedang = kelemahan serigala).
	var aldric: Battler = s.active[0]
	s.current = aldric
	aldric.bp = 3
	s.perform({"type": BattleSystem.ActionType.ATTACK, "targets": [wolf], "boost": 2, "weapon": 0})
	_check(wolf.revealed.has(BattleTypes.Type.PEDANG), "kelemahan pedang terbuka")
	_check(wolf.broken or not wolf.is_alive(), "3 hit pedang mematahkan shield 3")
	_check(aldric.bp == 1 and aldric.boosted_last_turn, "BP terpakai 2")
	if wolf.is_alive():
		var hp_before := wolf.hp
		s.current = aldric
		s.perform({"type": BattleSystem.ActionType.ATTACK, "targets": [wolf], "weapon": 1})
		_check(wolf.hp < hp_before, "serangan saat break masuk")
		_check(wolf.recover_round == s.round_number + 2, "pulih 2 ronde lagi")


func _test_boost_attack_hits() -> void:
	print("Boost")
	var s := _new_system("res://data/encounters/03_boss_ksatria.tres")
	var boss: Battler = s.enemies[0]
	var hits := [0]
	s.damaged.connect(func(_t: Battler, _a: int, _w: bool) -> void: hits[0] += 1)
	var kael: Battler = s.active[2]
	s.current = kael
	kael.bp = 5
	s.perform({"type": BattleSystem.ActionType.ATTACK, "targets": [boss], "boost": 3})
	_check(hits[0] == 4, "serang + boost 3 = 4 hit")
	_check(boss.shield == 2, "4 hit belati (kelemahan boss) -> shield 6 jadi 2")
	_check(kael.bp == 2, "boost maksimal 3")


func _test_swap_rules() -> void:
	print("Switch")
	var s := _new_system("res://data/encounters/02_lima_musuh.tres")
	_check(s.enemies.size() == 5, "5 musuh")
	var actor := s.next_turn()
	while actor.is_enemy:
		s.perform(s.choose_enemy_action(actor))
		actor = s.next_turn()
	var slot := actor.slot
	var incoming: Battler = s.reserve[slot]
	_check(s.swap(slot), "switch slot pelaku")
	_check(s.current == incoming, "cadangan langsung mengambil giliran")
	_check(not s.swap(slot), "switch slot sama ditolak di ronde yang sama")
	# KO otomatis digantikan cadangan.
	var other := (slot + 1) % 4
	var victim: Battler = s.active[other]
	var backup: Battler = s.reserve[other]
	var boss := s.enemies[0]
	s.current = boss
	victim.hp = 1
	s.perform({"type": BattleSystem.ActionType.ATTACK, "targets": [victim]})
	_check(s.active[other] == backup and victim.is_reserve, "anggota KO diganti cadangan")


func _test_full_battles() -> void:
	print("Simulasi penuh")
	for path in [
		"res://data/encounters/01_rute_serigala.tres",
		"res://data/encounters/02_lima_musuh.tres",
		"res://data/encounters/03_boss_ksatria.tres"
	]:
		for rng_seed in [1, 2, 3]:
			var s := _new_system(path, rng_seed)
			var turns := 0
			while s.result == BattleSystem.Result.NONE and turns < 500:
				var actor := s.next_turn()
				if actor.is_enemy:
					s.perform(s.choose_enemy_action(actor))
				else:
					s.perform(_auto_party_action(s, actor))
				turns += 1
			_check(
				s.result != BattleSystem.Result.NONE,
				(
					"%s seed %d selesai (%s, %d giliran)"
					% [path.get_file(), rng_seed, BattleSystem.Result.keys()[s.result], turns]
				)
			)


## Pemain bot: pakai kelemahan yang sudah diketahui, boost saat musuh break.
func _auto_party_action(s: BattleSystem, actor: Battler) -> Dictionary:
	var targets := s.alive_enemies()
	var target: Battler = targets[0]
	for t in targets:
		if t.broken:
			target = t
	var boost := actor.bp - 1 if target.broken else 0
	for skill in actor.skills():
		if (
			skill.effect == SkillData.Effect.DAMAGE
			and s.can_use_skill(actor, skill)
			and int(skill.type) in target.weaknesses
		):
			return {
				"type": BattleSystem.ActionType.SKILL,
				"skill": skill,
				"targets": [target],
				"boost": boost
			}
	return {"type": BattleSystem.ActionType.ATTACK, "targets": [target], "boost": boost}

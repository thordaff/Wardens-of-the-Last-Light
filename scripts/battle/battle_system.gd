class_name BattleSystem
extends RefCounted
## Logika battle Break & Boost tanpa tampilan, supaya bisa dites headless.
##
## Alur pemakaian:
##   setup(aktif, cadangan, encounter) -> start()
##   loop: actor = next_turn()
##         musuh -> perform(choose_enemy_action(actor))
##         party -> UI menyusun aksi -> perform(aksi); swap(slot) boleh kapan saja
##                  di giliran party, tidak memakai giliran.
##   selesai saat signal battle_ended.
##
## Aturan prototipe (bisa diubah tim desain):
## - Urutan giliran per ronde: speed tertinggi duluan, seri -> party dulu.
## - BP +1 di awal tiap giliran sendiri (giliran pertama = 1 BP), kecuali giliran
##   tepat setelah boost. Maks 5 BP, boost maks 3 per aksi. BP milik tiap karakter.
## - Serang biasa: boost menambah jumlah hit (1 + boost).
##   Skill: boost menaikkan power (x1, x1.5, x2, x2.5).
## - Tiap hit kelemahan mengurangi 1 shield. Shield 0 = BREAK: musuh kehilangan
##   giliran sampai awal ronde ke-2 setelahnya, menerima damage x2, lalu shield pulih.
## - Switch: tidak memakai giliran, maksimal 1x per slot per ronde.
##   Anggota aktif yang KO otomatis digantikan cadangannya bila masih hidup.
## - Kalah bila semua slot aktif KO. Kabur selalu berhasil kecuali boss.

signal round_started(round_number: int)
signal turn_started(actor: Battler)
signal action_performed(actor: Battler, action: Dictionary)
signal damaged(target: Battler, amount: int, weak: bool)
signal healed(target: Battler, amount: int)
signal weakness_revealed(target: Battler, type: int)
signal shield_changed(target: Battler)
signal broke(target: Battler)
signal recovered(target: Battler)
signal knocked_out(target: Battler)
## `manual` = dipilih pemain lewat Tukar; false = otomatis karena anggota aktif KO.
signal swapped(slot: int, now_active: Battler, now_reserve: Battler, manual: bool)
signal bp_changed(battler: Battler)
signal battle_ended(result: Result)

enum Result { NONE, VICTORY, DEFEAT, FLED }
enum ActionType { ATTACK, SKILL, DEFEND, FLEE }

const SLOTS := 4
const MAX_ENEMIES := 5
const MAX_BP := 5
const MAX_BOOST := 3
const START_BP := 0
const BOOST_SKILL_MULT: Array[float] = [1.0, 1.5, 2.0, 2.5]
const WEAK_MULT := 1.3
const BREAK_MULT := 2.0
const DEFEND_MULT := 0.5
const ENEMY_SKILL_CHANCE := 0.3

var active: Array[Battler] = []
var reserve: Array[Battler] = []
var enemies: Array[Battler] = []
var round_number := 0
## Sisa antrean ronde ini (tidak termasuk `current`).
var order: Array[Battler] = []
var current: Battler
var result: Result = Result.NONE
var can_flee := true
var rng := RandomNumberGenerator.new()

var _swapped_slots: Dictionary = {}


## `party_active` dan `party_reserve` = 4 elemen CharacterData (boleh null),
## pasangan per slot seperti PartyManager. `rng_seed` 0 = acak.
func setup(
	party_active: Array, party_reserve: Array, encounter: EncounterData, rng_seed: int = 0
) -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	active.clear()
	reserve.clear()
	enemies.clear()
	for i in SLOTS:
		var a: CharacterData = party_active[i] if i < party_active.size() else null
		var r: CharacterData = party_reserve[i] if i < party_reserve.size() else null
		if a == null:
			# Slot depan kosong: cadangan maju.
			a = r
			r = null
		active.append(_make_party(a, i, false))
		reserve.append(_make_party(r, i, true))
	var count := mini(encounter.enemies.size(), MAX_ENEMIES)
	var seen: Dictionary = {}
	for i in count:
		var e := Battler.from_enemy(encounter.enemies[i], i)
		var n: int = seen.get(e.display_name, 0)
		seen[e.display_name] = n + 1
		enemies.append(e)
	# Nama kembar diberi huruf: Serigala Pudar A, Serigala Pudar B.
	var counter: Dictionary = {}
	for e in enemies:
		if seen[e.display_name] > 1:
			var k: int = counter.get(e.display_name, 0)
			counter[e.display_name] = k + 1
			e.display_name += " " + char(65 + k)
	can_flee = not encounter.is_boss
	round_number = 0
	order.clear()
	current = null
	result = Result.NONE
	_swapped_slots.clear()


func start() -> void:
	_begin_round()


## Ambil unit berikutnya yang bisa beraksi. Null bila battle sudah selesai.
func next_turn() -> Battler:
	if result != Result.NONE:
		return null
	while true:
		if order.is_empty():
			_begin_round()
		var b: Battler = order.pop_front()
		if b.is_alive() and not b.is_reserve and not b.broken:
			current = b
			_start_turn(b)
			return b
	return null  # tidak tercapai


## Urutan sisa ronde ini, dimulai dari unit yang sedang beraksi.
func get_current_order() -> Array[Battler]:
	var out: Array[Battler] = []
	if current != null and current.is_alive():
		out.append(current)
	for b in order:
		if b.is_alive() and not b.is_reserve and not b.broken:
			out.append(b)
	return out


## Perkiraan urutan ronde berikutnya (untuk bar "BERIKUTNYA").
func get_next_order() -> Array[Battler]:
	var out: Array[Battler] = []
	for b in _field_units():
		if b.broken and b.recover_round > round_number + 1:
			continue
		out.append(b)
	out.sort_custom(_faster)
	return out


func alive_enemies() -> Array[Battler]:
	var out: Array[Battler] = []
	for b in enemies:
		if b.is_alive():
			out.append(b)
	return out


func alive_active() -> Array[Battler]:
	var out: Array[Battler] = []
	for b in active:
		if b != null and b.is_alive():
			out.append(b)
	return out


## Calon target untuk skill (atau serang biasa bila `skill` null).
func candidates(skill: SkillData) -> Array[Battler]:
	if skill == null or skill.targets_enemies():
		return alive_enemies()
	return alive_active()


func can_use_skill(actor: Battler, skill: SkillData) -> bool:
	return actor.sp >= skill.sp_cost


func can_swap(slot: int) -> bool:
	if result != Result.NONE or current == null or current.is_enemy:
		return false
	if slot < 0 or slot >= SLOTS or _swapped_slots.has(slot):
		return false
	var r := reserve[slot]
	return r != null and r.is_alive()


func swap(slot: int) -> bool:
	if not can_swap(slot):
		return false
	_swapped_slots[slot] = true
	_do_swap(slot, true)
	return true


## Aksi: {type: ActionType, skill: SkillData, targets: Array[Battler],
##        boost: int, weapon: int}. Target kosong untuk skill "semua".
## Mengembalikan false (tanpa mengubah apa pun, giliran tidak habis) bila aksi
## tidak sah, misalnya SP kurang, target kosong, atau kabur dari boss.
func perform(action: Dictionary) -> bool:
	if result != Result.NONE or current == null:
		return false
	var actor := current
	if not is_valid_action(actor, action):
		return false
	var type: ActionType = action.get("type", ActionType.ATTACK)
	var boost := 0
	if not actor.is_enemy and (type == ActionType.ATTACK or type == ActionType.SKILL):
		boost = clampi(int(action.get("boost", 0)), 0, mini(MAX_BOOST, actor.bp))
		action["boost"] = boost
	match type:
		ActionType.ATTACK:
			_do_attack(actor, action, boost)
		ActionType.SKILL:
			_do_skill(actor, action, boost)
		ActionType.DEFEND:
			actor.defending = true
		ActionType.FLEE:
			if can_flee:
				_finish(Result.FLED)
	if boost > 0:
		actor.bp -= boost
		actor.boosted_last_turn = true
		bp_changed.emit(actor)
	action_performed.emit(actor, action)
	_check_end()
	return true


func is_valid_action(actor: Battler, action: Dictionary) -> bool:
	var type: ActionType = action.get("type", ActionType.ATTACK)
	var targets: Array = action.get("targets", [])
	match type:
		ActionType.ATTACK:
			return not targets.is_empty() and targets[0] != null and targets[0].is_alive()
		ActionType.SKILL:
			var skill: SkillData = action.get("skill")
			if skill == null or actor.sp < skill.sp_cost:
				return false
			return not skill.is_single_target() or not targets.is_empty()
		ActionType.FLEE:
			return can_flee
	return true


## AI musuh sederhana: kadang skill, selain itu serang biasa ke party acak.
func choose_enemy_action(actor: Battler) -> Dictionary:
	var targets := alive_active()
	var skills := actor.skills()
	if not skills.is_empty() and rng.randf() < ENEMY_SKILL_CHANCE:
		var skill: SkillData = skills[rng.randi_range(0, skills.size() - 1)]
		var chosen: Array[Battler] = []
		if skill.is_single_target() and not targets.is_empty():
			chosen.append(targets[rng.randi_range(0, targets.size() - 1)])
		return {"type": ActionType.SKILL, "skill": skill, "targets": chosen}
	var target: Array[Battler] = []
	if not targets.is_empty():
		target.append(targets[rng.randi_range(0, targets.size() - 1)])
	return {"type": ActionType.ATTACK, "targets": target}


# --- internal ---------------------------------------------------------------


func _make_party(data: CharacterData, slot: int, is_res: bool) -> Battler:
	if data == null:
		return null
	var b := Battler.from_character(data, slot, is_res)
	b.bp = START_BP
	return b


func _field_units() -> Array[Battler]:
	var out: Array[Battler] = []
	for b in active:
		if b != null and b.is_alive():
			out.append(b)
	for b in enemies:
		if b.is_alive():
			out.append(b)
	return out


static func _faster(a: Battler, b: Battler) -> bool:
	if a.speed != b.speed:
		return a.speed > b.speed
	if a.is_enemy != b.is_enemy:
		return not a.is_enemy
	return a.slot < b.slot


func _begin_round() -> void:
	round_number += 1
	_swapped_slots.clear()
	for e in enemies:
		if e.broken and round_number >= e.recover_round:
			e.broken = false
			e.shield = e.max_shield
			recovered.emit(e)
			shield_changed.emit(e)
	order.clear()
	for b in _field_units():
		if not b.broken:
			order.append(b)
	order.sort_custom(_faster)
	round_started.emit(round_number)


func _start_turn(b: Battler) -> void:
	if b.is_enemy:
		turn_started.emit(b)
		return
	b.defending = false
	if b.boosted_last_turn:
		b.boosted_last_turn = false
	elif b.bp < MAX_BP:
		b.bp += 1
		bp_changed.emit(b)
	turn_started.emit(b)


func _do_attack(actor: Battler, action: Dictionary, boost: int) -> void:
	var targets: Array = action.get("targets", [])
	if targets.is_empty():
		return
	var target: Battler = targets[0]
	var type := BattleTypes.NONE
	if not actor.is_enemy:
		var weapons := actor.weapons()
		var w := int(action.get("weapon", 0))
		if not weapons.is_empty():
			type = weapons[clampi(w, 0, weapons.size() - 1)]
	for i in 1 + boost:
		if not target.is_alive():
			break
		_hit(actor, target, type, 1.0, true)


func _do_skill(actor: Battler, action: Dictionary, boost: int) -> void:
	var skill: SkillData = action.get("skill")
	if skill == null or actor.sp < skill.sp_cost:
		return
	actor.sp -= skill.sp_cost
	var power := skill.power * BOOST_SKILL_MULT[boost]
	var targets: Array[Battler] = []
	if skill.is_single_target():
		for t in action.get("targets", []):
			targets.append(t)
	else:
		# "Musuh" relatif terhadap pelaku: skill musuh ALL_ENEMIES mengenai party.
		var hits_enemy_side := skill.targets_enemies() != actor.is_enemy
		targets = alive_enemies() if hits_enemy_side else alive_active()
	var type := int(skill.type)
	if actor.is_enemy:
		type = BattleTypes.NONE
	for t in targets:
		if not t.is_alive():
			continue
		if skill.effect == SkillData.Effect.HEAL:
			_heal(t, int(actor.elem_atk * power * 3.0))
		else:
			_hit(actor, t, type, power, not BattleTypes.is_element(int(skill.type)))


func _hit(attacker: Battler, target: Battler, type: int, power: float, physical: bool) -> void:
	var atk := attacker.phys_atk if physical else attacker.elem_atk
	var def := target.phys_def if physical else target.elem_def
	var dmg := maxf(1.0, atk * 3.0 * power - def) * rng.randf_range(0.92, 1.08)
	if target.broken:
		dmg *= BREAK_MULT
	var weak := target.is_enemy and type != BattleTypes.NONE and type in target.weaknesses
	if weak:
		dmg *= WEAK_MULT
		if not target.revealed.has(type):
			target.revealed[type] = true
			weakness_revealed.emit(target, type)
	if target.defending:
		dmg *= DEFEND_MULT
	var amount := maxi(1, int(dmg))
	target.hp = maxi(0, target.hp - amount)
	damaged.emit(target, amount, weak)
	if weak and not target.broken and target.is_alive():
		target.shield -= 1
		shield_changed.emit(target)
		if target.shield <= 0:
			target.shield = 0
			target.broken = true
			target.recover_round = round_number + 2
			broke.emit(target)
	if not target.is_alive():
		_on_ko(target)


func _heal(target: Battler, amount: int) -> void:
	var before := target.hp
	target.hp = mini(target.max_hp, target.hp + maxi(1, amount))
	healed.emit(target, target.hp - before)


func _on_ko(target: Battler) -> void:
	target.defending = false
	knocked_out.emit(target)
	if target.is_enemy or target.is_reserve:
		return
	var r := reserve[target.slot]
	if r != null and r.is_alive():
		_do_swap(target.slot, false)


func _do_swap(slot: int, manual: bool) -> void:
	var out := active[slot]
	var inn := reserve[slot]
	active[slot] = inn
	reserve[slot] = out
	inn.is_reserve = false
	if out != null:
		out.is_reserve = true
		out.defending = false
	var i := order.find(out)
	if i != -1:
		order[i] = inn
	swapped.emit(slot, inn, out, manual)
	if current == out:
		# Cadangan yang masuk di giliran pasangannya memulai giliran sendiri
		# (+1 BP, status bertahan direset).
		current = inn
		_start_turn(inn)


func _check_end() -> void:
	if result != Result.NONE:
		return
	if alive_enemies().is_empty():
		_finish(Result.VICTORY)
	elif alive_active().is_empty():
		_finish(Result.DEFEAT)


func _finish(r: Result) -> void:
	result = r
	battle_ended.emit(r)

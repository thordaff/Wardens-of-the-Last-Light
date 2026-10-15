class_name Battler
extends RefCounted
## Status runtime satu unit di battle (party atau musuh).

var display_name: String
var is_enemy := false
var character: CharacterData
var enemy: EnemyData

var max_hp := 1
var hp := 1
var max_sp := 0
var sp := 0
var phys_atk := 0
var phys_def := 0
var elem_atk := 0
var elem_def := 0
var speed := 0

## Party: Boost Point. Musuh: tidak dipakai.
var bp := 0
var boosted_last_turn := false
var defending := false
## Party: slot 0..3. Musuh: indeks di formasi.
var slot := -1
var is_reserve := false

## Musuh saja.
var max_shield := 0
var shield := 0
var weaknesses: Array[int] = []
var revealed: Dictionary = {}
var broken := false
var recover_round := 0


static func from_character(data: CharacterData, slot_index: int, reserve: bool) -> Battler:
	var b := Battler.new()
	b.character = data
	b.display_name = data.display_name
	b.max_hp = data.max_hp
	b.hp = data.max_hp
	b.max_sp = data.max_sp
	b.sp = data.max_sp
	b.phys_atk = data.phys_atk
	b.phys_def = data.phys_def
	b.elem_atk = data.elem_atk
	b.elem_def = data.elem_def
	b.speed = data.speed
	b.slot = slot_index
	b.is_reserve = reserve
	return b


## `stat_scale` menguatkan HP dan atk/def (speed dan shield tetap).
static func from_enemy(data: EnemyData, index: int, stat_scale: float = 1.0) -> Battler:
	var b := Battler.new()
	b.enemy = data
	b.is_enemy = true
	b.display_name = data.display_name
	b.max_hp = roundi(data.max_hp * stat_scale)
	b.hp = b.max_hp
	b.phys_atk = roundi(data.phys_atk * stat_scale)
	b.phys_def = roundi(data.phys_def * stat_scale)
	b.elem_atk = roundi(data.elem_atk * stat_scale)
	b.elem_def = roundi(data.elem_def * stat_scale)
	b.speed = data.speed
	b.max_shield = data.shield
	b.shield = data.shield
	for w in data.weaknesses:
		b.weaknesses.append(int(w))
	b.slot = index
	return b


func is_alive() -> bool:
	return hp > 0


func weapons() -> Array[int]:
	var out: Array[int] = []
	if character != null:
		for w in character.weapons:
			out.append(int(w))
	return out


func skills() -> Array[SkillData]:
	if character != null:
		return character.skills
	if enemy != null:
		return enemy.skills
	var none: Array[SkillData] = []
	return none


func placeholder_color() -> Color:
	if character != null:
		return character.placeholder_color
	return enemy.placeholder_color

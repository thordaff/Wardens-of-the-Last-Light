extends Node
## Roster party. Autoload: PartyManager.
##
## Maksimal 8 anggota, 4 aktif di battle. Mengikuti default battle-layout.md §1:
## 4 slot, tiap slot berisi 1 aktif (depan) dan 1 cadangan (belakang).
## Switch = tukar depan/belakang di slot yang sama. Kalau desain combat nanti
## memilih switch bebas, `swap_with_reserve()` sudah mendukung tukar lintas slot.

signal roster_changed
signal slot_swapped(slot: int, now_active: CharacterData, now_reserve: CharacterData)

const MAX_ROSTER := 8
const ACTIVE_SLOTS := 4

## _active[i] dan _reserve[i] = pasangan slot i. null = kosong.
var _active: Array[CharacterData] = []
var _reserve: Array[CharacterData] = []


func _init() -> void:
	_active.resize(ACTIVE_SLOTS)
	_reserve.resize(ACTIVE_SLOTS)


## Tambah anggota ke slot kosong pertama (aktif dulu, lalu cadangan).
## Mengembalikan false kalau roster penuh atau anggota sudah ada.
func add_member(member: CharacterData) -> bool:
	if member == null or has_member(member) or is_full():
		return false
	var slot := _active.find(null)
	if slot != -1:
		_active[slot] = member
	else:
		_reserve[_reserve.find(null)] = member
	roster_changed.emit()
	return true


func remove_member(member: CharacterData) -> bool:
	if member == null:
		return false
	var slot := _active.find(member)
	if slot != -1:
		# Cadangan pasangannya naik supaya slot aktif tidak kosong.
		_active[slot] = _reserve[slot]
		_reserve[slot] = null
	else:
		slot = _reserve.find(member)
		if slot == -1:
			return false
		_reserve[slot] = null
	roster_changed.emit()
	return true


func has_member(member: CharacterData) -> bool:
	return member in _active or member in _reserve


func get_roster() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for m in _active + _reserve:
		if m != null:
			out.append(m)
	return out


func member_count() -> int:
	return get_roster().size()


func is_full() -> bool:
	return member_count() >= MAX_ROSTER


## 4 slot aktif, termasuk null untuk slot kosong (urutan = posisi di arena).
func get_active() -> Array[CharacterData]:
	return _active.duplicate()


func get_reserves() -> Array[CharacterData]:
	return _reserve.duplicate()


func get_active_in_slot(slot: int) -> CharacterData:
	return _active[slot]


func get_reserve_in_slot(slot: int) -> CharacterData:
	return _reserve[slot]


## Tukar aktif dan cadangan di satu slot. Slot tanpa cadangan tidak bisa switch.
func swap_slot(slot: int) -> bool:
	if slot < 0 or slot >= ACTIVE_SLOTS or _reserve[slot] == null:
		return false
	var tmp := _active[slot]
	_active[slot] = _reserve[slot]
	_reserve[slot] = tmp
	slot_swapped.emit(slot, _active[slot], _reserve[slot])
	roster_changed.emit()
	return true


## Switch bebas: cadangan dari slot mana pun masuk ke `active_slot`, yang keluar
## mengisi posisi cadangan itu.
func swap_with_reserve(active_slot: int, reserve_slot: int) -> bool:
	if active_slot < 0 or active_slot >= ACTIVE_SLOTS:
		return false
	if reserve_slot < 0 or reserve_slot >= ACTIVE_SLOTS or _reserve[reserve_slot] == null:
		return false
	var tmp := _active[active_slot]
	_active[active_slot] = _reserve[reserve_slot]
	_reserve[reserve_slot] = tmp
	slot_swapped.emit(active_slot, _active[active_slot], tmp)
	roster_changed.emit()
	return true

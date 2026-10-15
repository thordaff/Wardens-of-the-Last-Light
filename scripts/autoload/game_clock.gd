extends Node
## Jam dalam game ("Napas Suar"). Autoload: GameClock.
##
## Empat fase mengikuti art-direction.md §5b:
## pagi 06–10, siang 10–16, sore 16–19, malam 19–06.
## Jam berhenti selama battle; battle memakai fase saat encounter dimulai.
## Blend lighting antar fase dikerjakan node TimeOfDay di scene (belum dibuat),
## yang membaca `hour`, `get_phase()` dan `get_phase_blend()` dari sini.

signal hour_changed(hour: float)
signal phase_changed(phase: Phase)
signal paused_changed(is_paused: bool)

enum Phase { PAGI, SIANG, SORE, MALAM }

## Jam mulai tiap fase, urut dari pagi.
const PHASE_START := {
	Phase.PAGI: 6.0,
	Phase.SIANG: 10.0,
	Phase.SORE: 16.0,
	Phase.MALAM: 19.0,
}
const PHASE_NAMES := {
	Phase.PAGI: "Pagi",
	Phase.SIANG: "Siang",
	Phase.SORE: "Sore",
	Phase.MALAM: "Malam",
}
## Lama transisi antar fase dalam jam game (art-direction: ±1 jam, smoothstep).
const TRANSITION_HOURS := 1.0

## Jam game per detik nyata. 0.02 = satu hari penuh ±20 menit nyata.
@export var clock_speed: float = 0.02
## Jam saat ini, 0.0–24.0.
@export_range(0.0, 24.0, 0.01) var hour: float = 8.0:
	set = set_hour

var _paused_reasons: Dictionary = {}
var _phase: Phase = Phase.PAGI


func _ready() -> void:
	_phase = phase_at(hour)


func _process(delta: float) -> void:
	if is_paused():
		return
	set_hour(hour + delta * clock_speed)


func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	hour_changed.emit(hour)
	var new_phase := phase_at(hour)
	if new_phase != _phase:
		_phase = new_phase
		phase_changed.emit(_phase)


func get_phase() -> Phase:
	return _phase


func get_phase_name() -> String:
	return PHASE_NAMES[_phase]


static func phase_at(h: float) -> Phase:
	h = fposmod(h, 24.0)
	if h >= PHASE_START[Phase.MALAM] or h < PHASE_START[Phase.PAGI]:
		return Phase.MALAM
	if h >= PHASE_START[Phase.SORE]:
		return Phase.SORE
	if h >= PHASE_START[Phase.SIANG]:
		return Phase.SIANG
	return Phase.PAGI


static func next_phase(phase: Phase) -> Phase:
	return ((phase + 1) % Phase.size()) as Phase


## Untuk blend lighting: fase sekarang, fase berikutnya, dan bobot 0..1 menuju
## fase berikutnya. Bobot naik dengan smoothstep di jam terakhir sebelum fase
## berikutnya mulai, selain itu 0.
func get_phase_blend() -> Dictionary:
	var to := next_phase(_phase)
	var hours_left := fposmod(PHASE_START[to] - hour, 24.0)
	var t := 0.0
	if hours_left < TRANSITION_HOURS:
		t = smoothstep(0.0, 1.0, 1.0 - hours_left / TRANSITION_HOURS)
	return {"from": _phase, "to": to, "weight": t}


## Hentikan jam. `reason` dipakai supaya beberapa sistem (battle, cutscene, menu)
## bisa pause tanpa saling membatalkan.
func pause(reason: StringName = &"default") -> void:
	var was_paused := is_paused()
	_paused_reasons[reason] = true
	if not was_paused:
		paused_changed.emit(true)


func resume(reason: StringName = &"default") -> void:
	if not _paused_reasons.erase(reason):
		return
	if not is_paused():
		paused_changed.emit(false)


func is_paused() -> bool:
	return not _paused_reasons.is_empty()


## Dipanggil saat encounter dimulai. Mengembalikan fase yang dipakai battle.
func begin_battle() -> Phase:
	pause(&"battle")
	return _phase


func end_battle() -> void:
	resume(&"battle")

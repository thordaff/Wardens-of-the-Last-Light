class_name EncounterZone
extends Area3D
## Area random encounter (rumput tinggi / rute). Selama pemain berjalan di dalamnya,
## tiap meter punya peluang memicu battle dari daftar encounter.

signal encounter_triggered(encounter: EncounterData)

@export var encounters: Array[EncounterData] = []
## Peluang per meter berjalan.
@export_range(0.0, 1.0) var chance_per_meter: float = 0.08
## Jarak aman minimum sebelum encounter bisa terjadi (juga setelah kembali dari battle).
@export var grace_distance: float = 4.0

var _player: FieldPlayer
var _walked := 0.0


func _ready() -> void:
	add_to_group(&"encounter_zones")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func reset_grace() -> void:
	_walked = 0.0


func _on_body_entered(body: Node3D) -> void:
	var p := body as FieldPlayer
	if p == null:
		return
	_player = p
	if not p.moved.is_connected(_on_player_moved):
		p.moved.connect(_on_player_moved)


func _on_body_exited(body: Node3D) -> void:
	if body == _player:
		_player.moved.disconnect(_on_player_moved)
		_player = null


func _on_player_moved(distance: float) -> void:
	if encounters.is_empty():
		return
	_walked += distance
	if _walked < grace_distance:
		return
	# Peluang dihitung per jarak supaya tidak bergantung pada frame rate.
	if randf() < 1.0 - pow(1.0 - chance_per_meter, distance):
		_walked = 0.0
		encounter_triggered.emit(encounters[randi() % encounters.size()])

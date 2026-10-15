extends Node3D
## Scene kota graybox: menghubungkan pemain, kamera, zona encounter, dan battle.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"

## Posisi pemain disimpan saat masuk battle supaya kembali ke tempat yang sama.
static var _return_position: Variant = null

@onready var _player: FieldPlayer = $Player


func _ready() -> void:
	# Esc / Start membuka menu pause (autoload PauseMenu).
	add_to_group(&"pausable")
	if _return_position != null:
		_player.global_position = _return_position
		_return_position = null
	for zone in get_tree().get_nodes_in_group(&"encounter_zones"):
		(zone as EncounterZone).encounter_triggered.connect(_on_encounter)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_T:
		GameClock.set_hour(GameClock.hour + 3.0)


func _on_encounter(encounter: EncounterData) -> void:
	_player.input_enabled = false
	_return_position = _player.global_position
	BattleScene.pending_encounter = encounter
	BattleScene.return_scene = scene_file_path
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)

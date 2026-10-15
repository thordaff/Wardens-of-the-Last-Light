extends Control
## Layar game over setelah seluruh party tumbang: ulangi battle atau kembali ke judul.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var _retry: Button = %RetryButton
@onready var _title: Button = %TitleButton


func _ready() -> void:
	_retry.disabled = BattleScene.last_encounter == null
	_retry.pressed.connect(_on_retry)
	_title.pressed.connect(_on_title)
	if _retry.disabled:
		_title.grab_focus()
	else:
		_retry.grab_focus()


func _on_retry() -> void:
	# return_scene dibiarkan supaya setelah menang pemain kembali ke field yang sama.
	BattleScene.pending_encounter = BattleScene.last_encounter
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _on_title() -> void:
	BattleScene.return_scene = ""
	get_tree().change_scene_to_file(TITLE_SCENE)

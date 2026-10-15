extends Node3D
## Scene awal sementara: menampilkan jam dan fase, dan membuka prototipe battle.
## Diganti scene judul / field setelah prototipe battle jalan.

const BATTLE_SCENE := "res://scenes/battle/battle.tscn"
const ENCOUNTERS: Array[String] = [
	"res://data/encounters/01_rute_serigala.tres",
	"res://data/encounters/02_lima_musuh.tres",
	"res://data/encounters/03_boss_ksatria.tres",
]

@onready var _label: Label = $DebugUI/Label


func _process(_delta: float) -> void:
	var h: float = GameClock.hour
	var lines := PackedStringArray()
	lines.append("%02d:%02d  %s%s" % [
		int(h), int(fmod(h, 1.0) * 60.0),
		GameClock.get_phase_name(),
		"  (jam berhenti)" if GameClock.is_paused() else "",
	])
	lines.append("Party: %d/%d" % [PartyManager.member_count(), PartyManager.MAX_ROSTER])
	lines.append("")
	lines.append("Prototipe battle: tekan 1, 2, atau 3")
	lines.append("1 Serigala   2 Lima musuh   3 Boss")
	lines.append("T: majukan jam 3 jam")
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			var index := key.keycode - KEY_1
			BattleScene.pending_encounter = load(ENCOUNTERS[index])
			get_tree().change_scene_to_file(BATTLE_SCENE)
		KEY_T:
			GameClock.set_hour(GameClock.hour + 3.0)

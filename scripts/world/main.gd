extends Node3D
## Scene awal sementara: menampilkan jam dan fase untuk mengecek autoload.
## Diganti scene judul / field setelah prototipe battle jalan.

@onready var _label: Label = $DebugUI/Label


func _process(_delta: float) -> void:
	var h: float = GameClock.hour
	_label.text = "%02d:%02d  %s%s\nParty: %d/%d" % [
		int(h), int(fmod(h, 1.0) * 60.0),
		GameClock.get_phase_name(),
		"  (jam berhenti)" if GameClock.is_paused() else "",
		PartyManager.member_count(), PartyManager.MAX_ROSTER,
	]

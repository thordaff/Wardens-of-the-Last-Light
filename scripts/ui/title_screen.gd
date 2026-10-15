extends Control
## Layar judul: Mulai Baru, Lanjutkan (belum ada save), Pengaturan, Keluar.

const START_SCENE := "res://scenes/world/town_graybox.tscn"
const DEBUG_SCENE := "res://scenes/main.tscn"
const START_HOUR := 8.0

@onready var _new_game: Button = %NewGameButton
@onready var _continue: Button = %ContinueButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _settings: SettingsMenu = %SettingsMenu


func _ready() -> void:
	_new_game.pressed.connect(_on_new_game)
	# Placeholder sampai sistem save ada.
	_continue.disabled = true
	_settings_button.pressed.connect(_settings.open)
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_settings.closed.connect(_settings_button.grab_focus)
	_settings.hide()
	_new_game.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	# F1: scene uji (jam, encounter manual) untuk tim.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F1:
		get_tree().change_scene_to_file(DEBUG_SCENE)


func _on_new_game() -> void:
	GameClock.set_hour(START_HOUR)
	PartyManager.load_default_roster()
	get_tree().change_scene_to_file(START_SCENE)

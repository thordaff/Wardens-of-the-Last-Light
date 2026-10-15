extends CanvasLayer
## Menu pause global. Autoload: PauseMenu.
## Aktif hanya bila scene saat ini ada di group "pausable" (field). Tombol: Esc / Start.

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"

@onready var _root: Control = $Root
@onready var _resume: Button = %ResumeButton
@onready var _settings_button: Button = %SettingsButton
@onready var _title: Button = %TitleButton
@onready var _settings: SettingsMenu = %SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.hide()
	_settings.hide()
	_resume.pressed.connect(close)
	_settings_button.pressed.connect(_settings.open)
	_settings.closed.connect(_settings_button.grab_focus)
	_title.pressed.connect(_on_title)


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open():
		return
	_root.show()
	get_tree().paused = true
	GameClock.pause(&"menu")
	_resume.grab_focus()


func close() -> void:
	if not is_open():
		return
	_settings.hide()
	_root.hide()
	get_tree().paused = false
	GameClock.resume(&"menu")


func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible:
		return
	if is_open():
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()
		return
	if event.is_action_pressed(&"pause") and _can_pause():
		get_viewport().set_input_as_handled()
		open()


func _can_pause() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.is_in_group(&"pausable")


func _on_title() -> void:
	close()
	get_tree().change_scene_to_file(TITLE_SCENE)

class_name SettingsMenu
extends Control
## Layar pengaturan (volume, layar penuh, skala resolusi). Dipakai layar judul dan menu pause.
## Setiap perubahan langsung diterapkan dan disimpan oleh autoload Settings.

signal closed

@onready var _master: HSlider = %MasterSlider
@onready var _music: HSlider = %MusicSlider
@onready var _sfx: HSlider = %SfxSlider
@onready var _fullscreen: CheckButton = %FullscreenCheck
@onready var _scale: OptionButton = %ScaleOption
@onready var _back: Button = %BackButton


func _ready() -> void:
	for s in Settings.MAX_SCALE - Settings.MIN_SCALE + 1:
		var factor := Settings.MIN_SCALE + s
		var win := Settings.BASE_SIZE * factor
		_scale.add_item("%dx  (%d x %d)" % [factor, win.x, win.y], factor)
	_master.value_changed.connect(func(v: float) -> void: Settings.set_volume(&"master", v))
	_music.value_changed.connect(func(v: float) -> void: Settings.set_volume(&"music", v))
	_sfx.value_changed.connect(func(v: float) -> void: Settings.set_volume(&"sfx", v))
	_fullscreen.toggled.connect(Settings.set_fullscreen)
	_scale.item_selected.connect(
		func(i: int) -> void: Settings.set_resolution_scale(_scale.get_item_id(i))
	)
	_back.pressed.connect(close)
	visibility_changed.connect(_on_visibility_changed)


func open() -> void:
	show()


func close() -> void:
	hide()
	closed.emit()


func _on_visibility_changed() -> void:
	if not visible:
		return
	_master.set_value_no_signal(Settings.master_volume)
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)
	_scale.select(_scale.get_item_index(Settings.resolution_scale))
	_master.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

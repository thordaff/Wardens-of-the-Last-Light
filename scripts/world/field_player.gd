class_name FieldPlayer
extends CharacterBody3D
## Pemain di field: gerak 8 arah (keyboard / stik), animasi jalan 4 arah.
## Sprite sheet: grid frame, satu baris per arah (art-direction.md §7.2).

signal moved(distance: float)

const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right"]

@export var speed: float = 4.0
@export var acceleration: float = 30.0
@export var sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(32, 48)
@export var frames_per_direction: int = 4
@export var walk_fps: float = 8.0
## Baris sheet untuk tiap arah. -1 = pakai baris "left" dan dicerminkan.
@export var row_down: int = 0
@export var row_up: int = 1
@export var row_left: int = 2
@export var row_right: int = -1

var input_enabled := true
var _facing: StringName = &"down"

@onready var _sprite: AnimatedSprite3D = $Sprite


func _ready() -> void:
	if sheet != null:
		_sprite.sprite_frames = _build_frames()
	# Kaki menyentuh tanah: offset setengah tinggi frame.
	_sprite.offset = Vector2(0, frame_size.y * 0.5)
	_play_idle()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	# Kamera tidak berputar: atas di layar = -Z di dunia.
	var target := Vector3(input.x, 0.0, input.y) * speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	var step := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if step > 0.0001:
		moved.emit(step)
	_update_animation(input)


func _update_animation(input: Vector2) -> void:
	if input.length() < 0.1:
		_play_idle()
		return
	if absf(input.x) > absf(input.y):
		_facing = &"right" if input.x > 0.0 else &"left"
	else:
		_facing = &"down" if input.y > 0.0 else &"up"
	_play(_facing)


func _play(dir: StringName) -> void:
	if _sprite.sprite_frames == null:
		return
	_sprite.flip_h = dir == &"right" and row_right < 0
	if _sprite.animation != dir or not _sprite.is_playing():
		_sprite.play(dir)


func _play_idle() -> void:
	if _sprite.sprite_frames == null:
		return
	_sprite.flip_h = _facing == &"right" and row_right < 0
	_sprite.animation = _facing
	_sprite.stop()
	_sprite.frame = 0


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var rows := {
		&"down": row_down,
		&"up": row_up,
		&"left": row_left,
		&"right": row_right if row_right >= 0 else row_left,
	}
	for dir in DIRECTIONS:
		frames.add_animation(dir)
		frames.set_animation_speed(dir, walk_fps)
		frames.set_animation_loop(dir, true)
		var row: int = rows[dir]
		for i in frames_per_direction:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
			frames.add_frame(dir, atlas)
	return frames

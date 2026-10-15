class_name Lantern
extends OmniLight3D
## Lentera kota: kekuatan diatur TimeOfDay lewat group "lanterns",
## dan ikut berdenyut ±10% mengikuti Napas Suar.

@export var base_energy: float = 2.0
@export var pulse_amount: float = 0.1
@export var pulse_period: float = 4.0

var _strength := 1.0
var _time := 0.0


func _ready() -> void:
	add_to_group(&"lanterns")
	# Fase acak supaya lentera tidak berdenyut serempak sempurna.
	_time = randf() * pulse_period


func _process(delta: float) -> void:
	_time += delta
	var pulse := 1.0 + pulse_amount * sin(_time * TAU / pulse_period)
	light_energy = base_energy * _strength * pulse


func set_strength(value: float) -> void:
	_strength = value

class_name FieldCamera
extends Camera3D
## Kamera field HD-2D (art-direction.md §6): perspektif FOV rendah, menunduk,
## yaw tetap, mengikuti pemain dengan halus. DoF tilt-shift lewat CameraAttributesPractical.

@export var target: Node3D
@export_range(30.0, 35.0) var field_fov: float = 32.0
@export_range(-30.0, -25.0) var pitch_deg: float = -28.0
@export_range(8.0, 14.0) var distance: float = 11.0
## Kecepatan follow (makin besar makin cepat menempel).
@export var follow_speed: float = 5.0
## Titik fokus sedikit di atas kaki pemain.
@export var focus_height: float = 0.8
## Jarak dari kamera (m). Art-direction §5: far blur mulai ±12 m, near blur s/d ±3 m.
@export var near_blur_distance: float = 3.0
@export var far_blur_distance: float = 12.0


func _ready() -> void:
	fov = field_fov
	rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)
	_setup_dof()
	if target != null:
		global_position = _desired_position()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_desired_position(), weight)


func _desired_position() -> Vector3:
	var focus := target.global_position + Vector3(0.0, focus_height, 0.0)
	return focus + global_basis.z * distance


func _setup_dof() -> void:
	var attrs := attributes as CameraAttributesPractical
	if attrs == null:
		attrs = CameraAttributesPractical.new()
		attributes = attrs
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = far_blur_distance
	attrs.dof_blur_far_transition = 6.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = near_blur_distance
	attrs.dof_blur_near_transition = 2.0
	attrs.dof_blur_amount = 0.08

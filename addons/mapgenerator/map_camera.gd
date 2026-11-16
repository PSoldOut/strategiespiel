class_name MapCamera
extends Camera3D

## Simple free camera for the map generator.
## WASD pans, mouse wheel zooms, middle mouse button (or Q/E) rotates.

@export var move_speed: float = 45.0
@export var sprint_multiplier: float = 2.5
@export var zoom_step: float = 1.12
@export var min_distance: float = 4.0
@export var max_distance: float = 320.0
@export var rotate_sensitivity: float = 0.006
@export var min_pitch: float = -1.48
@export var max_pitch: float = -0.15

var _target: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = -0.95
var _distance: float = 80.0
var _bounds_min: Vector3 = Vector3(-10000.0, 0.0, -10000.0)
var _bounds_max: Vector3 = Vector3(10000.0, 0.0, 10000.0)
var _rotating: bool = false


func _ready() -> void:
	current = true
	_update_camera()


func _process(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if Input.is_key_pressed(KEY_Q):
		_yaw += delta * 1.5
	if Input.is_key_pressed(KEY_E):
		_yaw -= delta * 1.5

	if not direction.is_zero_approx():
		var speed: float = move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= sprint_multiplier
		var flat_direction := Basis(Vector3.UP, _yaw) * direction.normalized()
		_target += flat_direction * speed * delta

	_target.x = clampf(_target.x, _bounds_min.x, _bounds_max.x)
	_target.z = clampf(_target.z, _bounds_min.z, _bounds_max.z)
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
			_rotating = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = clampf(_distance / zoom_step, min_distance, max_distance)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = clampf(_distance * zoom_step, min_distance, max_distance)

	elif event is InputEventMouseMotion and _rotating:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * rotate_sensitivity
		_pitch = clampf(
			_pitch - motion.relative.y * rotate_sensitivity,
			min_pitch,
			max_pitch
		)


func _update_camera() -> void:
	var rotation_basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	position = _target + rotation_basis * Vector3(0.0, 0.0, _distance)
	rotation = Vector3(_pitch, _yaw, 0.0)


## Places the camera above the center of a map.
func frame_map(map_size: Vector3) -> void:
	_target = Vector3(map_size.x * 0.5, 0.0, map_size.z * 0.5)
	_distance = clampf(maxf(map_size.x, map_size.z) * 1.15, min_distance, max_distance)
	_pitch = -0.95
	_yaw = 0.0
	_update_camera()


func set_bounds(map_size: Vector3) -> void:
	_bounds_min = Vector3(-map_size.x * 0.25, 0.0, -map_size.z * 0.25)
	_bounds_max = Vector3(map_size.x * 1.25, 0.0, map_size.z * 1.25)

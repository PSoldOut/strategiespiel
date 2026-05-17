extends Camera3D
class_name RTSCamera
@export var speed := 50.0
@export var edge_speed := 40.0
@export var zoom_speed := 5.0
@export var mouse_sensitivity := 0.003

var yaw := 0.0
var pitch := -0.7

func _ready():
	_update_rotation()

func _input(event):
	# 🖱️ Rotation mit mittlerer Maustaste
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.2, -0.2)
		_update_rotation()

	# 🔍 Zoom entlang Blickrichtung
	if event is InputEventMouseButton and event.pressed:
		var forward = -transform.basis.z.normalized()
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			global_translate(forward * zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			global_translate(-forward * zoom_speed)

func _process(delta):
	var move_dir = Vector3.ZERO

	# 🎮 WASD
	if Input.is_key_pressed(KEY_W): move_dir.z += 1
	if Input.is_key_pressed(KEY_S): move_dir.z -= 1
	if Input.is_key_pressed(KEY_A): move_dir.x -= 1
	if Input.is_key_pressed(KEY_D): move_dir.x += 1

	# 🖱️ Edge Scrolling
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = get_viewport().get_visible_rect().size
	var edge := 20

	if mouse_pos.x < edge:
		move_dir.x -= 1
	elif mouse_pos.x > screen_size.x - edge:
		move_dir.x += 1

	if mouse_pos.y < edge:
		move_dir.z += 1
	elif mouse_pos.y > screen_size.y - edge:
		move_dir.z -= 1

	if move_dir != Vector3.ZERO:
		move_dir = move_dir.normalized()

		# 🔥 LOKALE Richtungen aus Matrix (FIX!)
		var basis = transform.basis.orthonormalized()

		var forward = -basis.z
		var right = basis.x

		# Nur XZ Bewegung (RTS typisch)
		forward.y = 0
		right.y = 0

		forward = forward.normalized()
		right = right.normalized()

		var movement = (forward * move_dir.z + right * move_dir.x) * speed * delta
		global_translate(movement)

func _update_rotation():
	var rot = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	transform.basis = rot

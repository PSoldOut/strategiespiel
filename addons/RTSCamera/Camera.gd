extends Camera3D
class_name RTSCamera
@export var speed := 50.0
@export var edge_speed := 40.0
@export var zoom_speed := 5.0
@export var mouse_sensitivity := 0.003


var zoom := 0.0
var min_zoom := 10.0
var max_zoom := 20.0

var min_pitch := deg_to_rad(35) # nah dran (stärker geneigt)
var max_pitch := deg_to_rad(70) # weit weg (flacher)

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
			if zoom < max_zoom:
				zoom += zoom_speed
				global_translate(forward * zoom_speed)
				if global_position.y < 20:
					rotate_object_local(Vector3(1,0,0), 0.05)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if zoom > 0:
				zoom -= zoom_speed
				global_translate(-forward * zoom_speed)
				if global_position.y < 20:
					rotate_object_local(Vector3(1,0,0), -0.05)

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
	
func update_camera():
	var t := inverse_lerp(min_zoom, max_zoom, zoom)
	var pitch := lerp(min_pitch, max_pitch, t)
	#pitch_pivot.rotation.x = -pitch

	# Kamera zurückziehen (klassischer RTS Zoom)
	$PitchPivot/Camera3D.position.z = zoom

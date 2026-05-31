extends Camera3D
class_name RTSCamera
@export var speed := 50.0
@export var edge_speed = 40.0
@export var zoom_step = 5.0
@export var mouse_sensitivity = 0.003



var min_zoom = 5.0
var max_zoom = 40.0
var old_zoom = 0
var new_zoom = 0
var current_zoom := 0.0
var forward
var direction = 1
var interpolation_speed = 0.8

var min_pitch := -1.2
var max_pitch := -0.2

var yaw := 0.0
var pitch := -0.7

var t : float = 0.0

func _ready():
	forward = -transform.basis.z.normalized()
	_update_rotation()

func _input(event):
	# 🖱️ Rotation mit mittlerer Maustaste
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)
		_update_rotation()

	# 🔍 Zoom entlang Blickrichtung
	if event is InputEventMouseButton and event.pressed:
		forward = -transform.basis.z.normalized()
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and is_zoom_in_possible():
			old_zoom = new_zoom
			new_zoom += zoom_step
			direction = 1
			
			
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_zoom_out_possible():
			old_zoom = new_zoom
			new_zoom -= zoom_step
			direction = -1
			

func _process(delta):
	if current_zoom < new_zoom - interpolation_speed or current_zoom > new_zoom + interpolation_speed:
		self.global_position = self.global_position + (forward * interpolation_speed * direction)
		current_zoom += direction * interpolation_speed
	
	
		if global_position.y < 20:
			rotate_object_local(Vector3(1,0,0), 0.01 * direction)
			pitch += 0.01 * direction
			pitch = clamp(pitch, min_pitch, max_pitch)
	#var pitch := lerp(min_pitch, max_pitch, t)
	#pitch_pivot.rotation.x = -pitch
	
	
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
	

func is_zoom_in_possible():
	print(global_position.y)
	return abs(current_zoom - new_zoom) < zoom_step * 2 and global_position.y - zoom_step > min_zoom


func is_zoom_out_possible() -> bool:
	print(global_position.y)
	return abs(current_zoom - new_zoom) < zoom_step * 2 and global_position.y + zoom_step < max_zoom
	
func update_translation():
	var startpos = self.global_position
	for t in range(1, 100, 1):
		current_zoom = inverse_lerp(old_zoom, new_zoom, t/100)
		self.global_position = startpos + (forward * t)
		#var pitch := lerp(min_pitch, max_pitch, t)
		#pitch_pivot.rotation.x = -pitch
		
		

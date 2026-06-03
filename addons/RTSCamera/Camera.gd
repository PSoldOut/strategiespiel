extends Camera3D
class_name RTSCamera

##Die Bewegungsgeschwindigkeit der Kamera 
@export var speed := 50.0
##Die Maussensitivität 
@export var mouse_sensitivity = 0.003
##Der Minimale Zoom. Sollte ein negativer Wert sein. Beschränkt die y koordinate der kamera
@export var max_zoom_out = 80.0
##Der Maximale Zoom. Beschränkt die y koordinate der kamera
@export var max_zoom_in = 5
##Die Veränderung im Zoom Pro Mausradumdrehung
@export var zoom_step = 5.0
##Die Zoomschritte interpolieren
@export var use_smooth_zoom : bool = true
##Wenn aktiv wird die Neigung der Kamera in der nähe des Maximal Zooms automatisch angepasst
@export var use_pitch_correction : bool = true
##Die interpolationsgeschwindigkeit für weichen Zoom
@export var interpolation_speed = 0.8
##Die Minimale Neigung der Kamera in radiant
@export var min_pitch := -1.2
##Die Maximale Neigung der Kamera in radiant
@export var max_pitch := -0.2

var new_zoom = 0

var forward
var direction = 1
var yaw := 0.0
var pitch := -0.7


func _ready():
	forward = -transform.basis.z.normalized()
	new_zoom = global_position.y
	if not use_smooth_zoom:
		interpolation_speed = zoom_step
	_update_rotation()



func _process(delta):
	if abs(self.global_position.y - new_zoom) >= interpolation_speed * delta * 60:
		self.global_position = self.global_position + (forward * interpolation_speed * delta * 60 * direction)
		global_position.y = clamp(global_position.y, max_zoom_in, max_zoom_out)
	
		if use_pitch_correction and global_position.y + max_zoom_in < 20:
			rotate_object_local(Vector3(1,0,0), 0.01 * direction)
			pitch += 0.01 * direction
			pitch = clamp(pitch, min_pitch, max_pitch)
		print("current zoom:", self.global_position)
		print("new zoom", new_zoom)
	else:
		new_zoom = self.global_position.y
	
	
	
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
			new_zoom -= zoom_step
			new_zoom = clamp(new_zoom, max_zoom_in, max_zoom_out)
			direction = 1
			
			
			
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and is_zoom_out_possible():
			new_zoom += zoom_step
			new_zoom = clamp(new_zoom, max_zoom_in, max_zoom_out)
			direction = -1





func _update_rotation():
	var rot = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	transform.basis = rot
	

func is_zoom_in_possible():
	print(global_position.y)
	return abs(global_position.y - new_zoom) < zoom_step * 2 and global_position.y - zoom_step > max_zoom_in


func is_zoom_out_possible() -> bool:
	print(global_position.y)
	return abs(global_position.y - new_zoom) < zoom_step * 2 and global_position.y + zoom_step < max_zoom_out
	

		
		

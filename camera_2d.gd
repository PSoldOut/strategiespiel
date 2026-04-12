extends Camera2D

@export var move_speed: float = 500.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 3.0

var dragging: bool = false

func _ready():
	make_current()


func _process(delta):
	handle_keyboard(delta)


func handle_keyboard(delta):
	var dir := Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		dir.x += 1
	
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 2.5
		
		position += dir * speed * delta * zoom.x   # 🔥 wichtig für RTS feeling


func _input(event):
	# 🖱️ Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom *= (1.0 - zoom_speed)

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom *= (1.0 + zoom_speed)
		
		# 🖱️ Drag Start/Stop
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	
	# 🖱️ Drag Bewegung
	if event is InputEventMouseMotion and dragging:
		position -= event.relative * zoom.x   # 🔥 invertiert für RTS Gefühl

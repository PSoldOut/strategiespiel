extends Node3D

@export var target: Node3D
@export var distance: float = 5.0
@export var zoom_speed: float = 1.0
@export var rotate_speed: float = 0.01
@export var min_distance: float = 1.5
@export var max_distance: float = 20.0

var yaw: float = 0.0
var pitch: float = 0.3

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	if target != null:
		update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if target == null:
		return
	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * rotate_speed
		pitch -= event.relative.y * rotate_speed
		pitch = clamp(pitch, -1.2, 1.2)
		update_camera()
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance -= zoom_speed
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance += zoom_speed
		
		distance = clamp(distance, min_distance, max_distance)
		update_camera()

func update_camera() -> void:
	if target == null:
		return
	
	if camera == null:
		return
	
	var target_pos: Vector3 = target.global_transform.origin
	
	var x: float = distance * cos(pitch) * sin(yaw)
	var y: float = distance * sin(pitch)
	var z: float = distance * cos(pitch) * cos(yaw)
	
	var cam_pos := target_pos + Vector3(x, y, z)
	
	camera.global_transform.origin = cam_pos
	camera.look_at(target_pos, Vector3.UP)

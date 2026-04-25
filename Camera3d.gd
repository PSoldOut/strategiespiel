extends Node3D
class_name RTSCamera

@export var move_speed: float = 12.0
@export var fast_speed: float = 28.0
@export var mouse_sensitivity: float = 0.003
@export var zoom_step: float = 4.0
@export var min_height: float = 6.0
@export var max_height: float = 80.0
@export var fixed_pitch: float = -60.0

@onready var pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var tile_palette: Control
@onready var map_spawner: Node
var rotating: bool = false
var hovered_tile: RTSMapTile = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pivot.rotation_degrees.x = fixed_pitch
	camera.current = true
	tile_palette = get_node("../CanvasLayer/TilePalette")
	map_spawner = get_node("../MapSpawner")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not rotating:
			_on_left_click()

func _process(delta: float) -> void:
	_handle_movement(delta)
	_update_hovered_tile()

func _handle_movement(delta: float) -> void:
	var move_input := Vector3.ZERO

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	if Input.is_key_pressed(KEY_W):
		move_input += forward
	if Input.is_key_pressed(KEY_S):
		move_input -= forward
	if Input.is_key_pressed(KEY_D):
		move_input += right
	if Input.is_key_pressed(KEY_A):
		move_input -= right

	if Input.is_key_pressed(KEY_Q):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_E):
		move_input.y -= 1.0
		
	if Input.is_key_pressed(KEY_Y):
		pivot.rotation.y += 1*delta
	if Input.is_key_pressed(KEY_X):
		pivot.rotation.y -= 1*delta

	if move_input != Vector3.ZERO:
		move_input = move_input.normalized()

	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
	global_position += move_input * speed * delta
	global_position.y = clamp(global_position.y, min_height, max_height)

func _rotate_camera(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	pivot.rotation_degrees.x = fixed_pitch

func _zoom(direction: int) -> void:
	var forward := -camera.global_transform.basis.z
	global_position += forward * direction * zoom_step
	global_position.y = clamp(global_position.y, min_height, max_height)

func _update_hovered_tile() -> void:
	if rotating:
		_set_hovered_tile(null)
		return

	var tile := _get_tile_under_mouse()
	_set_hovered_tile(tile)

func _get_tile_under_mouse() -> RTSMapTile:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 2000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider: Object = result.get("collider")
	if collider == null:
		return null

	return _extract_tile(collider)

func _extract_tile(collider: Object) -> RTSMapTile:
	if collider is RTSMapTile:
		return collider as RTSMapTile

	if collider is Node:
		var node := collider as Node

		if node.has_meta("tile_ref"):
			var ref = node.get_meta("tile_ref")
			if ref is RTSMapTile:
				return ref

		var current: Node = node
		while current != null:
			if current is RTSMapTile:
				return current as RTSMapTile
			current = current.get_parent()

	return null

func _set_hovered_tile(tile: RTSMapTile) -> void:
	if hovered_tile == tile:
		return

	if hovered_tile != null:
		hovered_tile.set_hovered(false)

	hovered_tile = tile

	if hovered_tile != null:
		hovered_tile.set_hovered(true)

func _on_left_click() -> void:
	if hovered_tile == null:
		return

	var selected_tile = tile_palette.selected_tile_type
	var selected_height = tile_palette.selected_height
	var selected_news = tile_palette.selected_direction
	
	print("CLICKED TILE:", hovered_tile.grid_x, hovered_tile.grid_y)
	print("SET TYPE:", selected_tile)
	print("SET HEIGHT:", selected_height)
	map_spawner.change_tile(hovered_tile.grid_x, hovered_tile.grid_y,selected_tile,selected_height,selected_news)

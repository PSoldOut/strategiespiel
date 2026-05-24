extends Node3D
class_name MapEditor

const DEFAULT_RAY_LENGTH: float = 10000.0
const INVALID_GRID: Vector2i = Vector2i(-999999, -999999)

@onready var map_spawner: MapSpawner = $MapSpawner
@onready var tile_palette: TilePalette = $CanvasLayer/TilePalette
@onready var hover_highlight: MeshInstance3D = $HoverHighlightMesh

@export var camera: Camera3D

var selected_tile_type: int = EnumMappings.GroundType.GRAS_TILE
var selected_height_action: float = 0.0

var is_painting: bool = false
var painted_tiles: Dictionary = {}
var last_painted_grid: Vector2i = INVALID_GRID


func _ready() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()

	tile_palette.save_requested.connect(_on_save_requested)
	tile_palette.reset_requested.connect(_on_reset_requested)


func _process(_delta: float) -> void:
	_update_hovered_tile()


func _unhandled_input(event: InputEvent) -> void:
	if _is_pointer_over_ui():
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_start_painting()
			else:
				_stop_painting()

	elif event is InputEventMouseMotion:
		if is_painting and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_paint_tile_under_mouse_once()


func _start_painting() -> void:
	is_painting = true
	painted_tiles.clear()
	last_painted_grid = INVALID_GRID
	_paint_tile_under_mouse_once()


func _stop_painting() -> void:
	if not is_painting:
		return

	is_painting = false
	painted_tiles.clear()
	last_painted_grid = INVALID_GRID


func _paint_tile_under_mouse_once() -> void:
	var hit := _get_mouse_map_hit()

	if hit.is_empty():
		return

	var grid_pos: Vector2i = hit["grid"]

	if not _is_valid_grid_pos(grid_pos):
		return

	if grid_pos == last_painted_grid:
		return

	if painted_tiles.has(grid_pos):
		return

	painted_tiles[grid_pos] = true
	last_painted_grid = grid_pos

	map_spawner.change_tile(grid_pos.x, grid_pos.y)


func _is_pointer_over_ui() -> bool:
	var hovered_control := get_viewport().gui_get_hovered_control()

	if hovered_control == null:
		return false

	return hovered_control is Control


func _on_save_requested() -> void:
	map_spawner.save_map()
	print("Map saved")


func _on_reset_requested() -> void:
	map_spawner.reset_map()


func _update_hovered_tile() -> void:
	var hit := _get_mouse_map_hit()

	if hit.is_empty():
		hover_highlight.visible = false
		return

	var grid_pos: Vector2i = hit["grid"]

	if not _is_valid_grid_pos(grid_pos):
		hover_highlight.visible = false
		return

	var hit_position: Vector3 = hit["position"]
	var tile_size := MapSpawner.TILE_SIZE

	hover_highlight.visible = true
	hover_highlight.global_position = Vector3(
		(float(grid_pos.x) + 0.5) * tile_size,
		hit_position.y + 0.03,
		(float(grid_pos.y) + 0.5) * tile_size
	)


func _get_grid_under_mouse() -> Vector2i:
	var hit := _get_mouse_map_hit()

	if hit.is_empty():
		return INVALID_GRID

	return hit["grid"]


func _get_mouse_map_hit() -> Dictionary:
	return get_mouse_map_hit(
		get_viewport(),
		get_world_3d(),
		camera,
		[self],
		DEFAULT_RAY_LENGTH,
		MapSpawner.TILE_SIZE
	)


static func get_mouse_map_hit(
	viewport: Viewport,
	world_3d: World3D,
	camera_ref: Camera3D = null,
	exclude: Array = [],
	ray_length: float = DEFAULT_RAY_LENGTH,
	tile_size: float = 2.0
) -> Dictionary:
	if viewport == null:
		return {}

	if world_3d == null:
		return {}

	if camera_ref == null:
		camera_ref = viewport.get_camera_3d()

	if camera_ref == null:
		return {}

	var mouse_pos := viewport.get_mouse_position()
	var from := camera_ref.project_ray_origin(mouse_pos)
	var to := from + camera_ref.project_ray_normal(mouse_pos) * ray_length

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = 1

	var result := world_3d.direct_space_state.intersect_ray(query)

	if result.is_empty():
		return {}

	var pos: Vector3 = result.position
	var grid_pos := world_position_to_grid(pos, tile_size)
	#print(grid_pos)

	return {
		"grid": grid_pos,
		"position": pos,
		"collider": result.collider
	}


static func world_position_to_grid(pos: Vector3, tile_size: float = 2.0) -> Vector2i:
	var grid_x := int(floor(pos.x / tile_size))
	var grid_y := int(floor(pos.z / tile_size))
	return Vector2i(grid_x, grid_y)


func _is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	if map_spawner == null:
		return false

	if map_spawner.has_method("is_valid_grid_pos"):
		return map_spawner.is_valid_grid_pos(grid_pos.x, grid_pos.y)

	# Fallback: if MapSpawner has no validation method, let change_tile validate later.
	return true


static func get_snapped_mouse_position(
	viewport: Viewport,
	world_3d: World3D,
	camera_ref: Camera3D = null,
	exclude: Array = [],
	ray_length: float = DEFAULT_RAY_LENGTH,
	grid_size: float = 2.0
) -> Vector3:
	if viewport == null:
		return Vector3.ZERO

	if world_3d == null:
		return Vector3.ZERO

	if camera_ref == null:
		camera_ref = viewport.get_camera_3d()

	if camera_ref == null:
		return Vector3.ZERO

	var mouse_pos := viewport.get_mouse_position()
	var from := camera_ref.project_ray_origin(mouse_pos)
	var to := from + camera_ref.project_ray_normal(mouse_pos) * ray_length

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = 1

	var result := world_3d.direct_space_state.intersect_ray(query)

	if result.is_empty():
		return Vector3.ZERO

	var pos: Vector3 = result.position
	return pos.snapped(Vector3(grid_size, 0.0, grid_size))

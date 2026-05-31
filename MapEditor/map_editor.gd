extends Node3D
class_name MapEditor

const DEFAULT_RAY_LENGTH: float = 10000.0
const INVALID_GRID: Vector2i = Vector2i(-999999, -999999)
const INVALID_PLACEMENT_COLOR: Color = Color(1.0, 0.0, 0.0, 1.0)
const DEFAULT_HOVER_COLOR: Color = Color(0.1, 0.8, 1.0, 1.0)

@onready var map_spawner: MapSpawner = $MapSpawner
@onready var tile_palette: TilePalette = $CanvasLayer/TilePalette
@onready var hover_highlight: MeshInstance3D = $HoverHighlightMesh

@export var camera: Camera3D

var selected_tile_type: int = EnumMappings.GroundType.GRAS_TILE
var selected_height_action: float = 0.0

var is_painting: bool = false
var painted_tiles: Dictionary = {}
var last_painted_grid: Vector2i = INVALID_GRID

var _hover_material: StandardMaterial3D
var _last_hover_footprint: Vector2i = Vector2i.ZERO
var _last_hover_color: Color = Color.TRANSPARENT


func _ready() -> void:
	_setup_hover_highlight()

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

	#if painted_tiles.has(grid_pos):
		#return

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

	var footprint := _get_selected_hover_footprint()
	var is_entity_preview := _is_entity_selected_for_preview()
	var is_valid_placement := true

	if is_entity_preview:
		is_valid_placement = _is_current_entity_placement_valid(grid_pos)
	else:
		footprint = Vector2i.ONE

	var preview_color := _get_selected_hover_color()
	if not is_valid_placement:
		preview_color = INVALID_PLACEMENT_COLOR

	_set_hover_outline_mesh(footprint, preview_color)
	_position_hover_highlight(grid_pos, footprint)
	hover_highlight.visible = true



func _setup_hover_highlight() -> void:
	if hover_highlight == null:
		return

	_hover_material = StandardMaterial3D.new()
	_hover_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hover_material.no_depth_test = true
	_hover_material.albedo_color = DEFAULT_HOVER_COLOR
	hover_highlight.material_override = _hover_material
	_set_hover_outline_mesh(Vector2i.ONE, DEFAULT_HOVER_COLOR)
	hover_highlight.visible = false


func _is_entity_selected_for_preview() -> bool:
	if tile_palette == null:
		return false

	return (
		int(tile_palette.selected_building_type) != EnumMappings.BuildingType.NONE
		or int(tile_palette.selected_resource_type) != EnumMappings.ResourceType.NONE
	)


func _get_selected_hover_footprint() -> Vector2i:
	if tile_palette == null or map_spawner == null:
		return Vector2i.ONE

	var selected_building_type: int = int(tile_palette.selected_building_type)
	var selected_resource_type: int = int(tile_palette.selected_resource_type)
	var selected_orientation: int = int(tile_palette.selected_orientation)

	if selected_building_type != EnumMappings.BuildingType.NONE:
		if map_spawner.has_method("get_building_footprint"):
			return map_spawner.get_building_footprint(selected_building_type, selected_orientation)
		return Vector2i.ONE

	if selected_resource_type != EnumMappings.ResourceType.NONE:
		if map_spawner.has_method("get_resource_footprint"):
			return map_spawner.get_resource_footprint(selected_resource_type, selected_orientation)
		return Vector2i.ONE

	return Vector2i.ONE


func _is_current_entity_placement_valid(grid_pos: Vector2i) -> bool:
	if tile_palette == null or map_spawner == null:
		return false

	var selected_building_type: int = int(tile_palette.selected_building_type)
	var selected_resource_type: int = int(tile_palette.selected_resource_type)
	var selected_orientation: int = int(tile_palette.selected_orientation)

	if selected_building_type != EnumMappings.BuildingType.NONE:
		if map_spawner.has_method("can_place_building"):
			return map_spawner.can_place_building(grid_pos, selected_building_type, selected_orientation)
		return false

	if selected_resource_type != EnumMappings.ResourceType.NONE:
		if map_spawner.has_method("can_place_resource"):
			return map_spawner.can_place_resource(grid_pos)
		return false

	return true


func _get_selected_hover_color() -> Color:
	if tile_palette == null or map_spawner == null:
		return DEFAULT_HOVER_COLOR

	var selected_building_type: int = int(tile_palette.selected_building_type)
	var selected_resource_type: int = int(tile_palette.selected_resource_type)

	if selected_building_type != EnumMappings.BuildingType.NONE:
		if map_spawner.has_method("get_building_color"):
			return map_spawner.get_building_color(selected_building_type)
		return DEFAULT_HOVER_COLOR

	if selected_resource_type != EnumMappings.ResourceType.NONE:
		if map_spawner.has_method("get_resource_color"):
			return map_spawner.get_resource_color(selected_resource_type)
		return DEFAULT_HOVER_COLOR

	return DEFAULT_HOVER_COLOR


func _set_hover_outline_mesh(footprint: Vector2i, color: Color) -> void:
	if hover_highlight == null:
		return

	var safe_footprint := Vector2i(max(1, footprint.x), max(1, footprint.y))

	if _last_hover_footprint == safe_footprint and _last_hover_color == color:
		return

	_last_hover_footprint = safe_footprint
	_last_hover_color = color

	if _hover_material == null:
		_setup_hover_highlight()

	if _hover_material != null:
		_hover_material.albedo_color = color

	var size_x := float(safe_footprint.x) * MapSpawner.TILE_SIZE
	var size_z := float(safe_footprint.y) * MapSpawner.TILE_SIZE
	var half_x := size_x * 0.5
	var half_z := size_z * 0.5
	var height := 0.15

	var bottom_y := 0.0
	var top_y := height

	var b0 := Vector3(-half_x, bottom_y, -half_z)
	var b1 := Vector3(half_x, bottom_y, -half_z)
	var b2 := Vector3(half_x, bottom_y, half_z)
	var b3 := Vector3(-half_x, bottom_y, half_z)
	var t0 := Vector3(-half_x, top_y, -half_z)
	var t1 := Vector3(half_x, top_y, -half_z)
	var t2 := Vector3(half_x, top_y, half_z)
	var t3 := Vector3(-half_x, top_y, half_z)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_line(mesh, b0, b1)
	_add_line(mesh, b1, b2)
	_add_line(mesh, b2, b3)
	_add_line(mesh, b3, b0)
	_add_line(mesh, t0, t1)
	_add_line(mesh, t1, t2)
	_add_line(mesh, t2, t3)
	_add_line(mesh, t3, t0)
	_add_line(mesh, b0, t0)
	_add_line(mesh, b1, t1)
	_add_line(mesh, b2, t2)
	_add_line(mesh, b3, t3)
	mesh.surface_end()

	hover_highlight.mesh = mesh


func _add_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)


func _position_hover_highlight(grid_pos: Vector2i, footprint: Vector2i) -> void:
	var safe_footprint := Vector2i(max(1, footprint.x), max(1, footprint.y))
	var tile_size := MapSpawner.TILE_SIZE
	var base_height := _get_max_height_for_footprint(grid_pos, safe_footprint)

	hover_highlight.global_position = Vector3(
		(float(grid_pos.x) + float(safe_footprint.x) * 0.5) * tile_size,
		base_height + 0.04,
		(float(grid_pos.y) + float(safe_footprint.y) * 0.5) * tile_size
	)


func _get_max_height_for_footprint(origin: Vector2i, footprint: Vector2i) -> float:
	if map_spawner == null:
		return 0.0

	var max_height := -INF
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			if not map_spawner.is_valid_grid_pos(x, y):
				continue

			var h := map_spawner.get_tile_height(Vector2i(x, y))
			if h > max_height:
				max_height = h

	if max_height == -INF:
		return 0.0

	return max_height


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

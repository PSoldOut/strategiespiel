extends Node3D
class_name MapSpawner

@export var auto_ramp_enabled: bool = true
@export var show_tile_lines: bool = true
@export var bake_collision: bool = true

@export var map_name: String = "Map001"
@export var map_save_directory: String = "res://GeneratedMaps"
@export var map_json_extension: String = ".json"
@export var baked_scene_extension: String = ".tscn"
@export var tile_palette: Control
@export_file("*.json") var entity_definitions_path: String = "res://entity_definitions.json"
@export var show_entity_outlines: bool = true
@export var entity_outline_height: float = 0.15
@export var entity_outline_y_offset: float = 0.04

const MAP_WIDTH: int = 32
const MAP_HEIGHT: int = 32
const EDITOR_JUNKS: int = 16
const TILE_SIZE: float = 2.0

const HEIGHT_STEP: float = 0.5
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 2.0

# Terrain data. Compatible with MapBaker.
# map_data[y][x] = { "type", "height", "corners" }
var map_data: Array = []

# Entity/editor data.
# resource_data[y][x] = { "resource_type", "orientation", "count" }
# building_data[y][x] = { "building_type", "player", "orientation", "is_center", "origin" }
var resource_data: Array = []
var building_data: Array = []

var ground_type: int = EnumMappings.GroundType.GRAS_TILE
var height_mode: int = EnumMappings.HeightMapping.HEIGHT_NONE
var player: int = EnumMappings.Player.WORLD
var building_type: int = EnumMappings.BuildingType.NONE
var resource_type: int = EnumMappings.ResourceType.NONE
var orientation: int = EnumMappings.Orientation.NORTH

var visual_root: Node3D
var entity_outline_root: Node3D
var entity_definitions: Dictionary = {}

signal map_spawned(map_data: Array)
signal map_data_changed


func _ready() -> void:
	load_entity_definitions()

	visual_root = Node3D.new()
	visual_root.name = "VisualMap"
	add_child(visual_root)

	load_map_from_json()
	rebuild_map()


# -------------------------------------------------------------------------
# High-level rebuild / editor rendering
# -------------------------------------------------------------------------

func rebuild_map() -> void:
	clear_children(visual_root)

	if auto_ramp_enabled:
		MapCornerService.recalculate_auto_ramps(map_data)

	build_visual_map()
	build_entity_outlines()
	call_deferred("_emit_map_spawned")


func _emit_map_spawned() -> void:
	map_spawned.emit(map_data)


func build_visual_map() -> void:
	# Editor view: chunked bake only.
	# Full one-piece bake happens only in save_map_as_scene().
	MapChunkRenderer.build_visual_chunks(
		visual_root,
		map_data,
		EDITOR_JUNKS,
		TILE_SIZE,
		bake_collision,
		show_tile_lines
	)


func rebuild_visual_chunks_for_area(origin: Vector2i, size: Vector2i, padding_tiles: int = 0) -> void:
	MapChunkRenderer.rebuild_visual_chunks_for_area(
		visual_root,
		map_data,
		EDITOR_JUNKS,
		origin,
		size,
		padding_tiles,
		TILE_SIZE,
		bake_collision,
		show_tile_lines
	)


# -------------------------------------------------------------------------
# Entity definitions
# -------------------------------------------------------------------------

func load_entity_definitions() -> void:
	entity_definitions = MapDefinitionService.load_entity_definitions(entity_definitions_path)


# -------------------------------------------------------------------------
# Loading / saving
# -------------------------------------------------------------------------

func get_map_json_path() -> String:
	return MapSaveLoadService.get_map_json_path(map_save_directory, map_name, map_json_extension)


func get_baked_scene_path() -> String:
	return MapSaveLoadService.get_baked_scene_path(map_save_directory, map_name, baked_scene_extension)


func set_selected_map_name(new_map_name: String, load_immediately: bool = true) -> void:
	var cleaned := new_map_name.strip_edges()
	if cleaned.is_empty():
		cleaned = "Map001"

	map_name = cleaned

	if load_immediately:
		load_map_from_json()
		rebuild_map()


func load_map_from_json() -> void:
	var json_path := get_map_json_path()
	var loaded := MapSaveLoadService.load_map_from_json(json_path, MAP_WIDTH, MAP_HEIGHT)

	map_data = loaded.get("map_data", [])
	resource_data = loaded.get("resource_data", [])
	building_data = loaded.get("building_data", [])

	if not FileAccess.file_exists(json_path):
		save_map_to_json()


func save_map_to_json() -> void:
	MapSaveLoadService.save_map_to_json(
		get_map_json_path(),
		map_save_directory,
		map_name,
		map_data,
		resource_data,
		building_data
	)


func save_map() -> void:
	var json_path := get_map_json_path()
	var scene_path := get_baked_scene_path()
	print("Saving map as JSON: ", json_path)
	print("Saving baked scene: ", scene_path)
	save_map_to_json()
	save_map_as_scene(scene_path)


func save_map_as_scene(path: String) -> void:
	MapSaveLoadService.save_map_as_scene(
		path,
		map_save_directory,
		map_data,
		map_name,
		TILE_SIZE,
		bake_collision,
		show_tile_lines
	)


# -------------------------------------------------------------------------
# Map creation / reset
# -------------------------------------------------------------------------

func create_new_empty_map(width: int, height: int) -> void:
	var empty_map := MapSaveLoadService.create_new_empty_map(width, height)
	map_data = empty_map.get("map_data", [])
	resource_data = empty_map.get("resource_data", [])
	building_data = empty_map.get("building_data", [])


func reset_map(
	width: int = MAP_WIDTH,
	height: int = MAP_HEIGHT,
	default_type: int = EnumMappings.GroundType.GRAS_TILE,
	default_height: float = 0.0,
) -> void:
	print("Resetting map...")

	map_data.clear()
	resource_data.clear()
	building_data.clear()

	for y in range(height):
		var terrain_row: Array = []
		var resource_row: Array = []
		var building_row: Array = []

		for x in range(width):
			terrain_row.append(MapTerrainService.make_cell(default_type, default_height))
			resource_row.append(MapResourceService.make_empty_resource_cell())
			building_row.append(MapBuildingService.make_empty_building_cell())

		map_data.append(terrain_row)
		resource_data.append(resource_row)
		building_data.append(building_row)

	save_map_to_json()
	rebuild_map()

	print("Map reset complete")


# -------------------------------------------------------------------------
# Grid wrappers, kept for compatibility with existing scripts
# -------------------------------------------------------------------------

func get_map_width() -> int:
	return MapGridService.get_map_width(map_data)


func get_map_height() -> int:
	return MapGridService.get_map_height(map_data)


func world_position_to_grid(pos: Vector3) -> Vector2i:
	return MapGridService.world_position_to_grid(pos, TILE_SIZE)


func grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	return MapGridService.grid_to_world_position(map_data, grid_pos, TILE_SIZE)


func get_tile_height(grid_pos: Vector2i) -> float:
	return MapGridService.get_tile_height(map_data, grid_pos)


func is_valid_grid_pos(grid_x: int, grid_y: int) -> bool:
	return MapGridService.is_valid_grid_pos(map_data, grid_x, grid_y)


func is_area_inside_map(origin: Vector2i, size: Vector2i) -> bool:
	return MapGridService.is_area_inside_map(map_data, origin, size)


func get_cells_in_area(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	return MapGridService.get_cells_in_area(origin, size)


# -------------------------------------------------------------------------
# Editor actions
# -------------------------------------------------------------------------

func change_tile(grid_x: int, grid_y: int) -> void:
	if tile_palette == null:
		return

	var grid_pos := Vector2i(grid_x, grid_y)
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return

	var selected_resource_type: int = int(tile_palette.selected_resource_type)
	var selected_building_type: int = int(tile_palette.selected_building_type)
	var selected_height_action: int = int(tile_palette.selected_height_action)
	var selected_ground_type: int = int(tile_palette.selected_ground_type)
	var selected_player: int = int(tile_palette.selected_player)
	var selected_orientation: int = int(tile_palette.selected_orientation)

	if selected_building_type != EnumMappings.BuildingType.NONE:
		var footprint := get_building_footprint(selected_building_type, selected_orientation)
		if place_building_at(grid_pos, selected_building_type, selected_player, selected_orientation):
			_commit_editor_change_for_area(grid_pos, footprint, false, true)
		return

	if selected_resource_type != EnumMappings.ResourceType.NONE:
		if place_resource_at(grid_pos, selected_resource_type, selected_orientation):
			_commit_editor_change_for_area(grid_pos, Vector2i.ONE, false, true)
		return

	if selected_height_action != EnumMappings.HeightMapping.HEIGHT_NONE:
		if change_height_at(grid_pos, selected_height_action, selected_ground_type):
			_commit_editor_change_for_area(grid_pos, Vector2i.ONE, true, false)
		return

	if change_ground_at(grid_pos, selected_ground_type):
		_commit_editor_change_for_area(grid_pos, Vector2i.ONE, false, false)


func _commit_editor_change(recalculate_ramps: bool) -> void:
	_commit_editor_change_for_area(
		Vector2i.ZERO,
		Vector2i(max(1, get_map_width()), max(1, get_map_height())),
		recalculate_ramps,
		true
	)


func _commit_editor_change_for_area(
	origin: Vector2i,
	size: Vector2i,
	recalculate_ramps: bool,
	refresh_outlines: bool
) -> void:
	if recalculate_ramps and auto_ramp_enabled:
		MapCornerService.recalculate_auto_ramps(map_data)

	map_data_changed.emit()

	var padding_tiles := 1 if recalculate_ramps and auto_ramp_enabled else 0
	rebuild_visual_chunks_for_area(origin, size, padding_tiles)

	if refresh_outlines:
		refresh_entity_outlines()


# -------------------------------------------------------------------------
# Terrain wrappers
# -------------------------------------------------------------------------

func change_ground_at(grid_pos: Vector2i, selected_ground_type: int) -> bool:
	return MapTerrainService.change_ground_at(map_data, grid_pos, selected_ground_type)


func change_height_at(grid_pos: Vector2i, height_action: int, selected_ground_type: int) -> bool:
	return MapTerrainService.change_height_at(
		map_data,
		resource_data,
		building_data,
		grid_pos,
		height_action,
		selected_ground_type,
		HEIGHT_STEP,
		MIN_HEIGHT,
		MAX_HEIGHT
	)


func can_edit_terrain(grid_pos: Vector2i) -> bool:
	return MapTerrainService.can_edit_terrain(map_data, resource_data, building_data, grid_pos)


# -------------------------------------------------------------------------
# Resource wrappers
# -------------------------------------------------------------------------

func place_resource_at(
	grid_pos: Vector2i,
	selected_resource_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH,
	count: int = 500
) -> bool:
	return MapResourceService.place_resource_at(
		map_data,
		resource_data,
		building_data,
		grid_pos,
		selected_resource_type,
		selected_orientation,
		count
	)


func remove_resource_at(grid_pos: Vector2i) -> bool:
	var changed := MapResourceService.remove_resource_at(map_data, resource_data, grid_pos)
	if changed:
		_commit_editor_change_for_area(grid_pos, Vector2i.ONE, false, true)
	return changed


func can_place_resource(grid_pos: Vector2i) -> bool:
	return MapResourceService.can_place_resource(map_data, resource_data, building_data, grid_pos)


func has_resource_at(grid_pos: Vector2i) -> bool:
	return MapResourceService.has_resource_at(map_data, resource_data, grid_pos)


func get_resource_footprint(selected_resource_type: int, selected_orientation: int = EnumMappings.Orientation.NORTH) -> Vector2i:
	return MapResourceService.get_resource_footprint(entity_definitions, selected_resource_type, selected_orientation)


func get_resource_color(selected_resource_type: int) -> Color:
	return MapResourceService.get_resource_color(entity_definitions, selected_resource_type)


func get_resource_definition(selected_resource_type: int) -> Dictionary:
	return MapResourceService.get_resource_definition(entity_definitions, selected_resource_type)


# -------------------------------------------------------------------------
# Building wrappers
# -------------------------------------------------------------------------

func place_building_at(
	origin: Vector2i,
	selected_building_type: int,
	selected_player: int = EnumMappings.Player.PLAYER_0,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	return MapBuildingService.place_building_at(
		map_data,
		resource_data,
		building_data,
		entity_definitions,
		origin,
		selected_building_type,
		selected_player,
		selected_orientation
	)


func remove_building_at(grid_pos: Vector2i) -> bool:
	var result := MapBuildingService.remove_building_at(map_data, building_data, entity_definitions, grid_pos)
	if bool(result.get("changed", false)):
		_commit_editor_change_for_area(result.get("origin", grid_pos), result.get("footprint", Vector2i.ONE), false, true)
		return true
	return false


func can_place_building(
	origin: Vector2i,
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	return MapBuildingService.can_place_building(
		map_data,
		resource_data,
		building_data,
		entity_definitions,
		origin,
		selected_building_type,
		selected_orientation
	)


func is_building_ground_valid(
	grid_pos: Vector2i,
	_selected_building_type: int,
	_selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	return MapBuildingService.is_building_ground_valid(map_data, grid_pos)


func has_building_at(grid_pos: Vector2i) -> bool:
	return MapBuildingService.has_building_at(map_data, building_data, grid_pos)


func get_building_origin_from_cell(building_cell: Dictionary) -> Vector2i:
	return MapBuildingService.get_building_origin_from_cell(building_cell)


func get_building_footprint(
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> Vector2i:
	return MapBuildingService.get_building_footprint(entity_definitions, selected_building_type, selected_orientation)


func get_building_color(selected_building_type: int) -> Color:
	return MapBuildingService.get_building_color(entity_definitions, selected_building_type)


func get_building_definition(selected_building_type: int) -> Dictionary:
	return MapBuildingService.get_building_definition(entity_definitions, selected_building_type)


# -------------------------------------------------------------------------
# Combined validation wrapper
# -------------------------------------------------------------------------

func is_tile_occupied(grid_pos: Vector2i) -> bool:
	return MapTerrainService.is_tile_occupied(map_data, resource_data, building_data, grid_pos)


# -------------------------------------------------------------------------
# Entity outline visuals
# -------------------------------------------------------------------------

func build_entity_outlines() -> void:
	entity_outline_root = MapEntityOutlineRenderer.build_entity_outlines(
		visual_root,
		map_data,
		resource_data,
		building_data,
		entity_definitions,
		show_entity_outlines,
		entity_outline_height,
		entity_outline_y_offset,
		TILE_SIZE
	)


func refresh_entity_outlines() -> void:
	entity_outline_root = MapEntityOutlineRenderer.refresh_entity_outlines(
		visual_root,
		entity_outline_root,
		map_data,
		resource_data,
		building_data,
		entity_definitions,
		show_entity_outlines,
		entity_outline_height,
		entity_outline_y_offset,
		TILE_SIZE
	)


func get_max_height_for_footprint(origin: Vector2i, footprint: Vector2i) -> float:
	return MapEntityOutlineRenderer.get_max_height_for_footprint(map_data, origin, footprint)


# -------------------------------------------------------------------------
# Utility / compatibility
# -------------------------------------------------------------------------

func recalculate_auto_ramps() -> void:
	MapCornerService.recalculate_auto_ramps(map_data)


func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func set_height_action(height_action: float) -> void:
	if is_equal_approx(height_action, HEIGHT_STEP):
		height_mode = EnumMappings.HeightMapping.HEIGHT_UP
	elif is_equal_approx(height_action, -HEIGHT_STEP):
		height_mode = EnumMappings.HeightMapping.HEIGHT_DOWN
	else:
		height_mode = EnumMappings.HeightMapping.HEIGHT_NONE

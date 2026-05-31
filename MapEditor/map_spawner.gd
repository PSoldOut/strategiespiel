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

const SAVE_VERSION: float = 0.2

const MAP_WIDTH: int = 128
const MAP_HEIGHT: int = 128
const EDITOR_JUNKS: int = 16
const TILE_SIZE: float = 2.0

const HEIGHT_STEP: float = 0.5
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 2.0

# Terrain data. This stays compatible with MapBaker.
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
var map_baker: MapBaker
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


func rebuild_map() -> void:
	clear_children(visual_root)

	if auto_ramp_enabled:
		recalculate_auto_ramps()

	build_visual_map()
	build_entity_outlines()
	call_deferred("_emit_map_spawned")


func _emit_map_spawned() -> void:
	map_spawned.emit(map_data)


func build_visual_map() -> void:
	if map_data.is_empty():
		return

	map_baker = MapBaker.new()
	map_baker.name = "MapBaker"
	map_baker.tile_size = TILE_SIZE
	map_baker.build_collision = bake_collision
	map_baker.show_tile_lines = show_tile_lines

	visual_root.add_child(map_baker)
	map_baker.bake_map(map_data)


# Compatibility wrapper, in case another script still calls the old name.
# It no longer builds chunks. It bakes the whole map.
func build_visual_chunks() -> void:
	build_visual_map()


func get_map_json_path() -> String:
	return map_save_directory.path_join(map_name + map_json_extension)


func get_baked_scene_path() -> String:
	return map_save_directory.path_join(map_name + baked_scene_extension)


func set_selected_map_name(new_map_name: String, load_immediately: bool = true) -> void:
	var cleaned := new_map_name.strip_edges()
	if cleaned.is_empty():
		cleaned = "Map001"

	# One source of truth. Both JSON and baked scene paths are derived from this.
	map_name = cleaned

	if load_immediately:
		load_map_from_json()
		rebuild_map()



# -------------------------------------------------------------------------
# Entity definitions
# -------------------------------------------------------------------------

func load_entity_definitions() -> void:
	entity_definitions.clear()

	if entity_definitions_path.is_empty():
		push_warning("MapSpawner: entity_definitions_path is empty.")
		return

	if not FileAccess.file_exists(entity_definitions_path):
		push_warning("MapSpawner: entity definitions file not found: " + entity_definitions_path)
		return

	var file := FileAccess.open(entity_definitions_path, FileAccess.READ)
	if file == null:
		push_warning("MapSpawner: could not open entity definitions: " + entity_definitions_path)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("MapSpawner: could not parse entity definitions: " + entity_definitions_path)
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("MapSpawner: entity definitions root must be a Dictionary.")
		return

	entity_definitions = json.data


func get_resource_definition(selected_resource_type: int) -> Dictionary:
	var resources: Dictionary = entity_definitions.get("resources", {})
	var key := str(int(selected_resource_type))

	if resources.has(key) and typeof(resources[key]) == TYPE_DICTIONARY:
		return resources[key]

	return {}


func get_building_definition(selected_building_type: int) -> Dictionary:
	var buildings: Dictionary = entity_definitions.get("buildings", {})
	var key := str(int(selected_building_type))

	if buildings.has(key) and typeof(buildings[key]) == TYPE_DICTIONARY:
		return buildings[key]

	return {}


func get_resource_color(selected_resource_type: int) -> Color:
	var definition := get_resource_definition(selected_resource_type)
	return color_from_definition(definition, Color(0.2, 0.8, 1.0, 1.0))


func get_building_color(selected_building_type: int) -> Color:
	var definition := get_building_definition(selected_building_type)
	return color_from_definition(definition, Color(1.0, 0.7, 0.2, 1.0))


func color_from_definition(definition: Dictionary, fallback: Color) -> Color:
	var color_value = definition.get("color", "")
	if typeof(color_value) == TYPE_STRING and not String(color_value).is_empty():
		return Color.html(String(color_value))

	return fallback


func get_resource_footprint(_selected_resource_type: int, _selected_orientation: int = EnumMappings.Orientation.NORTH) -> Vector2i:
	# Resources currently occupy exactly one map cell.
	# Add a "size" entry to the resource definition later if you want larger resources.
	return Vector2i.ONE

# -------------------------------------------------------------------------
# Loading / saving
# -------------------------------------------------------------------------

func load_map_from_json() -> void:
	var json_path := get_map_json_path()

	if not FileAccess.file_exists(json_path):
		create_new_empty_map(MAP_WIDTH, MAP_HEIGHT)
		save_map_to_json()
		return

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Could not open map JSON: " + json_path)
		create_new_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Could not parse map JSON: " + json_path)
		create_new_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		load_map_from_dictionary(data)
	elif typeof(data) == TYPE_ARRAY:
		# Very old format: file was directly terrain array.
		map_data = ensure_map_size(data, MAP_WIDTH, MAP_HEIGHT)
		resource_data = create_empty_resource_map(MAP_WIDTH, MAP_HEIGHT)
		building_data = create_empty_building_map(MAP_WIDTH, MAP_HEIGHT)
	else:
		create_new_empty_map(MAP_WIDTH, MAP_HEIGHT)


func load_map_from_dictionary(data: Dictionary) -> void:
	var loaded_width: int = int(data.get("width", MAP_WIDTH))
	var loaded_height: int = int(data.get("height", MAP_HEIGHT))

	if loaded_width <= 0:
		loaded_width = MAP_WIDTH
	if loaded_height <= 0:
		loaded_height = MAP_HEIGHT

	# Supports old "map_data" and new "terrain".
	var terrain_source: Array = data.get("terrain", data.get("map_data", []))
	map_data = ensure_map_size(terrain_source, loaded_width, loaded_height)

	# Supports both possible names while the format is still evolving.
	resource_data = ensure_resource_map_size(
		data.get("resources", data.get("resource_data", [])),
		loaded_width,
		loaded_height
	)

	building_data = ensure_building_map_size(
		data.get("buildings", data.get("building_data", [])),
		loaded_width,
		loaded_height
	)

	# Keep old maps valid even when they had only terrain.
	if resource_data.is_empty():
		resource_data = create_empty_resource_map(loaded_width, loaded_height)
	if building_data.is_empty():
		building_data = create_empty_building_map(loaded_width, loaded_height)


func save_map_to_json() -> void:
	ensure_save_directory()

	var json_path := get_map_json_path()
	var data := {
		"version": SAVE_VERSION,
		"map_name": map_name,
		"width": get_map_width(),
		"height": get_map_height(),

		# New names.
		"terrain": map_data,
		"resources": resource_data,
		"buildings": building_data,

		# Compatibility for older scripts that still read "map_data".
		"map_data": map_data
	}

	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save map JSON: " + json_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Saved JSON to: ", json_path)


func ensure_save_directory() -> void:
	if map_save_directory.is_empty():
		return

	var result := DirAccess.make_dir_recursive_absolute(map_save_directory)
	if result != OK and result != ERR_ALREADY_EXISTS:
		push_warning("Could not create map save directory: %s | Error: %s" % [map_save_directory, result])


# -------------------------------------------------------------------------
# Map creation / normalization
# -------------------------------------------------------------------------

func create_new_empty_map(width: int, height: int) -> void:
	map_data = create_empty_map(width, height)
	resource_data = create_empty_resource_map(width, height)
	building_data = create_empty_building_map(width, height)


func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell())
		result.append(row)

	return result


func create_empty_resource_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_empty_resource_cell())
		result.append(row)

	return result


func create_empty_building_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_empty_building_cell())
		result.append(row)

	return result


func ensure_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		for x in range(width):
			if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY and x < input_map[y].size():
				var value = input_map[y][x]

				if typeof(value) == TYPE_DICTIONARY:
					row.append(normalize_cell(value))
				else:
					row.append(make_cell(int(value)))
			else:
				row.append(make_cell())

		result.append(row)

	return result


func ensure_resource_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		for x in range(width):
			if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY and x < input_map[y].size():
				var value = input_map[y][x]
				if typeof(value) == TYPE_DICTIONARY:
					row.append(normalize_resource_cell(value))
				else:
					row.append(make_empty_resource_cell())
			else:
				row.append(make_empty_resource_cell())

		result.append(row)

	return result


func ensure_building_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		for x in range(width):
			if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY and x < input_map[y].size():
				var value = input_map[y][x]
				if typeof(value) == TYPE_DICTIONARY:
					row.append(normalize_building_cell(value))
				else:
					row.append(make_empty_building_cell())
			else:
				row.append(make_empty_building_cell())

		result.append(row)

	return result


func make_cell(
	tile_type: int = EnumMappings.GroundType.GRAS_TILE,
	height: float = 0.0
) -> Dictionary:
	return {
		"type": int(tile_type),
		"height": float(height),
		"corners": make_flat_corners(height)
	}


func make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": float(height),
		"se": float(height),
		"nw": float(height),
		"ne": float(height)
	}


func make_empty_resource_cell() -> Dictionary:
	return {
		"resource_type": EnumMappings.ResourceType.NONE,
		"orientation": EnumMappings.Orientation.NORTH,
		"count": 0
	}


func make_empty_building_cell() -> Dictionary:
	return {
		"building_type": EnumMappings.BuildingType.NONE,
		"player": EnumMappings.Player.WORLD,
		"orientation": EnumMappings.Orientation.NORTH,
		"is_center": false,
		"origin": {
			"x": -1,
			"y": -1
		}
	}


func normalize_cell(value: Dictionary) -> Dictionary:
	var tile_type: int = int(value.get("type", value.get("ground_type", EnumMappings.GroundType.GRAS_TILE)))
	var height: float = float(value.get("height", 0.0))
	var cell := make_cell(tile_type, height)

	# Important: keep saved auto-ramp corner data.
	# There are no ramp tiles anymore. Ramps are represented only by corner heights.
	if value.has("corners") and typeof(value["corners"]) == TYPE_DICTIONARY:
		var saved_corners: Dictionary = value["corners"]
		cell["corners"] = {
			"sw": float(saved_corners.get("sw", height)),
			"se": float(saved_corners.get("se", height)),
			"nw": float(saved_corners.get("nw", height)),
			"ne": float(saved_corners.get("ne", height))
		}

	return cell


func normalize_resource_cell(value: Dictionary) -> Dictionary:
	return {
		"resource_type": int(value.get("resource_type", value.get("resourcetype", EnumMappings.ResourceType.NONE))),
		"orientation": int(value.get("orientation", EnumMappings.Orientation.NORTH)),
		"count": int(value.get("count", 0))
	}


func normalize_building_cell(value: Dictionary) -> Dictionary:
	var origin_value = value.get("origin", {"x": -1, "y": -1})
	var origin_dict: Dictionary = {"x": -1, "y": -1}

	if typeof(origin_value) == TYPE_DICTIONARY:
		origin_dict = {
			"x": int(origin_value.get("x", -1)),
			"y": int(origin_value.get("y", -1))
		}
	else:
		# Fallback for an older possible flat format.
		origin_dict = {
			"x": int(value.get("origin_x", -1)),
			"y": int(value.get("origin_y", -1))
		}

	return {
		"building_type": int(value.get("building_type", value.get("buildingtype", EnumMappings.BuildingType.NONE))),
		"player": int(value.get("player", value.get("player_id", EnumMappings.Player.WORLD))),
		"orientation": int(value.get("orientation", EnumMappings.Orientation.NORTH)),
		"is_center": bool(value.get("is_center", value.get("center", false))),
		"origin": origin_dict
	}


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
			terrain_row.append(make_cell(default_type, default_height))
			resource_row.append(make_empty_resource_cell())
			building_row.append(make_empty_building_cell())

		map_data.append(terrain_row)
		resource_data.append(resource_row)
		building_data.append(building_row)

	save_map_to_json()
	rebuild_map()

	print("Map reset complete")


# -------------------------------------------------------------------------
# Grid helpers
# -------------------------------------------------------------------------

func get_map_width() -> int:
	if map_data.is_empty():
		return 0

	return map_data[0].size()


func get_map_height() -> int:
	return map_data.size()


func world_position_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / TILE_SIZE)),
		int(floor(pos.z / TILE_SIZE))
	)


func grid_to_world_position(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		float(grid_pos.x) * TILE_SIZE + TILE_SIZE * 0.5,
		get_tile_height(grid_pos),
		float(grid_pos.y) * TILE_SIZE + TILE_SIZE * 0.5
	)


func get_tile_height(grid_pos: Vector2i) -> float:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return 0.0

	return float(map_data[grid_pos.y][grid_pos.x].get("height", 0.0))


func is_valid_grid_pos(grid_x: int, grid_y: int) -> bool:
	return (
		grid_y >= 0
		and grid_y < map_data.size()
		and grid_x >= 0
		and grid_x < map_data[grid_y].size()
	)


func is_area_inside_map(origin: Vector2i, size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false

	return (
		origin.x >= 0
		and origin.y >= 0
		and origin.x + size.x <= get_map_width()
		and origin.y + size.y <= get_map_height()
	)


func get_cells_in_area(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			cells.append(Vector2i(x, y))

	return cells


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
		if place_building_at(grid_pos, selected_building_type, selected_player, selected_orientation):
			_commit_editor_change(false)
		return

	if selected_resource_type != EnumMappings.ResourceType.NONE:
		if place_resource_at(grid_pos, selected_resource_type, selected_orientation):
			_commit_editor_change(false)
		return

	if selected_height_action != EnumMappings.HeightMapping.HEIGHT_NONE:
		if change_height_at(grid_pos, selected_height_action, selected_ground_type):
			_commit_editor_change(true)
		return

	if change_ground_at(grid_pos, selected_ground_type):
		_commit_editor_change(false)


func _commit_editor_change(recalculate_ramps: bool) -> void:
	if recalculate_ramps and auto_ramp_enabled:
		recalculate_auto_ramps()

	map_data_changed.emit()
	rebuild_map()


func change_ground_at(grid_pos: Vector2i, selected_ground_type: int) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]
	var old_height: float = float(cell.get("height", 0.0))

	map_data[grid_pos.y][grid_pos.x] = make_cell(selected_ground_type, old_height)
	return true


func change_height_at(grid_pos: Vector2i, height_action: int, selected_ground_type: int) -> bool:
	if not can_edit_terrain(grid_pos):
		print("Cannot edit height: tile has resource or building at ", grid_pos)
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]

	var old_height: float = float(cell.get("height", 0.0))
	var new_height: float = old_height

	match height_action:
		EnumMappings.HeightMapping.HEIGHT_UP:
			new_height = clamp(old_height + HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)
		EnumMappings.HeightMapping.HEIGHT_DOWN:
			new_height = clamp(old_height - HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)
		_:
			return false

	if is_equal_approx(old_height, new_height):
		return false

	map_data[grid_pos.y][grid_pos.x] = make_cell(selected_ground_type, new_height)
	return true


func place_resource_at(
	grid_pos: Vector2i,
	selected_resource_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH,
	count: int = 500
) -> bool:
	if selected_resource_type == EnumMappings.ResourceType.NONE:
		return false

	if not can_place_resource(grid_pos):
		print("Cannot place resource at ", grid_pos)
		return false

	resource_data[grid_pos.y][grid_pos.x] = {
		"resource_type": selected_resource_type,
		"orientation": selected_orientation,
		"count": count
	}

	return true


func place_building_at(
	origin: Vector2i,
	selected_building_type: int,
	selected_player: int = EnumMappings.Player.PLAYER_0,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	if selected_building_type == EnumMappings.BuildingType.NONE:
		return false

	var footprint := get_building_footprint(selected_building_type, selected_orientation)

	if not can_place_building(origin, selected_building_type, selected_orientation):
		print("Cannot place building at ", origin, " footprint=", footprint)
		return false

	for cell_pos in get_cells_in_area(origin, footprint):
		building_data[cell_pos.y][cell_pos.x] = {
			"building_type": selected_building_type,
			"player": selected_player,
			"orientation": selected_orientation,
			"is_center": cell_pos == origin,
			"origin": {
				"x": origin.x,
				"y": origin.y
			}
		}

	return true


func remove_resource_at(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	if not has_resource_at(grid_pos):
		return false

	resource_data[grid_pos.y][grid_pos.x] = make_empty_resource_cell()
	return true


func remove_building_at(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	if not has_building_at(grid_pos):
		return false

	var building_cell: Dictionary = building_data[grid_pos.y][grid_pos.x]
	var origin := get_building_origin_from_cell(building_cell)

	if not is_valid_grid_pos(origin.x, origin.y):
		# Fallback: only clear the clicked tile if the saved origin is invalid.
		building_data[grid_pos.y][grid_pos.x] = make_empty_building_cell()
		return true

	var origin_cell: Dictionary = building_data[origin.y][origin.x]
	var stored_building_type: int = int(origin_cell.get("building_type", EnumMappings.BuildingType.NONE))
	var stored_orientation: int = int(origin_cell.get("orientation", EnumMappings.Orientation.NORTH))
	var footprint := get_building_footprint(stored_building_type, stored_orientation)

	for cell_pos in get_cells_in_area(origin, footprint):
		if not is_valid_grid_pos(cell_pos.x, cell_pos.y):
			continue

		var test_cell: Dictionary = building_data[cell_pos.y][cell_pos.x]
		var test_origin := get_building_origin_from_cell(test_cell)
		if test_origin == origin:
			building_data[cell_pos.y][cell_pos.x] = make_empty_building_cell()

	return true


# -------------------------------------------------------------------------
# Placement validation
# -------------------------------------------------------------------------

func can_edit_terrain(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	return not is_tile_occupied(grid_pos)


func can_place_resource(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	if is_tile_occupied(grid_pos):
		return false

	return true


func can_place_building(
	origin: Vector2i,
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	var footprint := get_building_footprint(selected_building_type, selected_orientation)

	if not is_area_inside_map(origin, footprint):
		return false

	for cell_pos in get_cells_in_area(origin, footprint):
		if is_tile_occupied(cell_pos):
			return false

		if not is_building_ground_valid(cell_pos, selected_building_type, selected_orientation):
			return false

	return true


func is_building_ground_valid(
	grid_pos: Vector2i,
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	# First simple rule:
	# buildings may only stand on flat cells.
	# Later you can extend this with allowed ground types, ramps, water, etc.
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]
	var height: float = float(cell.get("height", 0.0))
	var corners: Dictionary = cell.get("corners", make_flat_corners(height))

	return (
		is_equal_approx(float(corners.get("sw", height)), height)
		and is_equal_approx(float(corners.get("se", height)), height)
		and is_equal_approx(float(corners.get("nw", height)), height)
		and is_equal_approx(float(corners.get("ne", height)), height)
	)


func is_tile_occupied(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return true

	return has_resource_at(grid_pos) or has_building_at(grid_pos)


func has_resource_at(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	return int(resource_data[grid_pos.y][grid_pos.x].get("resource_type", EnumMappings.ResourceType.NONE)) != EnumMappings.ResourceType.NONE


func has_building_at(grid_pos: Vector2i) -> bool:
	if not is_valid_grid_pos(grid_pos.x, grid_pos.y):
		return false

	return int(building_data[grid_pos.y][grid_pos.x].get("building_type", EnumMappings.BuildingType.NONE)) != EnumMappings.BuildingType.NONE


func get_building_origin_from_cell(building_cell: Dictionary) -> Vector2i:
	var origin_value = building_cell.get("origin", {"x": -1, "y": -1})
	if typeof(origin_value) == TYPE_DICTIONARY:
		return Vector2i(
			int(origin_value.get("x", -1)),
			int(origin_value.get("y", -1))
		)

	return Vector2i(
		int(building_cell.get("origin_x", -1)),
		int(building_cell.get("origin_y", -1))
	)


func get_building_footprint(
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> Vector2i:
	if selected_building_type == EnumMappings.BuildingType.NONE:
		return Vector2i.ZERO

	var definition := get_building_definition(selected_building_type)
	var size_value = definition.get("size", {})
	var size := Vector2i.ONE

	if typeof(size_value) == TYPE_DICTIONARY:
		size = Vector2i(
			max(0, int(size_value.get("x", 1))),
			max(0, int(size_value.get("y", 1)))
		)
	else:
		# Fallback while the JSON is incomplete.
		match selected_building_type:
			EnumMappings.BuildingType.HOUSE:
				size = Vector2i(2, 2)
			_:
				size = Vector2i.ONE

	# Rotate non-square buildings.
	if selected_orientation == EnumMappings.Orientation.EAST or selected_orientation == EnumMappings.Orientation.WEST:
		return Vector2i(size.y, size.x)

	return size



# -------------------------------------------------------------------------
# Entity outline visuals
# -------------------------------------------------------------------------

func build_entity_outlines() -> void:
	if not show_entity_outlines:
		return

	if map_data.is_empty():
		return

	entity_outline_root = Node3D.new()
	entity_outline_root.name = "EntityOutlines"
	visual_root.add_child(entity_outline_root)

	spawn_resource_outlines()
	spawn_building_outlines()


func refresh_entity_outlines() -> void:
	# Use this if only entities changed and you do not want to rebuild the terrain mesh.
	if entity_outline_root != null and is_instance_valid(entity_outline_root):
		entity_outline_root.queue_free()
		entity_outline_root = null

	build_entity_outlines()


func spawn_resource_outlines() -> void:
	for y in range(resource_data.size()):
		if typeof(resource_data[y]) != TYPE_ARRAY:
			continue

		for x in range(resource_data[y].size()):
			var cell: Dictionary = resource_data[y][x]
			var stored_resource_type: int = int(cell.get("resource_type", EnumMappings.ResourceType.NONE))

			if stored_resource_type == EnumMappings.ResourceType.NONE:
				continue

			var stored_orientation: int = int(cell.get("orientation", EnumMappings.Orientation.NORTH))
			var footprint := get_resource_footprint(stored_resource_type, stored_orientation)
			var color := get_resource_color(stored_resource_type)
			var outline_name := "ResourceOutline_%s_%s" % [x, y]

			spawn_entity_outline(
				Vector2i(x, y),
				footprint,
				color,
				outline_name
			)


func spawn_building_outlines() -> void:
	for y in range(building_data.size()):
		if typeof(building_data[y]) != TYPE_ARRAY:
			continue

		for x in range(building_data[y].size()):
			var cell: Dictionary = building_data[y][x]
			var stored_building_type: int = int(cell.get("building_type", EnumMappings.BuildingType.NONE))

			if stored_building_type == EnumMappings.BuildingType.NONE:
				continue

			var origin := get_building_origin_from_cell(cell)
			if origin == Vector2i(-1, -1):
				origin = Vector2i(x, y)

			# Spawn exactly one outline per building, not one per occupied cell.
			if origin != Vector2i(x, y):
				continue

			var stored_orientation: int = int(cell.get("orientation", EnumMappings.Orientation.NORTH))
			var footprint := get_building_footprint(stored_building_type, stored_orientation)
			var color := get_building_color(stored_building_type)
			var outline_name := "BuildingOutline_%s_%s" % [x, y]

			spawn_entity_outline(
				origin,
				footprint,
				color,
				outline_name
			)


func spawn_entity_outline(
	origin: Vector2i,
	footprint: Vector2i,
	color: Color,
	outline_name: String = "EntityOutline"
) -> MeshInstance3D:
	if entity_outline_root == null:
		entity_outline_root = Node3D.new()
		entity_outline_root.name = "EntityOutlines"
		visual_root.add_child(entity_outline_root)

	var safe_footprint := Vector2i(max(1, footprint.x), max(1, footprint.y))

	var outline := MeshInstance3D.new()
	outline.name = outline_name
	outline.mesh = create_outline_box_mesh(safe_footprint)
	outline.material_override = create_outline_material(color)
	outline.global_position = get_outline_world_position(origin, safe_footprint)

	entity_outline_root.add_child(outline)
	return outline


func create_outline_box_mesh(footprint: Vector2i) -> ImmediateMesh:
	var size_x := float(footprint.x) * TILE_SIZE
	var size_z := float(footprint.y) * TILE_SIZE
	var half_x := size_x * 0.5
	var half_z := size_z * 0.5

	var bottom_y := 0.0
	var top_y := entity_outline_height

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
	_add_outline_line(mesh, b0, b1)
	_add_outline_line(mesh, b1, b2)
	_add_outline_line(mesh, b2, b3)
	_add_outline_line(mesh, b3, b0)
	_add_outline_line(mesh, t0, t1)
	_add_outline_line(mesh, t1, t2)
	_add_outline_line(mesh, t2, t3)
	_add_outline_line(mesh, t3, t0)
	_add_outline_line(mesh, b0, t0)
	_add_outline_line(mesh, b1, t1)
	_add_outline_line(mesh, b2, t2)
	_add_outline_line(mesh, b3, t3)
	mesh.surface_end()

	return mesh


func _add_outline_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)


func create_outline_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	return material


func get_outline_world_position(origin: Vector2i, footprint: Vector2i) -> Vector3:
	var base_height := get_max_height_for_footprint(origin, footprint)

	return Vector3(
		(float(origin.x) + float(footprint.x) * 0.5) * TILE_SIZE,
		base_height + entity_outline_y_offset,
		(float(origin.y) + float(footprint.y) * 0.5) * TILE_SIZE
	)


func get_max_height_for_footprint(origin: Vector2i, footprint: Vector2i) -> float:
	var max_height := -INF

	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			if not is_valid_grid_pos(x, y):
				continue

			var h := get_tile_height(Vector2i(x, y))
			if h > max_height:
				max_height = h

	if max_height == -INF:
		return 0.0

	return max_height

# -------------------------------------------------------------------------
# Baking / save scene
# -------------------------------------------------------------------------

func recalculate_auto_ramps() -> void:
	AutoRampBuilderAvg.recalculate_auto_ramps(map_data)


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


func save_map() -> void:
	var json_path := get_map_json_path()
	var scene_path := get_baked_scene_path()
	print("Saving map as JSON: ", json_path)
	print("Saving baked scene: ", scene_path)
	save_map_to_json()
	save_map_as_scene(scene_path)


func save_map_as_scene(path: String) -> void:
	if map_data.is_empty():
		push_error("Cannot save baked map: map_data is empty")
		return

	ensure_save_directory()

	var baker := MapBaker.new()
	baker.name = "MapBaker"
	baker.tile_size = TILE_SIZE
	baker.build_collision = bake_collision
	baker.show_tile_lines = show_tile_lines
	baker.save_baked_four_rotated_corners(map_data, path, map_name)

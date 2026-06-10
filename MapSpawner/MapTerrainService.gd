extends RefCounted
class_name MapTerrainService

static func make_cell(
	tile_type: int = EnumMappings.GroundType.GRAS_TILE,
	height: float = 0.0
) -> Dictionary:
	return {
		"type": int(tile_type),
		"height": float(height),
		"corners": MapCornerService.make_flat_corners(height)
	}


static func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell())
		result.append(row)

	return result


static func ensure_map_size(input_map: Array, width: int, height: int) -> Array:
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


static func normalize_cell(value: Dictionary) -> Dictionary:
	var tile_type: int = int(value.get("type", value.get("ground_type", EnumMappings.GroundType.GRAS_TILE)))
	var height: float = float(value.get("height", 0.0))
	var cell := make_cell(tile_type, height)

	# Keep saved corner data. Ramps are represented by corner heights.
	if value.has("corners") and typeof(value["corners"]) == TYPE_DICTIONARY:
		var saved_corners: Dictionary = value["corners"]
		cell["corners"] = {
			"sw": float(saved_corners.get("sw", height)),
			"se": float(saved_corners.get("se", height)),
			"nw": float(saved_corners.get("nw", height)),
			"ne": float(saved_corners.get("ne", height))
		}

	return cell


static func change_ground_at(map_data: Array, grid_pos: Vector2i, selected_ground_type: int) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]
	var old_height: float = float(cell.get("height", 0.0))

	map_data[grid_pos.y][grid_pos.x] = make_cell(selected_ground_type, old_height)
	return true


static func change_height_at(
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	grid_pos: Vector2i,
	height_action: int,
	selected_ground_type: int,
	height_step: float,
	min_height: float,
	max_height: float
) -> bool:
	if not can_edit_terrain(map_data, resource_data, building_data, grid_pos):
		print("Cannot edit height: tile has resource or building at ", grid_pos)
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]
	var old_height: float = float(cell.get("height", 0.0))
	var new_height: float = old_height

	match height_action:
		EnumMappings.HeightMapping.HEIGHT_UP:
			new_height = clamp(old_height + height_step, min_height, max_height)
		EnumMappings.HeightMapping.HEIGHT_DOWN:
			new_height = clamp(old_height - height_step, min_height, max_height)
		_:
			return false

	if is_equal_approx(old_height, new_height):
		return false

	map_data[grid_pos.y][grid_pos.x] = make_cell(selected_ground_type, new_height)
	return true


static func can_edit_terrain(map_data: Array, resource_data: Array, building_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	return not is_tile_occupied(map_data, resource_data, building_data, grid_pos)


static func is_tile_occupied(map_data: Array, resource_data: Array, building_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return true

	return (
		MapResourceService.has_resource_at(map_data, resource_data, grid_pos)
		or MapBuildingService.has_building_at(map_data, building_data, grid_pos)
	)

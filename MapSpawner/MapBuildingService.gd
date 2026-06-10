extends RefCounted
class_name MapBuildingService

static func make_empty_building_cell() -> Dictionary:
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


static func create_empty_building_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_empty_building_cell())
		result.append(row)

	return result


static func ensure_building_map_size(input_map: Array, width: int, height: int) -> Array:
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


static func normalize_building_cell(value: Dictionary) -> Dictionary:
	var origin_value = value.get("origin", {"x": -1, "y": -1})
	var origin_dict: Dictionary = {"x": -1, "y": -1}

	if typeof(origin_value) == TYPE_DICTIONARY:
		origin_dict = {
			"x": int(origin_value.get("x", -1)),
			"y": int(origin_value.get("y", -1))
		}
	else:
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


static func get_building_definition(entity_definitions: Dictionary, selected_building_type: int) -> Dictionary:
	var buildings: Dictionary = entity_definitions.get("buildings", {})
	var key := str(int(selected_building_type))

	if buildings.has(key) and typeof(buildings[key]) == TYPE_DICTIONARY:
		return buildings[key]

	return {}


static func get_building_color(entity_definitions: Dictionary, selected_building_type: int) -> Color:
	var definition := get_building_definition(entity_definitions, selected_building_type)
	return MapDefinitionService.color_from_definition(definition, Color(1.0, 0.7, 0.2, 1.0))


static func get_building_origin_from_cell(building_cell: Dictionary) -> Vector2i:
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


static func get_building_footprint(
	entity_definitions: Dictionary,
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> Vector2i:
	if selected_building_type == EnumMappings.BuildingType.NONE:
		return Vector2i.ZERO

	var definition := get_building_definition(entity_definitions, selected_building_type)
	var size_value = definition.get("size", {})
	var size := Vector2i.ONE

	if typeof(size_value) == TYPE_DICTIONARY:
		size = Vector2i(
			max(0, int(size_value.get("x", 1))),
			max(0, int(size_value.get("y", 1)))
		)
	else:
		match selected_building_type:
			EnumMappings.BuildingType.HOUSE:
				size = Vector2i(2, 2)
			_:
				size = Vector2i.ONE

	if selected_orientation == EnumMappings.Orientation.EAST or selected_orientation == EnumMappings.Orientation.WEST:
		return Vector2i(size.y, size.x)

	return size


static func has_building_at(map_data: Array, building_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	return int(building_data[grid_pos.y][grid_pos.x].get("building_type", EnumMappings.BuildingType.NONE)) != EnumMappings.BuildingType.NONE


static func is_building_ground_valid(map_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	var cell: Dictionary = map_data[grid_pos.y][grid_pos.x]
	return MapCornerService.is_cell_flat(cell)


static func can_place_building(
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	origin: Vector2i,
	selected_building_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	var footprint := get_building_footprint(entity_definitions, selected_building_type, selected_orientation)

	if not MapGridService.is_area_inside_map(map_data, origin, footprint):
		return false

	for cell_pos in MapGridService.get_cells_in_area(origin, footprint):
		if MapTerrainService.is_tile_occupied(map_data, resource_data, building_data, cell_pos):
			return false

		if not is_building_ground_valid(map_data, cell_pos):
			return false

	return true


static func place_building_at(
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	origin: Vector2i,
	selected_building_type: int,
	selected_player: int = EnumMappings.Player.PLAYER_0,
	selected_orientation: int = EnumMappings.Orientation.NORTH
) -> bool:
	if selected_building_type == EnumMappings.BuildingType.NONE:
		return false

	var footprint := get_building_footprint(entity_definitions, selected_building_type, selected_orientation)

	if not can_place_building(map_data, resource_data, building_data, entity_definitions, origin, selected_building_type, selected_orientation):
		print("Cannot place building at ", origin, " footprint=", footprint)
		return false

	for cell_pos in MapGridService.get_cells_in_area(origin, footprint):
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


static func remove_building_at(
	map_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	grid_pos: Vector2i
) -> Dictionary:
	# Returns {"changed": bool, "origin": Vector2i, "footprint": Vector2i}
	var result := {
		"changed": false,
		"origin": grid_pos,
		"footprint": Vector2i.ONE
	}

	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return result

	if not has_building_at(map_data, building_data, grid_pos):
		return result

	var building_cell: Dictionary = building_data[grid_pos.y][grid_pos.x]
	var origin := get_building_origin_from_cell(building_cell)

	if not MapGridService.is_valid_grid_pos(map_data, origin.x, origin.y):
		building_data[grid_pos.y][grid_pos.x] = make_empty_building_cell()
		result["changed"] = true
		return result

	var origin_cell: Dictionary = building_data[origin.y][origin.x]
	var stored_building_type: int = int(origin_cell.get("building_type", EnumMappings.BuildingType.NONE))
	var stored_orientation: int = int(origin_cell.get("orientation", EnumMappings.Orientation.NORTH))
	var footprint := get_building_footprint(entity_definitions, stored_building_type, stored_orientation)

	for cell_pos in MapGridService.get_cells_in_area(origin, footprint):
		if not MapGridService.is_valid_grid_pos(map_data, cell_pos.x, cell_pos.y):
			continue

		var test_cell: Dictionary = building_data[cell_pos.y][cell_pos.x]
		var test_origin := get_building_origin_from_cell(test_cell)
		if test_origin == origin:
			building_data[cell_pos.y][cell_pos.x] = make_empty_building_cell()

	result["changed"] = true
	result["origin"] = origin
	result["footprint"] = footprint
	return result

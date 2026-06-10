extends RefCounted
class_name MapResourceService

static func make_empty_resource_cell() -> Dictionary:
	return {
		"resource_type": EnumMappings.ResourceType.NONE,
		"orientation": EnumMappings.Orientation.NORTH,
		"count": 0
	}


static func create_empty_resource_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_empty_resource_cell())
		result.append(row)

	return result


static func ensure_resource_map_size(input_map: Array, width: int, height: int) -> Array:
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


static func normalize_resource_cell(value: Dictionary) -> Dictionary:
	return {
		"resource_type": int(value.get("resource_type", value.get("resourcetype", EnumMappings.ResourceType.NONE))),
		"orientation": int(value.get("orientation", EnumMappings.Orientation.NORTH)),
		"count": int(value.get("count", 0))
	}


static func get_resource_definition(entity_definitions: Dictionary, selected_resource_type: int) -> Dictionary:
	var resources: Dictionary = entity_definitions.get("resources", {})
	var key := str(int(selected_resource_type))

	if resources.has(key) and typeof(resources[key]) == TYPE_DICTIONARY:
		return resources[key]

	return {}


static func get_resource_color(entity_definitions: Dictionary, selected_resource_type: int) -> Color:
	var definition := get_resource_definition(entity_definitions, selected_resource_type)
	return MapDefinitionService.color_from_definition(definition, Color(0.2, 0.8, 1.0, 1.0))


static func get_resource_footprint(_entity_definitions: Dictionary, _selected_resource_type: int, _selected_orientation: int = EnumMappings.Orientation.NORTH) -> Vector2i:
	# Resources currently occupy exactly one map cell.
	return Vector2i.ONE


static func has_resource_at(map_data: Array, resource_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	return int(resource_data[grid_pos.y][grid_pos.x].get("resource_type", EnumMappings.ResourceType.NONE)) != EnumMappings.ResourceType.NONE


static func can_place_resource(map_data: Array, resource_data: Array, building_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	if MapTerrainService.is_tile_occupied(map_data, resource_data, building_data, grid_pos):
		return false

	return true


static func place_resource_at(
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	grid_pos: Vector2i,
	selected_resource_type: int,
	selected_orientation: int = EnumMappings.Orientation.NORTH,
	count: int = 500
) -> bool:
	if selected_resource_type == EnumMappings.ResourceType.NONE:
		return false

	if not can_place_resource(map_data, resource_data, building_data, grid_pos):
		print("Cannot place resource at ", grid_pos)
		return false

	resource_data[grid_pos.y][grid_pos.x] = {
		"resource_type": selected_resource_type,
		"orientation": selected_orientation,
		"count": count
	}

	return true


static func remove_resource_at(map_data: Array, resource_data: Array, grid_pos: Vector2i) -> bool:
	if not MapGridService.is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return false

	if not has_resource_at(map_data, resource_data, grid_pos):
		return false

	resource_data[grid_pos.y][grid_pos.x] = make_empty_resource_cell()
	return true

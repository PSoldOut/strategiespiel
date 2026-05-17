extends RefCounted
class_name MapDataTools


static func make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": float(height),
		"se": float(height),
		"nw": float(height),
		"ne": float(height),
	}


static func make_cell(
	tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	height: float = 0.0
) -> Dictionary:
	return {
		"type": int(tile_type),
		"height": float(height),
		"corners": make_flat_corners(height),
	}


static func normalize_cell(value: Dictionary) -> Dictionary:
	var tile_type: int = int(value.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var height: float = float(value.get("height", 0.0))
	var cell := make_cell(tile_type, height)

	# There are no ramp tiles anymore. Ramps are represented only by corner heights.
	if value.has("corners") and typeof(value["corners"]) == TYPE_DICTIONARY:
		var saved_corners: Dictionary = value["corners"]
		cell["corners"] = {
			"sw": float(saved_corners.get("sw", height)),
			"se": float(saved_corners.get("se", height)),
			"nw": float(saved_corners.get("nw", height)),
			"ne": float(saved_corners.get("ne", height)),
		}

	return cell


static func duplicate_cell(cell: Dictionary) -> Dictionary:
	var result := cell.duplicate(true)
	if result.has("corners") and typeof(result["corners"]) == TYPE_DICTIONARY:
		result["corners"] = result["corners"].duplicate(true)
	return result


static func duplicate_map_data(source_map: Array) -> Array:
	var result: Array = []

	for row in source_map:
		var new_row: Array = []
		if typeof(row) == TYPE_ARRAY:
			for cell in row:
				if typeof(cell) == TYPE_DICTIONARY:
					new_row.append(duplicate_cell(cell))
				else:
					new_row.append(cell)
		result.append(new_row)

	return result


static func create_empty_map(
	width: int,
	height: int,
	default_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	default_height: float = 0.0
) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell(default_type, default_height))
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


static func get_cell_safe(map_data: Array, x: int, y: int) -> Dictionary:
	if y < 0 or y >= map_data.size():
		return make_cell()

	if typeof(map_data[y]) != TYPE_ARRAY:
		return make_cell()

	if x < 0 or x >= map_data[y].size():
		return make_cell()

	if typeof(map_data[y][x]) != TYPE_DICTIONARY:
		return make_cell()

	return map_data[y][x]


static func get_cell_corner_heights(cell: Dictionary) -> Dictionary:
	var h := float(cell.get("height", 0.0))

	if cell.has("corners") and typeof(cell["corners"]) == TYPE_DICTIONARY:
		var c: Dictionary = cell["corners"]
		return {
			"h_sw": float(c.get("sw", h)),
			"h_se": float(c.get("se", h)),
			"h_nw": float(c.get("nw", h)),
			"h_ne": float(c.get("ne", h)),
		}

	return {
		"h_sw": h,
		"h_se": h,
		"h_nw": h,
		"h_ne": h,
	}

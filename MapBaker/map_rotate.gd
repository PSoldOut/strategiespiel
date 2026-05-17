extends RefCounted
class_name MapRotate


static func rotate_map_data(source_map: Array, rotation_steps: int = 0) -> Array:
	var steps := posmod(rotation_steps, 4)
	var result: Array = MapDataTools.duplicate_map_data(source_map)

	for i in range(steps):
		result = rotate_map_data_90_cw(result)

	return result


static func rotate_map_data_90_cw(source_map: Array) -> Array:
	var source_h := source_map.size()
	if source_h <= 0:
		return []

	var source_w: int = source_map[0].size()
	var result: Array = []

	# 90° rotation swaps width/height.
	for y in range(source_w):
		var row: Array = []
		for x in range(source_h):
			row.append({})
		result.append(row)

	for source_y in range(source_h):
		if typeof(source_map[source_y]) != TYPE_ARRAY:
			continue

		for source_x in range(source_map[source_y].size()):
			var target_x := source_h - 1 - source_y
			var target_y := source_x
			var source_cell = source_map[source_y][source_x]

			if typeof(source_cell) == TYPE_DICTIONARY:
				result[target_y][target_x] = rotate_cell_90_cw(source_cell)
			else:
				result[target_y][target_x] = source_cell

	return result


static func rotate_cell(source_cell: Dictionary, rotation_steps: int = 0) -> Dictionary:
	var steps := posmod(rotation_steps, 4)
	var result := MapDataTools.duplicate_cell(source_cell)

	for i in range(steps):
		result = rotate_cell_90_cw(result)

	return result


static func rotate_cell_90_cw(source_cell: Dictionary) -> Dictionary:
	var result := MapDataTools.duplicate_cell(source_cell)
	var base_height: float = float(source_cell.get("height", 0.0))
	var c: Dictionary = source_cell.get("corners", {})

	# Source corner movement for a 90° clockwise rotation:
	# nw -> ne, ne -> se, se -> sw, sw -> nw
	result["corners"] = {
		"nw": float(c.get("sw", base_height)),
		"ne": float(c.get("nw", base_height)),
		"se": float(c.get("ne", base_height)),
		"sw": float(c.get("se", base_height)),
	}

	return result

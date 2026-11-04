extends RefCounted
class_name AutoRampBuilderAvg
## Calculates shared terrain corners from the average height of touching cells.


static func recalculate_auto_ramps(map_data: Array) -> void:
	if map_data.is_empty():
		return

	var map_height: int = map_data.size()
	var map_width: int = map_data[0].size()
	if map_width <= 0:
		return

	_reset_all_corners_to_base_height(map_data)
	for vertex_y in range(map_height + 1):
		for vertex_x in range(map_width + 1):
			_apply_average_height_to_shared_vertex(map_data, vertex_x, vertex_y)


static func recalculate_auto_ramps_for_area(
	map_data: Array,
	origin: Vector2i,
	size: Vector2i,
	padding_tiles: int = 2
) -> void:
	if map_data.is_empty():
		return

	var map_height: int = map_data.size()
	var map_width: int = map_data[0].size()
	if map_width <= 0 or map_height <= 0:
		return

	var safe_size := Vector2i(maxi(1, size.x), maxi(1, size.y))
	var start_x := clampi(origin.x - padding_tiles, 0, map_width - 1)
	var start_y := clampi(origin.y - padding_tiles, 0, map_height - 1)
	var end_x := clampi(origin.x + safe_size.x - 1 + padding_tiles, 0, map_width - 1)
	var end_y := clampi(origin.y + safe_size.y - 1 + padding_tiles, 0, map_height - 1)

	_reset_corners_to_base_height_for_area(map_data, start_x, start_y, end_x, end_y)
	for vertex_y in range(start_y, end_y + 2):
		for vertex_x in range(start_x, end_x + 2):
			_apply_average_height_to_shared_vertex(map_data, vertex_x, vertex_y)


static func _reset_all_corners_to_base_height(map_data: Array) -> void:
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var height := float(cell.get("height", 0.0))
			cell["corners"] = _make_flat_corners(height)
			map_data[y][x] = cell


static func _reset_corners_to_base_height_for_area(
	map_data: Array,
	start_x: int,
	start_y: int,
	end_x: int,
	end_y: int
) -> void:
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			var cell: Dictionary = map_data[y][x]
			var height := float(cell.get("height", 0.0))
			cell["corners"] = _make_flat_corners(height)
			map_data[y][x] = cell


static func _apply_average_height_to_shared_vertex(
	map_data: Array,
	vertex_x: int,
	vertex_y: int
) -> void:
	var touching := _get_tiles_touching_vertex(map_data, vertex_x, vertex_y)
	if touching.is_empty():
		return

	var sum_height := 0.0
	for item: Dictionary in touching:
		var cell: Dictionary = map_data[int(item["y"])][int(item["x"])]
		sum_height += float(cell.get("height", 0.0))

	var average_height := sum_height / float(touching.size())
	for item: Dictionary in touching:
		_set_single_corner(
			map_data,
			int(item["x"]),
			int(item["y"]),
			str(item["corner"]),
			average_height
		)


static func _get_tiles_touching_vertex(
	map_data: Array,
	vertex_x: int,
	vertex_y: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_append_touching_tile(map_data, result, vertex_x - 1, vertex_y - 1, "se")
	_append_touching_tile(map_data, result, vertex_x, vertex_y - 1, "sw")
	_append_touching_tile(map_data, result, vertex_x - 1, vertex_y, "ne")
	_append_touching_tile(map_data, result, vertex_x, vertex_y, "nw")
	return result


static func _append_touching_tile(
	map_data: Array,
	result: Array[Dictionary],
	grid_x: int,
	grid_y: int,
	corner_name: String
) -> void:
	if not _is_valid_grid_pos(map_data, grid_x, grid_y):
		return

	result.append({
		"x": grid_x,
		"y": grid_y,
		"corner": corner_name,
	})


static func _set_single_corner(
	map_data: Array,
	grid_x: int,
	grid_y: int,
	corner_name: String,
	value: float
) -> void:
	var cell: Dictionary = map_data[grid_y][grid_x]
	var height := float(cell.get("height", 0.0))
	var corners: Dictionary = cell.get("corners", _make_flat_corners(height))
	corners[corner_name] = value
	cell["corners"] = corners
	map_data[grid_y][grid_x] = cell


static func _make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": height,
		"se": height,
		"nw": height,
		"ne": height,
	}


static func _is_valid_grid_pos(map_data: Array, grid_x: int, grid_y: int) -> bool:
	return (
		grid_y >= 0
		and grid_y < map_data.size()
		and grid_x >= 0
		and grid_x < map_data[grid_y].size()
	)

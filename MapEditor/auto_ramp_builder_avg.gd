extends RefCounted
class_name AutoRampBuilderAvg


# Shared-vertex / average-corner auto ramp system.
#
# New rule:
# - There is no max-step-height check anymore.
# - Every grid vertex is calculated once.
# - The height of that vertex is the average height of all touching cells.
# - The result is written back into the corresponding corner of every touching cell.
#
# Example for an inner vertex touched by four cells:
#   nw_cell.height + ne_cell.height + sw_cell.height + se_cell.height / 4
#
# Border vertices naturally use only 1 or 2 touching cells.
static func recalculate_auto_ramps(map_data: Array) -> void:
	if map_data.is_empty():
		return

	var map_h: int = map_data.size()
	var map_w: int = map_data[0].size()

	if map_w <= 0:
		return

	# Start clean. Every tile receives flat corners first.
	# Afterwards every shared vertex overwrites the affected corners.
	_reset_all_corners_to_base_height(map_data)

	# A map with WxH cells has (W+1)x(H+1) shared vertices.
	for vertex_y in range(map_h + 1):
		for vertex_x in range(map_w + 1):
			_apply_average_height_to_shared_vertex(map_data, vertex_x, vertex_y)


static func _reset_all_corners_to_base_height(map_data: Array) -> void:
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))
			cell["corners"] = _make_flat_corners(h)
			map_data[y][x] = cell


static func _apply_average_height_to_shared_vertex(
	map_data: Array,
	vertex_x: int,
	vertex_y: int
) -> void:
	var touching: Array = _get_tiles_touching_vertex(map_data, vertex_x, vertex_y)
	if touching.is_empty():
		return

	var sum_height: float = 0.0

	for item in touching:
		var tx: int = int(item["x"])
		var ty: int = int(item["y"])
		var cell: Dictionary = map_data[ty][tx]
		sum_height += float(cell.get("height", 0.0))

	var avg_height: float = sum_height / float(touching.size())

	for item in touching:
		var tx: int = int(item["x"])
		var ty: int = int(item["y"])
		var corner_name: String = str(item["corner"])
		_set_single_corner(map_data, tx, ty, corner_name, avg_height)


static func _get_tiles_touching_vertex(map_data: Array, vertex_x: int, vertex_y: int) -> Array:
	var result: Array = []

	# Tile north-west of the vertex touches it with its south-east corner.
	_append_touching_tile(map_data, result, vertex_x - 1, vertex_y - 1, "se")

	# Tile north-east of the vertex touches it with its south-west corner.
	_append_touching_tile(map_data, result, vertex_x, vertex_y - 1, "sw")

	# Tile south-west of the vertex touches it with its north-east corner.
	_append_touching_tile(map_data, result, vertex_x - 1, vertex_y, "ne")

	# Tile south-east of the vertex touches it with its north-west corner.
	_append_touching_tile(map_data, result, vertex_x, vertex_y, "nw")

	return result


static func _append_touching_tile(
	map_data: Array,
	result: Array,
	grid_x: int,
	grid_y: int,
	corner_name: String
) -> void:
	if not _is_valid_grid_pos(map_data, grid_x, grid_y):
		return

	result.append({
		"x": grid_x,
		"y": grid_y,
		"corner": corner_name
	})


static func _set_single_corner(
	map_data: Array,
	grid_x: int,
	grid_y: int,
	corner_name: String,
	value: float
) -> void:
	var cell: Dictionary = map_data[grid_y][grid_x]
	var height: float = float(cell.get("height", 0.0))
	var corners: Dictionary = cell.get("corners", _make_flat_corners(height))
	corners[corner_name] = float(value)
	cell["corners"] = corners
	map_data[grid_y][grid_x] = cell


static func _make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": float(height),
		"se": float(height),
		"nw": float(height),
		"ne": float(height)
	}


static func _is_valid_grid_pos(map_data: Array, grid_x: int, grid_y: int) -> bool:
	return (
		grid_y >= 0
		and grid_y < map_data.size()
		and grid_x >= 0
		and grid_x < map_data[grid_y].size()
	)

extends RefCounted
class_name AutoRampBuilder


# Shared vertex based auto-ramp system.
# A corner is not owned by one tile only. Up to four tiles touch the same vertex.
# Therefore every shared vertex is calculated once and then written back to all
# touching tile corners. This prevents neighbouring edits from overwriting each
# other with wrong corner resets.
static func recalculate_auto_ramps(map_data: Array, height_step: float) -> void:
	_reset_all_corners_to_base_height(map_data)

	var map_h := map_data.size()
	if map_h <= 0:
		return

	var map_w: int = map_data[0].size()

	# Vertices are grid intersections, so a 32x32 map has 33x33 vertices.
	for vertex_y in range(map_h + 1):
		for vertex_x in range(map_w + 1):
			_recalculate_shared_vertex(map_data, vertex_x, vertex_y, height_step)


static func _reset_all_corners_to_base_height(map_data: Array) -> void:
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))
			cell["corners"] = _make_flat_corners(h)
			map_data[y][x] = cell


static func _recalculate_shared_vertex(
	map_data: Array,
	vertex_x: int,
	vertex_y: int,
	height_step: float
) -> void:
	var touching := _get_tiles_touching_vertex(map_data, vertex_x, vertex_y)
	if touching.is_empty():
		return

	var first: Dictionary = touching[0]
	var first_cell: Dictionary = map_data[int(first["y"])][int(first["x"])]
	var min_h: float = float(first_cell.get("height", 0.0))
	var max_h: float = min_h

	for item in touching:
		var tx: int = int(item["x"])
		var ty: int = int(item["y"])
		var cell: Dictionary = map_data[ty][tx]
		var h: float = float(cell.get("height", 0.0))
		min_h = min(min_h, h)
		max_h = max(max_h, h)

	# Same height means the flat reset is already correct.
	if is_equal_approx(max_h, min_h):
		return

	# Only one height step can become an automatic ramp.
	# Bigger steps stay vertical/steep instead of creating broken multi-height corners.
	if not is_equal_approx(max_h - min_h, height_step):
		return

	# Shared rule: keep the edited plateau/hole visible.
	# For normal positive ramps, 0.0 -> 0.5 chooses 0.5.
	# For holes, 0.0 -> -0.5 chooses -0.5.
	# In other words: choose the height farther away from zero.
	var shared_height := _get_dominant_vertex_height(min_h, max_h)

	for item in touching:
		var tx: int = int(item["x"])
		var ty: int = int(item["y"])
		var corner_name: String = str(item["corner"])
		_set_single_corner(map_data, tx, ty, corner_name, shared_height)


static func _get_dominant_vertex_height(min_h: float, max_h: float) -> float:
	if abs(min_h) > abs(max_h):
		return min_h
	return max_h


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
	corners[corner_name] = value
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

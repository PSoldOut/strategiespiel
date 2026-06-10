extends RefCounted
class_name MapGridService

static func get_map_width(map_data: Array) -> int:
	if map_data.is_empty():
		return 0
	return map_data[0].size()


static func get_map_height(map_data: Array) -> int:
	return map_data.size()


static func is_valid_grid_pos(map_data: Array, grid_x: int, grid_y: int) -> bool:
	return (
		grid_y >= 0
		and grid_y < map_data.size()
		and grid_x >= 0
		and grid_x < map_data[grid_y].size()
	)


static func is_area_inside_map(map_data: Array, origin: Vector2i, size: Vector2i) -> bool:
	if size.x <= 0 or size.y <= 0:
		return false

	return (
		origin.x >= 0
		and origin.y >= 0
		and origin.x + size.x <= get_map_width(map_data)
		and origin.y + size.y <= get_map_height(map_data)
	)


static func get_cells_in_area(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for y in range(origin.y, origin.y + size.y):
		for x in range(origin.x, origin.x + size.x):
			cells.append(Vector2i(x, y))

	return cells


static func world_position_to_grid(pos: Vector3, tile_size: float) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / tile_size)),
		int(floor(pos.z / tile_size))
	)


static func grid_to_world_position(map_data: Array, grid_pos: Vector2i, tile_size: float) -> Vector3:
	return Vector3(
		float(grid_pos.x) * tile_size + tile_size * 0.5,
		get_tile_height(map_data, grid_pos),
		float(grid_pos.y) * tile_size + tile_size * 0.5
	)


static func get_tile_height(map_data: Array, grid_pos: Vector2i) -> float:
	if not is_valid_grid_pos(map_data, grid_pos.x, grid_pos.y):
		return 0.0

	return float(map_data[grid_pos.y][grid_pos.x].get("height", 0.0))

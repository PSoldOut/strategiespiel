extends RefCounted
class_name MapChunkRenderer

static func build_visual_chunks(
	visual_root: Node3D,
	map_data: Array,
	chunk_count_value: int,
	tile_size: float,
	bake_collision: bool,
	show_tile_lines: bool
) -> void:
	if map_data.is_empty():
		return

	var chunk_count := get_editor_chunk_count(chunk_count_value)

	for chunk_y in range(chunk_count):
		for chunk_x in range(chunk_count):
			bake_visual_chunk(visual_root, map_data, chunk_count_value, chunk_x, chunk_y, tile_size, bake_collision, show_tile_lines)


static func get_editor_chunk_count(chunk_count_value: int) -> int:
	return max(1, chunk_count_value)


static func get_editor_chunk_size(map_data: Array, chunk_count_value: int) -> Vector2i:
	var chunk_count := get_editor_chunk_count(chunk_count_value)
	var map_width := MapGridService.get_map_width(map_data)
	var map_height := MapGridService.get_map_height(map_data)

	if map_width <= 0 or map_height <= 0:
		return Vector2i.ZERO

	return Vector2i(
		int(ceil(float(map_width) / float(chunk_count))),
		int(ceil(float(map_height) / float(chunk_count)))
	)


static func get_visual_chunk_name(chunk_x: int, chunk_y: int) -> String:
	return "MapBaker_%02d_%02d" % [chunk_x, chunk_y]


static func bake_visual_chunk(
	visual_root: Node3D,
	map_data: Array,
	chunk_count_value: int,
	chunk_x: int,
	chunk_y: int,
	tile_size: float,
	bake_collision: bool,
	show_tile_lines: bool
) -> void:
	if map_data.is_empty() or visual_root == null:
		return

	var chunk_count := get_editor_chunk_count(chunk_count_value)
	if chunk_x < 0 or chunk_y < 0 or chunk_x >= chunk_count or chunk_y >= chunk_count:
		return

	var map_width := MapGridService.get_map_width(map_data)
	var map_height := MapGridService.get_map_height(map_data)
	var chunk_size := get_editor_chunk_size(map_data, chunk_count_value)

	if map_width <= 0 or map_height <= 0 or chunk_size == Vector2i.ZERO:
		return

	var start_x := chunk_x * chunk_size.x
	var start_y := chunk_y * chunk_size.y

	if start_x >= map_width or start_y >= map_height:
		return

	var end_x :int= min(start_x + chunk_size.x, map_width)
	var end_y :int= min(start_y + chunk_size.y, map_height)
	var chunk_map := get_terrain_chunk(map_data, start_x, start_y, end_x, end_y)

	if chunk_map.is_empty():
		return

	var chunk_baker := MapBaker.new()
	chunk_baker.name = get_visual_chunk_name(chunk_x, chunk_y)
	chunk_baker.tile_size = tile_size
	chunk_baker.build_collision = bake_collision
	chunk_baker.show_tile_lines = show_tile_lines
	chunk_baker.position = Vector3(
		float(start_x) * tile_size,
		0.0,
		float(start_y) * tile_size
	)

	visual_root.add_child(chunk_baker)
	chunk_baker.bake_map(chunk_map)


static func remove_visual_chunk(visual_root: Node3D, chunk_x: int, chunk_y: int) -> void:
	if visual_root == null:
		return

	var chunk_name := get_visual_chunk_name(chunk_x, chunk_y)
	var old_chunk := visual_root.get_node_or_null(chunk_name)
	if old_chunk == null:
		return

	visual_root.remove_child(old_chunk)
	old_chunk.queue_free()


static func rebuild_visual_chunk(
	visual_root: Node3D,
	map_data: Array,
	chunk_count_value: int,
	chunk_x: int,
	chunk_y: int,
	tile_size: float,
	bake_collision: bool,
	show_tile_lines: bool
) -> void:
	remove_visual_chunk(visual_root, chunk_x, chunk_y)
	bake_visual_chunk(visual_root, map_data, chunk_count_value, chunk_x, chunk_y, tile_size, bake_collision, show_tile_lines)


static func rebuild_visual_chunks_for_area(
	visual_root: Node3D,
	map_data: Array,
	chunk_count_value: int,
	origin: Vector2i,
	size: Vector2i,
	padding_tiles: int,
	tile_size: float,
	bake_collision: bool,
	show_tile_lines: bool
) -> void:
	if map_data.is_empty():
		return

	var map_width := MapGridService.get_map_width(map_data)
	var map_height := MapGridService.get_map_height(map_data)
	var chunk_size := get_editor_chunk_size(map_data, chunk_count_value)
	var chunk_count := get_editor_chunk_count(chunk_count_value)

	if map_width <= 0 or map_height <= 0 or chunk_size == Vector2i.ZERO:
		return

	var safe_size := Vector2i(max(1, size.x), max(1, size.y))
	var start_x :int= clamp(origin.x - padding_tiles, 0, map_width - 1)
	var start_y :int= clamp(origin.y - padding_tiles, 0, map_height - 1)
	var end_x :int= clamp(origin.x + safe_size.x - 1 + padding_tiles, 0, map_width - 1)
	var end_y :int= clamp(origin.y + safe_size.y - 1 + padding_tiles, 0, map_height - 1)

	var start_chunk_x :int= clamp(int(floor(float(start_x) / float(chunk_size.x))), 0, chunk_count - 1)
	var start_chunk_y :int= clamp(int(floor(float(start_y) / float(chunk_size.y))), 0, chunk_count - 1)
	var end_chunk_x :int= clamp(int(floor(float(end_x) / float(chunk_size.x))), 0, chunk_count - 1)
	var end_chunk_y :int= clamp(int(floor(float(end_y) / float(chunk_size.y))), 0, chunk_count - 1)

	for chunk_y in range(start_chunk_y, end_chunk_y + 1):
		for chunk_x in range(start_chunk_x, end_chunk_x + 1):
			rebuild_visual_chunk(visual_root, map_data, chunk_count_value, chunk_x, chunk_y, tile_size, bake_collision, show_tile_lines)


static func get_terrain_chunk(map_data: Array, start_x: int, start_y: int, end_x: int, end_y: int) -> Array:
	var chunk: Array = []

	for y in range(start_y, end_y):
		var row: Array = []

		for x in range(start_x, end_x):
			row.append(map_data[y][x])

		chunk.append(row)

	return chunk

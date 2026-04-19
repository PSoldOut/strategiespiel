extends Node
const ChunkBuilderScene = preload("res://ChunkBuilder.gd")

@export var map_file_path: String = "res://map_save.json"

const MAP_WIDTH: int = 16
const MAP_HEIGHT: int = 16
const TILE_SIZE: float = 2.0

var map_data: Array = []
func _ready() -> void:
	load_map_from_json(map_file_path)

	var chunk_builder := ChunkBuilder.new()
	add_child(chunk_builder)

	chunk_builder.tile_size = TILE_SIZE
	chunk_builder.build_from_map(map_data, 0, 0, 16, 16)
	
func spawn_baked_map(chunk_size: int = 16) -> void:
	clear_old_tiles()

	var map_h := map_data.size()
	if map_h == 0:
		print("map_data empty")
		return

	var map_w : int = map_data[0].size()

	for chunk_y in range(0, map_h, chunk_size):
		for chunk_x in range(0, map_w, chunk_size):
			var chunk_builder := ChunkBuilder.new()
			add_child(chunk_builder)

			chunk_builder.tile_size = TILE_SIZE
			chunk_builder.tile_height_step = 1.0
			chunk_builder.position = Vector3(chunk_x * TILE_SIZE, 0.0, chunk_y * TILE_SIZE)

			chunk_builder.build_from_map(
				map_data,
				chunk_x,
				chunk_y,
				min(chunk_size, map_w - chunk_x),
				min(chunk_size, map_h - chunk_y)
			)
			
func load_map_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Map file not found: " + path + " -> using empty map")
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open map file: " + path)
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_error("JSON parse error in file: " + path)
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		map_data = ensure_map_size(data.get("map_data", []), MAP_WIDTH, MAP_HEIGHT)
	elif typeof(data) == TYPE_ARRAY:
		# Fallback für alte Dateien
		map_data = ensure_map_size(data, MAP_WIDTH, MAP_HEIGHT)
	else:
		push_error("Invalid map JSON format")
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		
func ensure_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY:
			var source_row: Array = input_map[y]

			for x in range(width):
				if x < source_row.size():
					var value = source_row[x]

					if typeof(value) == TYPE_DICTIONARY:
						row.append({
							"type": value.get("type", EnumMappings.TileEnums.STANDAD_TILE),
							"height": float(value.get("height", 0.0)),
							"ramp": value.get("ramp", EnumMappings.NEWSEnums.NORTH)
						})
					else:
						# Fallback für alte Maps mit nur int TileType
						row.append(make_cell(value, 0.0, EnumMappings.NEWSEnums.NORTH))
				else:
					row.append(make_cell())
		else:
			for x in range(width):
				row.append(make_cell())

		result.append(row)

	return result

	
	
func make_cell(
	tile_type: int = EnumMappings.TileEnums.STANDAD_TILE,
	height: float = 0.0,
	ramp: int = EnumMappings.NEWSEnums.NORTH
) -> Dictionary:
	return {
		"type": tile_type,
		"height": height,
		"ramp": ramp
	}
		
func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell())
		result.append(row)

	return result
	
func clear_old_tiles() -> void:
	for child in get_children():
		child.queue_free()

extends Node
class_name MapSpawner

var tile_scenes: Dictionary[int, PackedScene] = {
	EnumMappings.TileEnums.STANDAD_TILE: preload("res://StandardTile.tscn"),
	EnumMappings.TileEnums.GOLD_TILE: preload("res://GoldTile.tscn"),
}
@export var map_file_path: String = "res://map_save.json"

const MAP_WIDTH: int = 64
const MAP_HEIGHT: int = 64
const TILE_SIZE: float = 2.0

var map_data: Array = []
var height_data: Array = []

func _ready() -> void:
	load_map_from_json(map_file_path)
	spawn_map()

func load_map_from_json(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning("Map file not found: " + path + " -> using empty map")
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		height_data = create_empty_height_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open map file: " + path)
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		height_data = create_empty_height_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_error("JSON parse error in file: " + path)
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		height_data = create_empty_height_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		map_data = ensure_map_size(data.get("map_data", []), MAP_WIDTH, MAP_HEIGHT)
		height_data = ensure_height_map_size(data.get("height_data", []), MAP_WIDTH, MAP_HEIGHT)
	elif typeof(data) == TYPE_ARRAY:
		# Fallback für alte Dateien
		map_data = ensure_map_size(data, MAP_WIDTH, MAP_HEIGHT)
		height_data = create_empty_height_map(MAP_WIDTH, MAP_HEIGHT)
	else:
		push_error("Invalid map JSON format")
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		height_data = create_empty_height_map(MAP_WIDTH, MAP_HEIGHT)

func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(0)
		result.append(row)

	return result

func create_empty_height_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(0.0)
		result.append(row)

	return result

func ensure_height_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY:
			var source_row: Array = input_map[y]
			for x in range(width):
				if x < source_row.size():
					var value = source_row[x]
					if value == null:
						row.append(0.0)
					else:
						row.append(float(value))
				else:
					row.append(0.0)
		else:
			for x in range(width):
				row.append(0.0)

		result.append(row)

	return result

func ensure_map_size(input_map: Array, width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []

		if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY:
			var source_row: Array = input_map[y]
			for x in range(width):
				if x < source_row.size():
					row.append(source_row[x])
				else:
					row.append(EnumMappings.TileEnums.STANDAD_TILE)
		else:
			for x in range(width):
				row.append(EnumMappings.TileEnums.STANDAD_TILE)

		result.append(row)

	return result

func get_scene_for_cell(cell_value):
	if tile_scenes.has(cell_value):
		return tile_scenes[cell_value]
	
	# fallback (optional)
	if tile_scenes.has(EnumMappings.TileEnums.STANDAD_TILE):
		return tile_scenes[EnumMappings.TileEnums.STANDAD_TILE]
	
	return null

func spawn_map() -> void:
	clear_old_tiles()

	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var tile_value = map_data[y][x]
			var height_value = height_data[y][x]
			var scene: PackedScene = get_scene_for_cell(tile_value)
			if scene == null:
				continue
			
			var tile_instance := scene.instantiate() as Node3D
			add_child(tile_instance)
			
			tile_instance.position = Vector3(
				x * TILE_SIZE,
				height_value,
				y * TILE_SIZE
			)
			
			if tile_instance.has_method("set_tile_data"):
				tile_instance.call("set_tile_data", tile_value,height_value, x, y)

func clear_old_tiles() -> void:
	for child in get_children():
		child.queue_free()
		
func save_map_to_json(path: String = map_file_path) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open map file for writing: " + path)
		return false

	var save_data := {
		"map_data": map_data,
		"height_data": height_data
	}

	var json_text := JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()

	print("Map saved to: ", ProjectSettings.globalize_path(path))
	return true
	
	
func change_tile(x: int, y: int, new_type: int, new_height:float) -> void:
	if y < 0 or y >= map_data.size():
		return
	if x < 0 or x >= map_data[y].size():
		return

	map_data[y][x] = new_type
	height_data[y][x] = new_height
	respawn_single_tile(x, y)
	


func respawn_single_tile(x: int, y: int) -> void:
	var old_tile := get_tile_node_at(x, y)
	if old_tile != null:
		old_tile.queue_free()

	var scene: PackedScene = get_scene_for_cell(map_data[y][x])

	if scene == null:
		return

	var tile_instance := scene.instantiate() as Node3D
	add_child(tile_instance)
	tile_instance.position = Vector3(x * TILE_SIZE, height_data[y][x], y * TILE_SIZE)

	if tile_instance.has_method("set_tile_data"):
		tile_instance.call("set_tile_data", map_data[y][x],height_data[y][x], x, y)


func get_tile_node_at(x: int, y: int) -> Node3D:
	for child in get_children():
		if child.get("grid_x") == x and child.get("grid_y") == y:
			return child
	return null


func _on_save_pressed() -> void:
	save_map_to_json() 
	pass # Replace with function body.

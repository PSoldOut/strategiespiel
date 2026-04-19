extends Node
class_name MapSpawner

var tile_scenes: Dictionary[int, PackedScene] = {
	EnumMappings.TileEnums.STANDAD_TILE: preload("res://StandardTile.tscn"),
	EnumMappings.TileEnums.GOLD_TILE: preload("res://GoldTile.tscn"),
	EnumMappings.TileEnums.RAMP_TILE: preload("res://RampTile.tscn"),
}

@export var map_file_path: String = "res://map_save.json"

const MAP_WIDTH: int = 16
const MAP_HEIGHT: int = 16
const TILE_SIZE: float = 2.0

var map_data: Array = []


func _ready() -> void:
	load_map_from_json(map_file_path)
	spawn_map()


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


func save_map_to_json(path: String = map_file_path) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not open map file for writing: " + path)
		return false

	var save_data := {
		"map_data": map_data
	}

	var json_text := JSON.stringify(save_data, "\t")
	file.store_string(json_text)
	file.close()

	print("Map saved to: ", ProjectSettings.globalize_path(path))
	return true


func get_scene_for_cell(tile_type: int) -> PackedScene:
	if tile_scenes.has(tile_type):
		return tile_scenes[tile_type]

	if tile_scenes.has(EnumMappings.TileEnums.STANDAD_TILE):
		return tile_scenes[EnumMappings.TileEnums.STANDAD_TILE]

	return null


func spawn_map() -> void:
	clear_old_tiles()

	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			spawn_single_tile(x, y)


func spawn_single_tile(x: int, y: int) -> void:
	var cell: Dictionary = map_data[y][x]

	var tile_type: int = cell.get("type", EnumMappings.TileEnums.STANDAD_TILE)
	var height_value: float = float(cell.get("height", 0.0))
	var ramp_value: int = cell.get("ramp", EnumMappings.NEWSEnums.NORTH)

	var scene: PackedScene = get_scene_for_cell(tile_type)
	if scene == null:
		return

	var tile_instance := scene.instantiate() as Node3D
	add_child(tile_instance)

	tile_instance.position = Vector3(
		x * TILE_SIZE,
		height_value,
		y * TILE_SIZE
	)

	if tile_instance.has_method("set_tile_data"):
		tile_instance.call("set_tile_data", tile_type, height_value, ramp_value, x, y)

	if tile_instance.has_method("update_ramp_visual"):
		tile_instance.call("update_ramp_visual")


func clear_old_tiles() -> void:
	for child in get_children():
		child.queue_free()


func get_tile_node_at(x: int, y: int) -> Node3D:
	for child in get_children():
		if child.get("grid_x") == x and child.get("grid_y") == y:
			return child
	return null


func change_tile(x: int, y: int, new_type: int, new_height: float, new_ramp: int) -> void:
	if y < 0 or y >= map_data.size():
		return
	if x < 0 or x >= map_data[y].size():
		return

	map_data[y][x] = make_cell(new_type, new_height, new_ramp)
	respawn_single_tile(x, y)


func respawn_single_tile(x: int, y: int) -> void:
	var old_tile := get_tile_node_at(x, y)
	if old_tile != null:
		old_tile.queue_free()

	spawn_single_tile(x, y)


func _on_save_pressed() -> void:
	save_map_to_json()

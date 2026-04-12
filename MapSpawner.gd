extends Node
class_name MapSpawner

@export var tile_scene: PackedScene
@export var map_file_path: String = "res://map_data.json"

const MAP_WIDTH: int = 64
const MAP_HEIGHT: int = 64
const TILE_SIZE: float = 2.0

var map_data: Array = []

func _ready() -> void:
	map_data = load_map_from_json(map_file_path)
	map_data = ensure_map_size(map_data, MAP_WIDTH, MAP_HEIGHT)
	spawn_map(map_data)

func load_map_from_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_warning("Map file not found: " + path + " -> using empty map")
		return create_empty_map(MAP_WIDTH, MAP_HEIGHT)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open map file: " + path)
		return create_empty_map(MAP_WIDTH, MAP_HEIGHT)

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(content)
	if parse_result != OK:
		push_error("JSON parse error in file: " + path)
		return create_empty_map(MAP_WIDTH, MAP_HEIGHT)

	if typeof(json.data) != TYPE_ARRAY:
		push_error("Map JSON root must be an Array")
		return create_empty_map(MAP_WIDTH, MAP_HEIGHT)

	return json.data

func create_empty_map(width: int, height: int) -> Array:
	var result: Array = []

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(null)
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
					row.append(null)
		else:
			for x in range(width):
				row.append(null)

		result.append(row)

	return result

func spawn_map(data: Array) -> void:
	if tile_scene == null:
		push_error("tile_scene is not assigned")
		return

	clear_old_tiles()

	for y in range(data.size()):
		var row: Array = data[y]

		for x in range(row.size()):
			var cell_value = row[x]

			# Erster Schritt:
			# Leere Felder -> StandardTile
			# Aktuell spawnen wir auch bei belegten Feldern erstmal das gleiche Tile
			var tile_instance := tile_scene.instantiate() as Node3D
			add_child(tile_instance)

			tile_instance.position = Vector3(
				x * TILE_SIZE,
				0.0,
				y * TILE_SIZE
			)

			# Optional: Werte an Tile weitergeben
			if tile_instance.has_method("set_tile_data"):
				tile_instance.call("set_tile_data", cell_value, x, y)

func clear_old_tiles() -> void:
	for child in get_children():
		child.queue_free()

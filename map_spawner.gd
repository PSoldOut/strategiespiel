extends Node3D
class_name MapSpawner

@export var map_file_path: String = "res://MapSaveData.json"
@export var map_tile_scene: PackedScene = preload("res://MapTile.tscn")

const MAP_WIDTH: int = 16
const MAP_HEIGHT: int = 16
const TILE_SIZE: float = 2.0
const CHUNK_SIZE: int = 16

var map_data: Array = []

var selected_tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE
var selected_height: float = 0.0
var selected_ramp: int = EnumMappings.RampTypeEnums.FLAT

var visual_root: Node3D
var click_root: Node3D


func _ready() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualChunks"
	add_child(visual_root)

	click_root = Node3D.new()
	click_root.name = "ClickableTiles"
	add_child(click_root)

	load_map_from_json()
	rebuild_map()


func set_palette(tile_type: int, height: float, ramp: int) -> void:
	selected_tile_type = tile_type
	selected_height = height
	selected_ramp = ramp


func rebuild_map() -> void:
	clear_children(visual_root)
	clear_children(click_root)

	build_visual_chunks()
	build_click_tiles()


func build_visual_chunks() -> void:
	var map_h := map_data.size()
	if map_h <= 0:
		return

	var map_w : int = map_data[0].size()

	for chunk_y in range(0, map_h, CHUNK_SIZE):
		for chunk_x in range(0, map_w, CHUNK_SIZE):
			var chunk := ChunkBuilder.new()
			visual_root.add_child(chunk)

			chunk.tile_size = TILE_SIZE
			chunk.tile_height_step = 0.5
			chunk.build_collision = true
			chunk.position = Vector3(chunk_x * TILE_SIZE, 0.0, chunk_y * TILE_SIZE)

			chunk.build_from_map(
				map_data,
				chunk_x,
				chunk_y,
				min(CHUNK_SIZE, map_w - chunk_x),
				min(CHUNK_SIZE, map_h - chunk_y)
			)


func build_click_tiles() -> void:
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]

			var tile := map_tile_scene.instantiate() as RTSMapTile
			click_root.add_child(tile)

			if tile == null:
				push_error("MapTile.tscn root does not have RTSMapTile script")
				continue

			tile.position = Vector3(
				(x + 0.5) * TILE_SIZE,
				float(cell.get("height", 0.0)) + 0.05,
				(y + 0.5) * TILE_SIZE
			)

			tile.set_tile_data(
				int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE)),
				float(cell.get("height", 0.0)),
				int(cell.get("ramp", EnumMappings.RampTypeEnums.FLAT)),
				x,
				y
			)

			tile.tile_clicked.connect(_on_tile_clicked)

func _on_tile_clicked(tile: RTSMapTile) -> void:
	change_tile(tile.grid_x, tile.grid_y)


func load_map_from_json() -> void:
	if not FileAccess.file_exists(map_file_path):
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		save_map_to_json()
		return

	var file := FileAccess.open(map_file_path, FileAccess.READ)
	if file == null:
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		map_data = ensure_map_size(data.get("map_data", []), MAP_WIDTH, MAP_HEIGHT)
	elif typeof(data) == TYPE_ARRAY:
		map_data = ensure_map_size(data, MAP_WIDTH, MAP_HEIGHT)
	else:
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)


func save_map_to_json() -> void:
	var data := {
		"map_data": map_data
	}

	var file := FileAccess.open(map_file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save map JSON: " + map_file_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Saved JSON to: ", map_file_path)


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

		for x in range(width):
			if y < input_map.size() and typeof(input_map[y]) == TYPE_ARRAY and x < input_map[y].size():
				var value = input_map[y][x]

				if typeof(value) == TYPE_DICTIONARY:
					row.append(make_cell(
						int(value.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE)),
						float(value.get("height", 0.0)),
						int(value.get("ramp", EnumMappings.RampTypeEnums.FLAT))
					))
				else:
					row.append(make_cell(int(value)))
			else:
				row.append(make_cell())

		result.append(row)

	return result


func make_cell(
	tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	height: float = 0.0,
	ramp: int = EnumMappings.RampTypeEnums.FLAT
) -> Dictionary:
	return {
		"type": int(tile_type),
		"height": float(height),
		"ramp": int(ramp),
		"corners": make_corners(float(height), int(ramp), int(tile_type))
	}

func make_corners(height: float, ramp: int, tile_type: int) -> Dictionary:
	var h_sw := height
	var h_se := height
	var h_nw := height
	var h_ne := height

	if tile_type != EnumMappings.TileTypeEnums.RAMP_TILE:
		return {
			"sw": h_sw,
			"se": h_se,
			"nw": h_nw,
			"ne": h_ne
		}

	var low := height - 0.5
	var high := height

	match ramp:
		EnumMappings.RampTypeEnums.RAMP_N:
			h_sw = low
			h_se = low
			h_nw = high
			h_ne = high

		EnumMappings.RampTypeEnums.RAMP_S:
			h_sw = high
			h_se = high
			h_nw = low
			h_ne = low

		EnumMappings.RampTypeEnums.RAMP_E:
			h_sw = low
			h_nw = low
			h_se = high
			h_ne = high

		EnumMappings.RampTypeEnums.RAMP_W:
			h_sw = high
			h_nw = high
			h_se = low
			h_ne = low

		EnumMappings.RampTypeEnums.RAMP_NE:
			h_sw = low
			h_se = low
			h_nw = low
			h_ne = high

		EnumMappings.RampTypeEnums.RAMP_NW:
			h_se = low
			h_sw = low
			h_ne = low
			h_nw = high

		EnumMappings.RampTypeEnums.RAMP_SE:
			h_nw = low
			h_sw = low
			h_ne = low
			h_se = high

		EnumMappings.RampTypeEnums.RAMP_SW:
			h_ne = low
			h_se = low
			h_nw = low
			h_sw = high

	return {
		"sw": h_sw,
		"se": h_se,
		"nw": h_nw,
		"ne": h_ne
	}


func reset_map(
	width: int = MAP_WIDTH,
	height: int = MAP_HEIGHT,
	default_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	default_height: float = 0.0,
	default_ramp: int = EnumMappings.RampTypeEnums.FLAT
) -> void:
	print("Resetting map...")

	map_data.clear()

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell(default_type, default_height, default_ramp))
		map_data.append(row)

	save_map_to_json()
	rebuild_map()

	print("Map reset complete")
	
	
func change_tile(grid_x: int, grid_y: int) -> void:
	if grid_y < 0 or grid_y >= map_data.size():
		return
	if grid_x < 0 or grid_x >= map_data[grid_y].size():
		return

	map_data[grid_y][grid_x] = make_cell(
		selected_tile_type,
		selected_height,
		selected_ramp
	)

	save_map_to_json()
	rebuild_map()

func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
	


func _on_save_pressed() -> void:
	save_map_to_json()


func _on_reset_button_pressed() -> void:
	reset_map()

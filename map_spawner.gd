extends Node3D
class_name MapSpawner

@export var map_file_path: String = "res://MapSaveData.json"
@export var map_tile_scene: PackedScene = preload("res://MapTile.tscn")
@export var auto_ramp_enabled: bool = true

const MAP_WIDTH: int = 16
const MAP_HEIGHT: int = 16
const TILE_SIZE: float = 2.0
const CHUNK_SIZE: int = 16

var map_data: Array = []

var selected_tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE
var edit_mode: int = EnumMappings.EditMode.SET_TILE_TYPE

const HEIGHT_STEP: float = 0.5
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 2.0

var visual_root: Node3D
var click_root: Node3D

signal map_spawned(map_data: Array)



func _ready() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualChunks"
	add_child(visual_root)

	click_root = Node3D.new()
	click_root.name = "ClickableTiles"
	add_child(click_root)

	load_map_from_json()
	rebuild_map()





func rebuild_map() -> void:
	clear_children(visual_root)
	clear_children(click_root)

	build_visual_chunks()
	build_click_tiles()
	call_deferred("_emit_map_spawned")


func _emit_map_spawned() -> void:
	map_spawned.emit(map_data)

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
					row.append(normalize_cell(value))
				else:
					row.append(make_cell(int(value)))
			else:
				row.append(make_cell())

		result.append(row)

	return result


func make_cell(
	tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	height: float = 0.0
) -> Dictionary:
	return {
		"type": int(tile_type),
		"height": float(height),
		"corners": {
			"sw": float(height),
			"se": float(height),
			"nw": float(height),
			"ne": float(height)
		}
	}

func normalize_cell(value: Dictionary) -> Dictionary:
	var tile_type: int = int(value.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var height: float = float(value.get("height", 0.0))

	return make_cell(tile_type, height)




func reset_map(
	width: int = MAP_WIDTH,
	height: int = MAP_HEIGHT,
	default_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE,
	default_height: float = 0.0,
) -> void:
	print("Resetting map...")

	map_data.clear()

	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(make_cell(default_type, default_height))
		map_data.append(row)

	save_map_to_json()
	rebuild_map()

	print("Map reset complete")
	
	
func change_tile(grid_x: int, grid_y: int) -> void:
	if not is_valid_grid_pos(grid_x, grid_y):
		return

	var cell: Dictionary = map_data[grid_y][grid_x]

	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var height: float = float(cell.get("height", 0.0))

	match edit_mode:
		EnumMappings.EditMode.SET_TILE_TYPE:
			tile_type = selected_tile_type

		EnumMappings.EditMode.HEIGHT_UP:
			height = clamp(height + HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)

		EnumMappings.EditMode.HEIGHT_DOWN:
			height = clamp(height - HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)

	map_data[grid_y][grid_x] = make_cell(tile_type, height)

	if auto_ramp_enabled:
		recalculate_auto_ramps()

	save_map_to_json()
	rebuild_map()

func recalculate_auto_ramps() -> void:
	# Reset all corners to base height first.
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))

			cell["corners"] = {
				"sw": h,
				"se": h,
				"nw": h,
				"ne": h
			}

			map_data[y][x] = cell

	# Then apply edge ramps.
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			_apply_auto_ramp_between(x, y, x + 1, y)
			_apply_auto_ramp_between(x, y, x, y + 1)

	# Then apply diagonal corner touching.
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			_apply_auto_corner_between(x, y, x + 1, y + 1)
			_apply_auto_corner_between(x + 1, y, x, y + 1)

func _apply_auto_ramp_between(ax: int, ay: int, bx: int, by: int) -> void:
	if not is_valid_grid_pos(ax, ay):
		return
	if not is_valid_grid_pos(bx, by):
		return

	var a: Dictionary = map_data[ay][ax]
	var b: Dictionary = map_data[by][bx]

	var ah: float = float(a.get("height", 0.0))
	var bh: float = float(b.get("height", 0.0))

	if not is_equal_approx(abs(ah - bh), HEIGHT_STEP):
		return

	# B is east of A
	if bx == ax + 1 and by == ay:
		if ah < bh:
			_set_corners(ax, ay, ["se", "ne"], bh)
		else:
			_set_corners(bx, by, ["sw", "nw"], ah)

	# B is south of A
	if bx == ax and by == ay + 1:
		if ah < bh:
			_set_corners(ax, ay, ["sw", "se"], bh)
		else:
			_set_corners(bx, by, ["nw", "ne"], ah)
func _apply_auto_corner_between(ax: int, ay: int, bx: int, by: int) -> void:
	if not is_valid_grid_pos(ax, ay):
		return
	if not is_valid_grid_pos(bx, by):
		return

	var a: Dictionary = map_data[ay][ax]
	var b: Dictionary = map_data[by][bx]

	var ah: float = float(a.get("height", 0.0))
	var bh: float = float(b.get("height", 0.0))

	if not is_equal_approx(abs(ah - bh), HEIGHT_STEP):
		return

	# B is south-east of A
	if bx == ax + 1 and by == ay + 1:
		if ah < bh:
			_set_corners(ax, ay, ["se"], bh)
		else:
			_set_corners(bx, by, ["nw"], ah)

	# B is south-west of A
	if bx == ax - 1 and by == ay + 1:
		if ah < bh:
			_set_corners(ax, ay, ["sw"], bh)
		else:
			_set_corners(bx, by, ["ne"], ah)

func _set_corners(grid_x: int, grid_y: int, names: Array[String], value: float) -> void:
	var cell: Dictionary = map_data[grid_y][grid_x]
	var corners: Dictionary = cell.get("corners", {})

	for corner_name in names:
		corners[corner_name] = value

	cell["corners"] = corners
	map_data[grid_y][grid_x] = cell

		
func is_valid_grid_pos(grid_x: int, grid_y: int) -> bool:
	return (
		grid_y >= 0
		and grid_y < map_data.size()
		and grid_x >= 0
		and grid_x < map_data[grid_y].size()
	)

func clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
	

func set_palette(tile_type: int, height_action: float) -> void:
	selected_tile_type = tile_type

	if is_equal_approx(height_action, 0.5):
		edit_mode = EnumMappings.EditMode.HEIGHT_UP
	elif is_equal_approx(height_action, -0.5):
		edit_mode = EnumMappings.EditMode.HEIGHT_DOWN
	else:
		edit_mode = EnumMappings.EditMode.SET_TILE_TYPE

func _on_save_pressed() -> void:
	save_map_to_json()


func _on_reset_button_pressed() -> void:
	reset_map()

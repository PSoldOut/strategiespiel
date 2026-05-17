extends Node3D
class_name MapSpawner

@export var map_tile_scene: PackedScene = preload("res://MapEditor/MapTile.tscn")
@export var auto_ramp_enabled: bool = true
@export var show_tile_lines: bool = true
@export var bake_collision: bool = true

@export var map_name: String = "Map001"
@export var map_save_directory: String = "res://GeneratedMaps"
@export var map_json_extension: String = ".json"
@export var baked_scene_extension: String = ".tscn"

const MAP_WIDTH: int = 32
const MAP_HEIGHT: int = 32
const TILE_SIZE: float = 2.0

const HEIGHT_STEP: float = 0.5
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 2.0

var map_data: Array = []

var selected_tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE
var edit_mode: int = EnumMappings.EditMode.SET_TILE_TYPE

var visual_root: Node3D
var click_root: Node3D
var map_baker: MapBaker

signal map_spawned(map_data: Array)
signal tile_clicked(tile: RTSMapTile)


func _ready() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualMap"
	add_child(visual_root)

	click_root = Node3D.new()
	click_root.name = "ClickableTiles"
	add_child(click_root)

	load_map_from_json()
	rebuild_map()


func rebuild_map() -> void:
	clear_children(visual_root)
	clear_children(click_root)

	build_visual_map()
	build_click_tiles()
	call_deferred("_emit_map_spawned")


func _emit_map_spawned() -> void:
	map_spawned.emit(map_data)


func build_visual_map() -> void:
	if map_data.is_empty():
		return

	map_baker = MapBaker.new()
	map_baker.name = "MapBaker"
	map_baker.tile_size = TILE_SIZE
	map_baker.build_collision = bake_collision
	map_baker.show_tile_lines = show_tile_lines

	visual_root.add_child(map_baker)
	map_baker.bake_map(map_data)


# Compatibility wrapper, in case another script still calls the old name.
# It no longer builds chunks. It bakes the whole map.
func build_visual_chunks() -> void:
	build_visual_map()


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

			if not tile.tile_clicked.is_connected(_on_tile_clicked):
				tile.tile_clicked.connect(_on_tile_clicked)


func _on_tile_clicked(tile: RTSMapTile) -> void:
	tile_clicked.emit(tile)
	change_tile(tile.grid_x, tile.grid_y)


func get_map_json_path() -> String:
	return map_save_directory.path_join(map_name + map_json_extension)


func get_baked_scene_path() -> String:
	return map_save_directory.path_join(map_name + baked_scene_extension)


func set_selected_map_name(new_map_name: String, load_immediately: bool = true) -> void:
	var cleaned := new_map_name.strip_edges()
	if cleaned.is_empty():
		cleaned = "Map001"

	map_name = cleaned

	if load_immediately:
		load_map_from_json()
		rebuild_map()


func load_map_from_json() -> void:
	var json_path := get_map_json_path()

	if not FileAccess.file_exists(json_path):
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		save_map_to_json()
		return

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Could not open map JSON: " + json_path)
		map_data = create_empty_map(MAP_WIDTH, MAP_HEIGHT)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Could not parse map JSON: " + json_path)
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
	ensure_save_directory()

	var json_path := get_map_json_path()
	var data := {
		"map_name": map_name,
		"map_data": map_data
	}

	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save map JSON: " + json_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Saved JSON to: ", json_path)


func ensure_save_directory() -> void:
	if map_save_directory.is_empty():
		return

	var result := DirAccess.make_dir_recursive_absolute(map_save_directory)
	if result != OK and result != ERR_ALREADY_EXISTS:
		push_warning("Could not create map save directory: %s | Error: %s" % [map_save_directory, result])


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
		"corners": make_flat_corners(height)
	}


func make_flat_corners(height: float) -> Dictionary:
	return {
		"sw": float(height),
		"se": float(height),
		"nw": float(height),
		"ne": float(height)
	}


func normalize_cell(value: Dictionary) -> Dictionary:
	var tile_type: int = int(value.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var height: float = float(value.get("height", 0.0))
	var cell := make_cell(tile_type, height)

	# Important: keep saved auto-ramp corner data.
	# There are no ramp tiles anymore. Ramps are represented only by corner heights.
	if value.has("corners") and typeof(value["corners"]) == TYPE_DICTIONARY:
		var saved_corners: Dictionary = value["corners"]
		cell["corners"] = {
			"sw": float(saved_corners.get("sw", height)),
			"se": float(saved_corners.get("se", height)),
			"nw": float(saved_corners.get("nw", height)),
			"ne": float(saved_corners.get("ne", height))
		}

	return cell


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
		reset_auto_ramp_area(grid_x, grid_y)
		apply_auto_ramp_to_neighbours(grid_x, grid_y)

	save_map_to_json()
	rebuild_map()



func reset_auto_ramp_area(center_x: int, center_y: int) -> void:
	# Reset only the changed tile and its 8 neighbours.
	# This removes old corner overrides when a tile goes back from 0.5 to 0.0
	# or from -0.5 to 0.0, without destroying the whole map's saved ramps.
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := center_x + dx
			var y := center_y + dy

			if not is_valid_grid_pos(x, y):
				continue

			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))
			cell["corners"] = make_flat_corners(h)
			map_data[y][x] = cell


func apply_auto_ramp_to_neighbours(grid_x: int, grid_y: int) -> void:
	if not is_valid_grid_pos(grid_x, grid_y):
		return

	var target_height := float(map_data[grid_y][grid_x].get("height", 0.0))

	# Direct neighbours share an edge with the changed tile.
	# The changed tile stays flat. The neighbour's bordering corners move to target_height.
	_apply_auto_ramp_corner_patch(grid_x, grid_y - 1, target_height, ["sw", "se"]) # north tile, south edge
	_apply_auto_ramp_corner_patch(grid_x, grid_y + 1, target_height, ["nw", "ne"]) # south tile, north edge
	_apply_auto_ramp_corner_patch(grid_x - 1, grid_y, target_height, ["se", "ne"]) # west tile, east edge
	_apply_auto_ramp_corner_patch(grid_x + 1, grid_y, target_height, ["sw", "nw"]) # east tile, west edge

	# Diagonal neighbours touch only one corner.
	_apply_auto_ramp_corner_patch(grid_x - 1, grid_y - 1, target_height, ["se"]) # north-west tile
	_apply_auto_ramp_corner_patch(grid_x + 1, grid_y - 1, target_height, ["sw"]) # north-east tile
	_apply_auto_ramp_corner_patch(grid_x - 1, grid_y + 1, target_height, ["ne"]) # south-west tile
	_apply_auto_ramp_corner_patch(grid_x + 1, grid_y + 1, target_height, ["nw"]) # south-east tile


func _apply_auto_ramp_corner_patch(
	grid_x: int,
	grid_y: int,
	target_height: float,
	corner_names: Array[String]
) -> void:
	if not is_valid_grid_pos(grid_x, grid_y):
		return

	var cell: Dictionary = map_data[grid_y][grid_x]
	var neighbour_height := float(cell.get("height", 0.0))

	# Only connect one height step: +0.5 and -0.5 both work.
	if not is_equal_approx(abs(neighbour_height - target_height), HEIGHT_STEP):
		return

	var corners: Dictionary = cell.get("corners", make_flat_corners(neighbour_height))

	for corner_name in corner_names:
		corners[corner_name] = target_height

	cell["corners"] = corners
	map_data[grid_y][grid_x] = cell


func recalculate_auto_ramps() -> void:
	# Reset all corners to base height first.
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))

			cell["corners"] = make_flat_corners(h)
			map_data[y][x] = cell

	# Edge touching tiles.
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			_apply_auto_ramp_between(x, y, x + 1, y)
			_apply_auto_ramp_between(x, y, x, y + 1)

	# Diagonal touching tiles.
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

	# B is east of A.
	if bx == ax + 1 and by == ay:
		if ah < bh:
			_set_corners(ax, ay, ["se", "ne"], bh)
		else:
			_set_corners(bx, by, ["sw", "nw"], ah)

	# B is south of A.
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

	# B is south-east of A.
	if bx == ax + 1 and by == ay + 1:
		if ah < bh:
			_set_corners(ax, ay, ["se"], bh)
		else:
			_set_corners(bx, by, ["nw"], ah)

	# B is south-west of A.
	if bx == ax - 1 and by == ay + 1:
		if ah < bh:
			_set_corners(ax, ay, ["sw"], bh)
		else:
			_set_corners(bx, by, ["ne"], ah)


func _set_corners(grid_x: int, grid_y: int, names: Array[String], value: float) -> void:
	var cell: Dictionary = map_data[grid_y][grid_x]
	var corners: Dictionary = cell.get("corners", make_flat_corners(float(cell.get("height", 0.0))))

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


func set_height_action(height_action: float) -> void:
	if is_equal_approx(height_action, HEIGHT_STEP):
		edit_mode = EnumMappings.EditMode.HEIGHT_UP
	elif is_equal_approx(height_action, -HEIGHT_STEP):
		edit_mode = EnumMappings.EditMode.HEIGHT_DOWN
	else:
		edit_mode = EnumMappings.EditMode.SET_TILE_TYPE

	print("MapSpawner edit_mode:", edit_mode, " height_action:", height_action)


func set_selected_tile_type(tile_type: int) -> void:
	selected_tile_type = tile_type


func set_palette(tile_type: int, height_action: float) -> void:
	set_selected_tile_type(tile_type)
	set_height_action(height_action)


func save_map() -> void:
	save_map_to_json()
	save_map_as_scene(get_baked_scene_path())


func save_map_as_scene(path: String) -> void:
	if map_data.is_empty():
		push_error("Cannot save baked map: map_data is empty")
		return

	ensure_save_directory()

	var baker := MapBaker.new()
	baker.name = "MapBaker"
	baker.tile_size = TILE_SIZE
	baker.build_collision = bake_collision
	baker.show_tile_lines = show_tile_lines
	baker.save_baked_map(map_data, path, map_name)

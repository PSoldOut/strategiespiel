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
@export var tile_palette : Control

const MAP_WIDTH: int = 32
const MAP_HEIGHT: int = 32
const TILE_SIZE: float = 2.0

const HEIGHT_STEP: float = 0.5
const MIN_HEIGHT: float = -2.0
const MAX_HEIGHT: float = 2.0

var map_data: Array = []

var ground_type: int = EnumMappings.GroundType.GRAS_TILE
var height_mode: int = EnumMappings.HeightMapping.HEIGHT_NONE
var player: int = EnumMappings.Player.WORLD
var building_type: int = EnumMappings.BuildingType.NONE

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

	if auto_ramp_enabled:
		recalculate_auto_ramps()

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
				int(cell.get("type", EnumMappings.GroundType.GRAS_TILE)),
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

	# One source of truth. Both JSON and baked scene paths are derived from this.
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
	tile_type: int = EnumMappings.GroundType.GRAS_TILE,
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
	var tile_type: int = int(value.get("type", EnumMappings.GroundType.GRAS_TILE))
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
	default_type: int = EnumMappings.GroundType.GRAS_TILE,
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
	if not is_valid_grid_pos(grid_x, grid_y) or tile_palette.selected_building_type != EnumMappings.BuildingType.NONE:
		return

	var cell: Dictionary = map_data[grid_y][grid_x]

	var old_height: float = float(cell.get("height", 0.0))
	var height: float = float(cell.get("height", 0.0))
	var height_action = tile_palette.selected_height_action
	print(tile_palette.selected_height_action)
	match height_action:
		EnumMappings.HeightMapping.HEIGHT_UP:
			height = clamp(old_height + HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)

		EnumMappings.HeightMapping.HEIGHT_DOWN:
			height = clamp(old_height - HEIGHT_STEP, MIN_HEIGHT, MAX_HEIGHT)

	map_data[grid_y][grid_x] = make_cell(tile_palette.selected_ground_type, height)

	if old_height != height:
		recalculate_auto_ramps()
		
		
	#var old_ground_type: int = int(cell.get("ground", 0))
	#var old_player: int = int ()
	#var player: int = EnumMappings.Player.WORLD
	#var building_type: int = EnumMappings.BuildingType.NONE

	save_map_to_json()
	rebuild_map()

func recalculate_auto_ramps():
	recalculate_auto_ramps_1()
	
func recalculate_auto_ramps_2() -> void:
	
	return

func recalculate_auto_ramps_1() -> void:
	# Shared vertex based auto-ramp system.
	# A corner is not owned by one tile only. Up to four tiles touch the same vertex.
	# Therefore every shared vertex is calculated once and then written back to all
	# touching tile corners. This prevents neighbouring edits from overwriting each
	# other with wrong corner resets.
	reset_all_corners_to_base_height()

	var map_h := map_data.size()
	if map_h <= 0:
		return

	var map_w: int = map_data[0].size()

	# Vertices are grid intersections, so a 32x32 map has 33x33 vertices.
	for vertex_y in range(map_h + 1):
		for vertex_x in range(map_w + 1):
			recalculate_shared_vertex(vertex_x, vertex_y)


func reset_all_corners_to_base_height() -> void:
	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]
			var h: float = float(cell.get("height", 0.0))
			cell["corners"] = make_flat_corners(h)
			map_data[y][x] = cell


func recalculate_shared_vertex(vertex_x: int, vertex_y: int) -> void:
	var touching := get_tiles_touching_vertex(vertex_x, vertex_y)
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
	if not is_equal_approx(max_h - min_h, HEIGHT_STEP):
		return

	# Shared rule: keep the edited plateau/hole visible.
	# For normal positive ramps, 0.0 -> 0.5 chooses 0.5.
	# For holes, 0.0 -> -0.5 chooses -0.5.
	# In other words: choose the height farther away from zero.
	var shared_height := get_dominant_vertex_height(min_h, max_h)

	for item in touching:
		var tx: int = int(item["x"])
		var ty: int = int(item["y"])
		var corner_name: String = str(item["corner"])
		set_single_corner(tx, ty, corner_name, shared_height)


func get_dominant_vertex_height(min_h: float, max_h: float) -> float:
	if abs(min_h) > abs(max_h):
		return min_h
	return max_h


func get_tiles_touching_vertex(vertex_x: int, vertex_y: int) -> Array:
	var result: Array = []

	# Tile north-west of the vertex touches it with its south-east corner.
	append_touching_tile(result, vertex_x - 1, vertex_y - 1, "se")

	# Tile north-east of the vertex touches it with its south-west corner.
	append_touching_tile(result, vertex_x, vertex_y - 1, "sw")

	# Tile south-west of the vertex touches it with its north-east corner.
	append_touching_tile(result, vertex_x - 1, vertex_y, "ne")

	# Tile south-east of the vertex touches it with its north-west corner.
	append_touching_tile(result, vertex_x, vertex_y, "nw")

	return result


func append_touching_tile(result: Array, grid_x: int, grid_y: int, corner_name: String) -> void:
	if not is_valid_grid_pos(grid_x, grid_y):
		return

	result.append({
		"x": grid_x,
		"y": grid_y,
		"corner": corner_name
	})


func set_single_corner(grid_x: int, grid_y: int, corner_name: String, value: float) -> void:
	var cell: Dictionary = map_data[grid_y][grid_x]
	var height: float = float(cell.get("height", 0.0))
	var corners: Dictionary = cell.get("corners", make_flat_corners(height))
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
		height_mode = EnumMappings.HeightMapping.HEIGHT_UP
	elif is_equal_approx(height_action, -HEIGHT_STEP):
		height_mode = EnumMappings.HeightMapping.HEIGHT_DOWN
	else:
		height_mode = EnumMappings.HeightMapping.HEIGHT_NONE


func save_map() -> void:
	var json_path := get_map_json_path()
	var scene_path := get_baked_scene_path()
	print("Saving map as JSON: ", json_path)
	print("Saving baked scene: ", scene_path)
	save_map_to_json()
	save_map_as_scene(scene_path)


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
	baker.save_baked_four_rotated_corners(map_data, path, map_name)

extends Node3D
class_name MapSpawner

const DEFAULT_MAP_TILE_SCENE_PATH: String = "res://MapEditor/MapTile.tscn"

@export var map_tile_scene: PackedScene
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
var click_tiles_by_grid: Dictionary = {}
var map_baker: MapBaker

signal map_spawned(map_data: Array)
signal tile_clicked(tile: RTSMapTile) # Legacy/optional. Click logic is handled by MapEditor via baked map raycast.


func _ready() -> void:
	_ensure_required_scenes()

	visual_root = Node3D.new()
	visual_root.name = "VisualMap"
	add_child(visual_root)

	click_root = Node3D.new()
	click_root.name = "ClickableTiles"
	add_child(click_root)

	load_map_from_json()
	rebuild_map()


func _ensure_required_scenes() -> void:
	if map_tile_scene != null:
		return

	if not ResourceLoader.exists(DEFAULT_MAP_TILE_SCENE_PATH):
		push_error("MapSpawner: MapTile scene not found: " + DEFAULT_MAP_TILE_SCENE_PATH)
		return

	map_tile_scene = load(DEFAULT_MAP_TILE_SCENE_PATH) as PackedScene

	if map_tile_scene == null:
		push_error("MapSpawner: Could not load MapTile scene as PackedScene: " + DEFAULT_MAP_TILE_SCENE_PATH)


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
	_ensure_required_scenes()
	click_tiles_by_grid.clear()

	if map_tile_scene == null:
		push_error("MapSpawner: map_tile_scene is null. Assign MapTile.tscn in the Inspector or fix DEFAULT_MAP_TILE_SCENE_PATH.")
		return

	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: Dictionary = map_data[y][x]

			var tile := map_tile_scene.instantiate() as RTSMapTile

			if tile == null:
				push_error("MapTile.tscn root does not have RTSMapTile script")
				continue

			click_root.add_child(tile)

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

			click_tiles_by_grid[Vector2i(x, y)] = tile

			# Clickable tiles are now only hover/highlight visuals.
			# Click and drag editing is handled by MapEditor via raycast against the baked map collision.
			# Therefore these tiles do not need collision and should not directly change map data.
			# _ensure_click_tile_collision(tile)


func _ensure_click_tile_collision(tile: RTSMapTile) -> void:
	# GetTileUnderMouse uses a physics raycast.
	# Therefore every spawned editor tile needs a collision object.
	# The collision is added slightly above the visual map so the ray hits
	# the editable RTSMapTile instead of the baked visual map collision.
	if tile == null:
		return

	var existing := tile.find_child("ClickCollisionBody", false, false)
	if existing != null:
		return

	var body := StaticBody3D.new()
	body.name = "ClickCollisionBody"
	body.input_ray_pickable = true
	body.set_meta("tile_ref", tile)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"

	var box := BoxShape3D.new()
	box.size = Vector3(TILE_SIZE, 0.12, TILE_SIZE)
	shape.shape = box

	body.add_child(shape)
	tile.add_child(body)


func _on_tile_clicked(tile: RTSMapTile) -> void:
	# Legacy compatibility only.
	# Map editing is now handled by MapEditor click/drag logic, not by RTSMapTile clicks.
	tile_clicked.emit(tile)


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


func get_tile_at_grid(grid_x: int, grid_y: int) -> RTSMapTile:
	if not is_valid_grid_pos(grid_x, grid_y):
		return null

	var key := Vector2i(grid_x, grid_y)
	if not click_tiles_by_grid.has(key):
		return null

	return click_tiles_by_grid[key] as RTSMapTile


func world_position_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(pos.x / TILE_SIZE)),
		int(floor(pos.z / TILE_SIZE))
	)


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

	#save_map_to_json()
	rebuild_map()

func recalculate_auto_ramps() -> void:
	AutoRampBuilderAvg.recalculate_auto_ramps(map_data)


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

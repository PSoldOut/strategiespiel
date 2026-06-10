extends RefCounted
class_name MapSaveLoadService

const SAVE_VERSION: float = 0.2

static func get_map_json_path(map_save_directory: String, map_name: String, map_json_extension: String) -> String:
	return map_save_directory.path_join(map_name + map_json_extension)


static func get_baked_scene_path(map_save_directory: String, map_name: String, baked_scene_extension: String) -> String:
	return map_save_directory.path_join(map_name + baked_scene_extension)


static func ensure_save_directory(map_save_directory: String) -> void:
	if map_save_directory.is_empty():
		return

	var result := DirAccess.make_dir_recursive_absolute(map_save_directory)
	if result != OK and result != ERR_ALREADY_EXISTS:
		push_warning("Could not create map save directory: %s | Error: %s" % [map_save_directory, result])


static func load_map_from_json(
	json_path: String,
	default_width: int,
	default_height: int
) -> Dictionary:
	if not FileAccess.file_exists(json_path):
		return create_new_empty_map(default_width, default_height)

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("Could not open map JSON: " + json_path)
		return create_new_empty_map(default_width, default_height)

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("Could not parse map JSON: " + json_path)
		return create_new_empty_map(default_width, default_height)

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		return load_map_from_dictionary(data, default_width, default_height)

	if typeof(data) == TYPE_ARRAY:
		return {
			"map_data": MapTerrainService.ensure_map_size(data, default_width, default_height),
			"resource_data": MapResourceService.create_empty_resource_map(default_width, default_height),
			"building_data": MapBuildingService.create_empty_building_map(default_width, default_height)
		}

	return create_new_empty_map(default_width, default_height)


static func load_map_from_dictionary(data: Dictionary, default_width: int, default_height: int) -> Dictionary:
	var loaded_width: int = int(data.get("width", default_width))
	var loaded_height: int = int(data.get("height", default_height))

	if loaded_width <= 0:
		loaded_width = default_width
	if loaded_height <= 0:
		loaded_height = default_height

	var terrain_source: Array = data.get("terrain", data.get("map_data", []))
	var map_data := MapTerrainService.ensure_map_size(terrain_source, loaded_width, loaded_height)

	var resource_data := MapResourceService.ensure_resource_map_size(
		data.get("resources", data.get("resource_data", [])),
		loaded_width,
		loaded_height
	)

	var building_data := MapBuildingService.ensure_building_map_size(
		data.get("buildings", data.get("building_data", [])),
		loaded_width,
		loaded_height
	)

	if resource_data.is_empty():
		resource_data = MapResourceService.create_empty_resource_map(loaded_width, loaded_height)
	if building_data.is_empty():
		building_data = MapBuildingService.create_empty_building_map(loaded_width, loaded_height)

	return {
		"map_data": map_data,
		"resource_data": resource_data,
		"building_data": building_data
	}


static func create_new_empty_map(width: int, height: int) -> Dictionary:
	return {
		"map_data": MapTerrainService.create_empty_map(width, height),
		"resource_data": MapResourceService.create_empty_resource_map(width, height),
		"building_data": MapBuildingService.create_empty_building_map(width, height)
	}


static func save_map_to_json(
	json_path: String,
	map_save_directory: String,
	map_name: String,
	map_data: Array,
	resource_data: Array,
	building_data: Array
) -> void:
	ensure_save_directory(map_save_directory)

	var data := {
		"version": SAVE_VERSION,
		"map_name": map_name,
		"width": MapGridService.get_map_width(map_data),
		"height": MapGridService.get_map_height(map_data),
		"terrain": map_data,
		"resources": resource_data,
		"buildings": building_data,
		"map_data": map_data
	}

	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save map JSON: " + json_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("Saved JSON to: ", json_path)


static func save_map_as_scene(
	path: String,
	map_save_directory: String,
	map_data: Array,
	map_name: String,
	tile_size: float,
	bake_collision: bool,
	show_tile_lines: bool
) -> void:
	if map_data.is_empty():
		push_error("Cannot save baked map: map_data is empty")
		return

	ensure_save_directory(map_save_directory)

	var baker := MapBaker.new()
	baker.name = "MapBaker"
	baker.tile_size = tile_size
	baker.build_collision = bake_collision
	baker.show_tile_lines = show_tile_lines
	baker.save_baked_four_rotated_corners(map_data, path, map_name)

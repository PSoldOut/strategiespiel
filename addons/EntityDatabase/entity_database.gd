extends Node
## EntityDatabase
##
## Central access point for entity definitions.
## For now this loads JSON. Later this file can be changed internally to SQLite
## while keeping the public API stable.

@export_file("*.json") var entity_definitions_path: String = "res://addons/entity_database/entity_definitions.json"

var _definitions: Dictionary = {}
var _loaded: bool = false


func _ready() -> void:
	load_definitions()


func load_definitions(path: String = "") -> bool:
	var final_path := path if path != "" else entity_definitions_path

	if not FileAccess.file_exists(final_path):
		push_error("[EntityDatabase] Definitions file not found: " + final_path)
		_definitions = {}
		_loaded = false
		return false

	var file := FileAccess.open(final_path, FileAccess.READ)
	if file == null:
		push_error("[EntityDatabase] Could not open definitions file: " + final_path)
		_definitions = {}
		_loaded = false
		return false

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[EntityDatabase] Invalid JSON dictionary: " + final_path)
		_definitions = {}
		_loaded = false
		return false

	_definitions = parsed
	_loaded = true
	print("[EntityDatabase] Loaded definitions: ", final_path)
	return true


func is_loaded() -> bool:
	return _loaded


func get_definitions() -> Dictionary:
	return _definitions


func _get_category(category: String) -> Dictionary:
	if not _loaded:
		load_definitions()

	return _definitions.get(category, {})


func _get_entry(category: String, type_id: int) -> Dictionary:
	var category_data := _get_category(category)
	return category_data.get(str(type_id), {})


func _get_color_from_entry(entry: Dictionary, fallback: Color = Color.WHITE) -> Color:
	var color_string := str(entry.get("color", ""))
	if color_string == "":
		return fallback

	return Color(color_string)


func _orientation_swaps_size(orientation: int) -> bool:
	# Preferred enum order:
	# NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3
	return orientation == 1 or orientation == 3


func get_resource_def(resource_type: int) -> Dictionary:
	return _get_entry("resources", resource_type)


func get_resource_name(resource_type: int) -> String:
	var entry := get_resource_def(resource_type)
	return str(entry.get("name", "Unknown Resource"))


func get_resource_enum_name(resource_type: int) -> String:
	var entry := get_resource_def(resource_type)
	return str(entry.get("enum_name", "UNKNOWN"))


func get_resource_color(resource_type: int) -> Color:
	var entry := get_resource_def(resource_type)
	return _get_color_from_entry(entry, Color.WHITE)


func get_resource_value(resource_type: int) -> int:
	var entry := get_resource_def(resource_type)
	return int(entry.get("value", 0))


func get_all_resource_defs(include_none: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var resources := _get_category("resources")

	var keys := resources.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))

	for key in keys:
		if not include_none and int(key) == 0:
			continue

		var entry: Dictionary = resources[key].duplicate(true)
		entry["id"] = int(key)
		result.append(entry)

	return result


func get_building_def(building_type: int) -> Dictionary:
	return _get_entry("buildings", building_type)


func get_building_name(building_type: int) -> String:
	var entry := get_building_def(building_type)
	return str(entry.get("name", "Unknown Building"))


func get_building_enum_name(building_type: int) -> String:
	var entry := get_building_def(building_type)
	return str(entry.get("enum_name", "UNKNOWN"))


func get_building_color(building_type: int) -> Color:
	var entry := get_building_def(building_type)
	return _get_color_from_entry(entry, Color.WHITE)


func get_building_size(building_type: int, orientation: int = 0) -> Vector2i:
	var entry := get_building_def(building_type)

	var size_data: Dictionary = entry.get("size", {
		"x": 1,
		"y": 1
	})

	var size := Vector2i(
		int(size_data.get("x", 1)),
		int(size_data.get("y", 1))
	)

	if _orientation_swaps_size(orientation):
		return Vector2i(size.y, size.x)

	return size


func get_all_building_defs(include_none: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var buildings := _get_category("buildings")

	var keys := buildings.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))

	for key in keys:
		if not include_none and int(key) == 0:
			continue

		var entry: Dictionary = buildings[key].duplicate(true)
		entry["id"] = int(key)
		result.append(entry)

	return result


func get_entity_color(resource_type: int, building_type: int) -> Color:
	if building_type != 0:
		return get_building_color(building_type)

	if resource_type != 0:
		return get_resource_color(resource_type)

	return Color.WHITE


func get_entity_display_name(resource_type: int, building_type: int) -> String:
	if building_type != 0:
		return get_building_name(building_type)

	if resource_type != 0:
		return get_resource_name(resource_type)

	return "None"

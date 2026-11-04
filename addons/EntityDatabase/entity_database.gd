extends Node
## Loads and validates standalone entity archetype definitions.

enum StatTier {
	LOW = 0,
	NORMAL = 1,
	HIGH = 2,
}

const CATEGORY_RESOURCES := &"resources"
const CATEGORY_BUILDINGS := &"buildings"
const CATEGORY_UNITS := &"units"
const KEY_NAME := &"name"
const KEY_COLOR := &"color"
const KEY_SIZE := &"size"
const KEY_FACTION := &"faction"
const KEY_STATS := &"stats"
const KEY_RANGE := &"range"
const KEY_SPEED := &"speed"
const KEY_LIFE := &"life"
const KEY_DAMAGE := &"damage"
const FACTION_ENEMY := &"ENEMY"
const FACTION_FRIENDLY := &"FRIENDLY"
const STAT_TIER_BY_NAME := {
	&"LOW": StatTier.LOW,
	&"NORMAL": StatTier.NORMAL,
	&"HIGH": StatTier.HIGH,
}
const REQUIRED_CATEGORIES: Array[StringName] = [
	CATEGORY_RESOURCES,
	CATEGORY_BUILDINGS,
	CATEGORY_UNITS,
]
const REQUIRED_UNIT_STATS: Array[StringName] = [
	KEY_RANGE,
	KEY_SPEED,
	KEY_LIFE,
	KEY_DAMAGE,
]

@export_file("*.json") var entity_definitions_path: String = (
	"res://addons/EntityDatabase/entity_definitions.json"
)

var _definitions: Dictionary = {}
var _loaded := false


func _ready() -> void:
	load_definitions()


func load_definitions(path: String = "") -> bool:
	var final_path := path if not path.is_empty() else entity_definitions_path
	if not FileAccess.file_exists(final_path):
		return _fail_load("Definitions file not found: " + final_path)

	var file := FileAccess.open(final_path, FileAccess.READ)
	if file == null:
		return _fail_load("Could not open definitions file: " + final_path)

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return _fail_load(
			"Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		)
	if typeof(json.data) != TYPE_DICTIONARY:
		return _fail_load("Definitions root must be a dictionary: " + final_path)

	var definitions: Dictionary = json.data
	if not _validate_definitions(definitions):
		return _fail_load("Definitions do not match the required schema: " + final_path)

	_definitions = definitions.duplicate(true)
	_loaded = true
	print("[EntityDatabase] Loaded definitions: ", final_path)
	return true


func is_loaded() -> bool:
	return _loaded


func get_definitions() -> Dictionary:
	_ensure_loaded()
	return _definitions.duplicate(true)


func get_resource_def(resource_id: StringName) -> Dictionary:
	return _get_entry(CATEGORY_RESOURCES, resource_id)


func get_resource_name(resource_id: StringName) -> String:
	return str(get_resource_def(resource_id).get(String(KEY_NAME), "Unknown Resource"))


func get_resource_color(resource_id: StringName) -> Color:
	return _get_color_from_entry(get_resource_def(resource_id), Color.WHITE)


func get_all_resource_defs() -> Array[Dictionary]:
	return _get_all_entries(CATEGORY_RESOURCES)


func get_building_def(building_id: StringName) -> Dictionary:
	return _get_entry(CATEGORY_BUILDINGS, building_id)


func get_building_name(building_id: StringName) -> String:
	return str(get_building_def(building_id).get(String(KEY_NAME), "Unknown Building"))


func get_building_color(building_id: StringName) -> Color:
	return _get_color_from_entry(get_building_def(building_id), Color.WHITE)


func get_building_size(building_id: StringName, rotated := false) -> Vector2i:
	var entry := get_building_def(building_id)
	var size_data: Dictionary = entry.get(String(KEY_SIZE), {})
	var size := Vector2i(int(size_data.get("x", 1)), int(size_data.get("y", 1)))
	return Vector2i(size.y, size.x) if rotated else size


func get_all_building_defs() -> Array[Dictionary]:
	return _get_all_entries(CATEGORY_BUILDINGS)


func get_unit_def(unit_id: StringName) -> Dictionary:
	return _get_entry(CATEGORY_UNITS, unit_id)


func get_unit_name(unit_id: StringName) -> String:
	return str(get_unit_def(unit_id).get(String(KEY_NAME), "Unknown Unit"))


func get_unit_faction(unit_id: StringName) -> StringName:
	return StringName(get_unit_def(unit_id).get(String(KEY_FACTION), ""))


func get_unit_stat_tier(unit_id: StringName, stat: StringName) -> StatTier:
	var stats: Dictionary = get_unit_def(unit_id).get(String(KEY_STATS), {})
	var tier_name := StringName(stats.get(String(stat), "NORMAL"))
	return STAT_TIER_BY_NAME.get(tier_name, StatTier.NORMAL)


func get_all_unit_defs(faction: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _get_all_entries(CATEGORY_UNITS):
		if not faction.is_empty() and StringName(entry.get(String(KEY_FACTION), "")) != faction:
			continue
		result.append(entry)
	return result


func _ensure_loaded() -> void:
	if not _loaded:
		load_definitions()


func _get_category(category: StringName) -> Dictionary:
	_ensure_loaded()
	return _definitions.get(String(category), {})


func _get_entry(category: StringName, entity_id: StringName) -> Dictionary:
	var entry: Dictionary = _get_category(category).get(String(entity_id), {})
	return entry.duplicate(true)


func _get_all_entries(category: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var category_data := _get_category(category)
	var ids := category_data.keys()
	ids.sort()
	for entity_id in ids:
		var entry: Dictionary = category_data[entity_id].duplicate(true)
		entry["id"] = StringName(entity_id)
		result.append(entry)
	return result


func _get_color_from_entry(entry: Dictionary, fallback: Color) -> Color:
	var color_string := str(entry.get(String(KEY_COLOR), ""))
	if not Color.html_is_valid(color_string):
		return fallback
	return Color.html(color_string)


func _validate_definitions(definitions: Dictionary) -> bool:
	if int(definitions.get("version", 0)) < 1:
		push_error("[EntityDatabase] Missing or invalid schema version.")
		return false

	for category in REQUIRED_CATEGORIES:
		var category_data = definitions.get(String(category))
		if typeof(category_data) != TYPE_DICTIONARY or category_data.is_empty():
			push_error("[EntityDatabase] Missing or empty category: " + String(category))
			return false

	if not _validate_named_entries(definitions[String(CATEGORY_RESOURCES)]):
		return false
	if not _validate_buildings(definitions[String(CATEGORY_BUILDINGS)]):
		return false
	return _validate_units(definitions[String(CATEGORY_UNITS)])


func _validate_named_entries(entries: Dictionary) -> bool:
	for entity_id in entries:
		var entry = entries[entity_id]
		if str(entity_id).is_empty() or typeof(entry) != TYPE_DICTIONARY:
			push_error("[EntityDatabase] Entity IDs and entries must be valid dictionaries.")
			return false
		if str(entry.get(String(KEY_NAME), "")).is_empty():
			push_error("[EntityDatabase] Entity is missing a name: " + str(entity_id))
			return false
	return true


func _validate_buildings(buildings: Dictionary) -> bool:
	if not _validate_named_entries(buildings):
		return false
	for building_id in buildings:
		var size = buildings[building_id].get(String(KEY_SIZE))
		if typeof(size) != TYPE_DICTIONARY:
			push_error("[EntityDatabase] Building is missing its size: " + str(building_id))
			return false
		if int(size.get("x", 0)) <= 0 or int(size.get("y", 0)) <= 0:
			push_error("[EntityDatabase] Building size must be positive: " + str(building_id))
			return false
	return true


func _validate_units(units: Dictionary) -> bool:
	if not _validate_named_entries(units):
		return false
	for unit_id in units:
		var unit: Dictionary = units[unit_id]
		var faction := StringName(unit.get(String(KEY_FACTION), ""))
		if faction != FACTION_ENEMY and faction != FACTION_FRIENDLY:
			push_error("[EntityDatabase] Unit has invalid faction: " + str(unit_id))
			return false
		var stats = unit.get(String(KEY_STATS))
		if typeof(stats) != TYPE_DICTIONARY:
			push_error("[EntityDatabase] Unit is missing stats: " + str(unit_id))
			return false
		for stat in REQUIRED_UNIT_STATS:
			var tier := StringName(stats.get(String(stat), ""))
			if not STAT_TIER_BY_NAME.has(tier):
				push_error(
					"[EntityDatabase] Unit %s has invalid %s tier." % [unit_id, stat]
				)
				return false
	return true


func _fail_load(message: String) -> bool:
	push_error("[EntityDatabase] " + message)
	_definitions = {}
	_loaded = false
	return false

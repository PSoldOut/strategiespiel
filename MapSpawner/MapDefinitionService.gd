extends RefCounted
class_name MapDefinitionService

static func load_entity_definitions(entity_definitions_path: String) -> Dictionary:
	var entity_definitions: Dictionary = {}

	if entity_definitions_path.is_empty():
		push_warning("MapSpawner: entity_definitions_path is empty.")
		return entity_definitions

	if not FileAccess.file_exists(entity_definitions_path):
		push_warning("MapSpawner: entity definitions file not found: " + entity_definitions_path)
		return entity_definitions

	var file := FileAccess.open(entity_definitions_path, FileAccess.READ)
	if file == null:
		push_warning("MapSpawner: could not open entity definitions: " + entity_definitions_path)
		return entity_definitions

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("MapSpawner: could not parse entity definitions: " + entity_definitions_path)
		return entity_definitions

	if typeof(json.data) != TYPE_DICTIONARY:
		push_warning("MapSpawner: entity definitions root must be a Dictionary.")
		return entity_definitions

	return json.data


static func color_from_definition(definition: Dictionary, fallback: Color) -> Color:
	var color_value = definition.get("color", "")
	if typeof(color_value) == TYPE_STRING and not String(color_value).is_empty():
		return Color.html(String(color_value))

	return fallback

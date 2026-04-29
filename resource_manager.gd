extends Node
class_name ResourceManager

@export var map_spawner: MapSpawner
@export var map_file_path: String = "res://map_save.json"
@export var resource_scene: PackedScene
@export var resource_height_offset: float = 1.0

var spawned_resources: Array[GameResource] = []


func _ready() -> void:
	if map_spawner == null:
		push_error("ResourceManager: map_spawner ist nicht gesetzt.")
		return

	if resource_scene == null:
		push_error("ResourceManager: resource_scene ist nicht gesetzt.")
		return

	map_spawner.map_spawned.connect(_on_map_spawned)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(_on_resource_timer)


func _on_map_spawned() -> void:
	clear_resources()
	spawn_resources_from_json()


func _on_resource_timer() -> void:
	print("resource_timer")
	get_tree().call_group("resources", "on_resource_timer")


func spawn_resources_from_json() -> void:
	var map_data := load_map_data_from_json(map_file_path)

	if map_data.is_empty():
		push_warning("ResourceManager: Keine map_data gefunden.")
		return

	for y in range(map_data.size()):
		var row: Array = map_data[y]

		for x in range(row.size()):
			var cell = row[x]

			if typeof(cell) != TYPE_DICTIONARY:
				continue

			var tile_type := int(cell.get("type", EnumMappings.TileEnums.STANDAD_TILE))

			if tile_type == EnumMappings.TileEnums.GOLD_TILE:
				spawn_resource_at_cell(x, y, cell)


func spawn_resource_at_cell(x: int, y: int, cell: Dictionary) -> void:
	var height_value := float(cell.get("height", 0.0))

	var resource := resource_scene.instantiate() as Node3D
	add_child(resource)

	resource.global_position = Vector3(
		(x * MapSpawner.TILE_SIZE)+(MapSpawner.TILE_SIZE/2),
		height_value + resource_height_offset,
		(y * MapSpawner.TILE_SIZE)+(MapSpawner.TILE_SIZE/2)
	)

	spawned_resources.append(resource)

	print("Resource gespawnt bei x:", x, " y:", y, " height:", height_value)


func load_map_data_from_json(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("ResourceManager: Map file nicht gefunden: " + path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ResourceManager: Konnte Map file nicht öffnen: " + path)
		return []

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	var result := json.parse(content)

	if result != OK:
		push_error("ResourceManager: JSON Parse Error.")
		return []

	var data = json.data

	if typeof(data) == TYPE_DICTIONARY:
		return data.get("map_data", [])

	if typeof(data) == TYPE_ARRAY:
		return data

	return []


func clear_resources() -> void:
	for resource in spawned_resources:
		if is_instance_valid(resource):
			resource.queue_free()

	spawned_resources.clear()

extends Node
class_name ResourceManager

@export var map_spawner: MapSpawner
@export var resource_scene: PackedScene
@export var resource_height_offset: float = 1.0

var spawned_resources: Array[Node3D] = []
var resource_timer: Timer


func _ready() -> void:
	if map_spawner == null:
		push_error("ResourceManager: map_spawner ist nicht gesetzt.")
		return

	if resource_scene == null:
		push_error("ResourceManager: resource_scene ist nicht gesetzt.")
		return

	# MapSpawner emits: map_spawned(map_data)
	# CONNECT_DEFERRED makes sure this runs after the rebuild frame is finished.
	if not map_spawner.map_spawned.is_connected(_on_map_spawned):
		map_spawner.map_spawned.connect(_on_map_spawned, CONNECT_DEFERRED)

	_create_resource_timer()

	# If ResourceManager enters the scene after MapSpawner already built the map,
	# spawn once from the current in-memory data.
	if not map_spawner.map_data.is_empty():
		call_deferred("_on_map_spawned", map_spawner.map_data)


func _create_resource_timer() -> void:
	resource_timer = Timer.new()
	resource_timer.name = "ResourceTimer"
	resource_timer.wait_time = 1.0
	resource_timer.one_shot = false
	resource_timer.autostart = true
	add_child(resource_timer)
	resource_timer.timeout.connect(_on_resource_timer)


func _on_map_spawned(new_map_data: Array) -> void:
	clear_resources()
	spawn_resources_from_map_data(new_map_data)


func _on_resource_timer() -> void:
	get_tree().call_group("resources", "on_resource_timer")


func spawn_resources_from_map_data(source_map_data: Array) -> void:
	if source_map_data.is_empty():
		push_warning("ResourceManager: Keine map_data gefunden.")
		return

	for y in range(source_map_data.size()):
		if typeof(source_map_data[y]) != TYPE_ARRAY:
			continue

		var row: Array = source_map_data[y]

		for x in range(row.size()):
			var cell = row[x]

			if typeof(cell) != TYPE_DICTIONARY:
				continue

			var tile_type := int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))

			if tile_type == EnumMappings.TileTypeEnums.GOLD_TILE:
				spawn_resource_at_cell(x, y, cell)


func spawn_resource_at_cell(x: int, y: int, cell: Dictionary) -> void:
	var height_value := float(cell.get("height", 0.0))

	var resource := resource_scene.instantiate() as Node3D
	if resource == null:
		push_error("ResourceManager: resource_scene root must be Node3D.")
		return

	add_child(resource)

	resource.global_position = Vector3(
		(x * MapSpawner.TILE_SIZE) + (MapSpawner.TILE_SIZE / 2.0),
		height_value + resource_height_offset,
		(y * MapSpawner.TILE_SIZE) + (MapSpawner.TILE_SIZE / 2.0)
	)

	spawned_resources.append(resource)

	print("Resource gespawnt bei x:", x, " y:", y, " height:", height_value)


func clear_resources() -> void:
	for resource in spawned_resources:
		if is_instance_valid(resource):
			resource.queue_free()

	spawned_resources.clear()

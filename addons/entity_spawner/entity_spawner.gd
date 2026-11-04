class_name EntitySpawner
extends Node3D
## Instantiates catalogued Node3D scenes at configured or explicit transforms.

signal entity_spawned(entity_id: StringName, entity: Node3D)
signal spawn_failed(entity_id: StringName, reason: String)

enum SpawnPointSelection {
	RANDOM = 0,
	SEQUENTIAL = 1,
}

@export var catalog: EntitySpawnCatalog
@export var spawn_parent: Node3D
@export var spawn_points: Array[Marker3D] = []
@export var selection_mode := SpawnPointSelection.RANDOM
@export var random_seed: int = 0

var _next_spawn_point_index := 0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	if random_seed == 0:
		_random.randomize()
	else:
		_random.seed = random_seed


func spawn_entity(entity_id: StringName) -> Node3D:
	var spawn_point := _select_spawn_point()
	if spawn_point == null:
		return _fail_spawn(entity_id, "No valid spawn point is configured.")
	return spawn_entity_at_point(entity_id, spawn_point)


func spawn_entity_at_index(entity_id: StringName, point_index: int) -> Node3D:
	if point_index < 0 or point_index >= spawn_points.size():
		return _fail_spawn(entity_id, "Spawn point index is out of range.")

	var spawn_point := spawn_points[point_index]
	if not is_instance_valid(spawn_point):
		return _fail_spawn(entity_id, "Spawn point is not valid.")
	return spawn_entity_at_point(entity_id, spawn_point)


func spawn_entity_at_point(entity_id: StringName, spawn_point: Marker3D) -> Node3D:
	if not is_instance_valid(spawn_point):
		return _fail_spawn(entity_id, "Spawn point is not valid.")
	return spawn_entity_at_transform(entity_id, spawn_point.global_transform)


func spawn_entity_at_transform(entity_id: StringName, spawn_transform: Transform3D) -> Node3D:
	if catalog == null:
		return _fail_spawn(entity_id, "Spawn catalog is not configured.")
	if not catalog.has_entity(entity_id):
		return _fail_spawn(entity_id, "Entity ID is not registered in the spawn catalog.")

	var scene := catalog.get_scene(entity_id)
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return _fail_spawn(entity_id, "Entity scene root must inherit Node3D.")

	var entity := instance as Node3D
	var target_parent := spawn_parent if spawn_parent != null else self
	target_parent.add_child(entity)
	entity.global_transform = spawn_transform
	entity_spawned.emit(entity_id, entity)
	return entity


func reset_sequence() -> void:
	_next_spawn_point_index = 0


func _select_spawn_point() -> Marker3D:
	var valid_points: Array[Marker3D] = []
	for spawn_point in spawn_points:
		if is_instance_valid(spawn_point):
			valid_points.append(spawn_point)

	if valid_points.is_empty():
		return null

	match selection_mode:
		SpawnPointSelection.SEQUENTIAL:
			var index := _next_spawn_point_index % valid_points.size()
			_next_spawn_point_index += 1
			return valid_points[index]
		_:
			return valid_points[_random.randi_range(0, valid_points.size() - 1)]


func _fail_spawn(entity_id: StringName, reason: String) -> Node3D:
	push_error("EntitySpawner: %s Entity: %s" % [reason, entity_id])
	spawn_failed.emit(entity_id, reason)
	return null

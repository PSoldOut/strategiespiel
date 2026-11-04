class_name RunMapController
extends Node
## Starts each gameplay run with a freshly seeded generated map.

signal map_generated(result: MapGenerationResult)

@export var map_spawner: MapSpawner
@export var generation_config: MapGeneratorConfig
@export var decoration_spawner: EntitySpawner
@export var generate_on_ready := true

var current_seed: int = 0
var current_result: MapGenerationResult
var _spawned_decorations: Array[Node3D] = []


func _ready() -> void:
	if generate_on_ready:
		call_deferred("start_new_run")


func start_new_run(seed: int = -1) -> MapGenerationResult:
	if map_spawner == null or generation_config == null:
		push_error("RunMapController requires MapSpawner and MapGeneratorConfig.")
		return null

	_clear_decorations()
	current_seed = seed if seed >= 0 else _create_random_seed()
	current_result = map_spawner.generate_new_run_map(generation_config, current_seed)
	if current_result == null:
		return null

	if decoration_spawner != null:
		_spawned_decorations = map_spawner.spawn_generated_decorations(decoration_spawner)
	map_generated.emit(current_result)
	return current_result


func _create_random_seed() -> int:
	var random := RandomNumberGenerator.new()
	random.randomize()
	return random.randi_range(1, 2_147_483_647)


func _clear_decorations() -> void:
	for decoration in _spawned_decorations:
		if is_instance_valid(decoration):
			decoration.queue_free()
	_spawned_decorations.clear()

class_name MapDecorationSpawner
extends RefCounted
## Places generated decoration records through the standalone EntitySpawner.

const META_COLLISION_MODE := &"generated_collision_mode"
const QUARTER_TURN_RADIANS := TAU / 4.0


static func spawn_all(
	result: MapGenerationResult,
	spawner: EntitySpawner,
	tile_size: float,
) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	if result == null or spawner == null:
		return spawned

	for decoration in result.decorations:
		var entity_id := StringName(decoration.get(&"id", ""))
		var grid_position: Vector2i = decoration.get(&"grid_position", Vector2i.ZERO)
		if entity_id.is_empty() or not _is_valid_grid_position(result.map_data, grid_position):
			continue

		var cell: Dictionary = result.map_data[grid_position.y][grid_position.x]
		var height := float(cell.get(&"height", 0.0))
		var rotation_steps := posmod(int(decoration.get(&"rotation_steps", 0)), 4)
		var basis := Basis(Vector3.UP, float(rotation_steps) * QUARTER_TURN_RADIANS)
		var origin := Vector3(
			(float(grid_position.x) + 0.5) * tile_size,
			height,
			(float(grid_position.y) + 0.5) * tile_size,
		)
		var entity := spawner.spawn_entity_at_transform(entity_id, Transform3D(basis, origin))
		if entity == null:
			continue

		var collision_mode := int(
			decoration.get(&"collision_mode", MapDecorationRule.CollisionMode.NONE)
		)
		entity.set_meta(META_COLLISION_MODE, collision_mode)
		if collision_mode == MapDecorationRule.CollisionMode.BLOCKING:
			_warn_if_blocking_decoration_has_no_collision(entity, entity_id)
		spawned.append(entity)
	return spawned


static func _is_valid_grid_position(map_data: Array, position: Vector2i) -> bool:
	return (
		position.y >= 0
		and position.y < map_data.size()
		and map_data[position.y] is Array
		and position.x >= 0
		and position.x < map_data[position.y].size()
	)


static func _warn_if_blocking_decoration_has_no_collision(
	entity: Node3D,
	entity_id: StringName,
) -> void:
	if _contains_collision_shape(entity):
		return
	push_warning(
		"Blocking decoration '%s' has no CollisionShape3D in its spawned scene." % entity_id
	)


static func _contains_collision_shape(node: Node) -> bool:
	if node is CollisionShape3D:
		return true
	for child in node.get_children():
		if _contains_collision_shape(child):
			return true
	return false

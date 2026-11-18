extends Node
class_name AbilitySystem

## Executes abilities described by the content catalog.
## All rules and costs are checked by Game.gd before an ability reaches here.
##
## Runtime state such as training queues and rally points lives here, not in
## the data-only resources.

class PendingSpawn extends RefCounted:
	var ability: SpawnUnitAbility = null
	var source: Node3D = null
	var source_id: int = 0
	var team: String = ""
	var fallback_position: Vector3 = Vector3.ZERO
	var remaining: float = 0.0


signal ability_used(id: StringName)
signal upgrade_added(team: String, upgrade: StringName)
signal tag_unlock_requested(tag: StringName)
signal rally_point_changed(source: Node3D, position: Vector3)
signal training_completed(source: Node3D, ability: StringName)

@export var content: GameContentCatalog
@export var agents_root: Node3D
@export var drag_selection: DragSelection

var _team_upgrades: Dictionary = {}
var _rally_points: Dictionary = {}
var _pending_spawns: Array[PendingSpawn] = []


func _process(delta: float) -> void:
	if _pending_spawns.is_empty():
		return

	# Iterate backwards so completed entries can be removed in place.
	for index in range(_pending_spawns.size() - 1, -1, -1):
		var entry: PendingSpawn = _pending_spawns[index]
		entry.remaining -= delta
		if entry.remaining > 0.0:
			continue

		_complete_spawn(entry)
		_pending_spawns.remove_at(index)


func can_execute(ability: AbilityDefinition, source: Node3D = null) -> bool:
	if ability == null:
		return false

	if ability is SpawnUnitAbility:
		var spawn_ability := ability as SpawnUnitAbility
		return agents_root != null \
			and content != null \
			and content.get_unit(spawn_ability.unit) != null

	if ability is UpgradeAbility:
		var upgrade_ability := ability as UpgradeAbility
		return content != null and content.get_upgrade(upgrade_ability.upgrade) != null

	if ability is SetRallyPointAbility:
		return source != null and is_instance_valid(source) and source.is_inside_tree()

	return ability is UnlockTagAbility


func use(
	ability: AbilityDefinition,
	source: Node3D,
	team: String,
	_context: ContentContext,
	target_position: Vector3
) -> bool:
	if not can_execute(ability, source):
		return false

	var used := false
	if ability is SpawnUnitAbility:
		var spawn_ability := ability as SpawnUnitAbility
		if spawn_ability.duration > 0.0:
			used = _queue_spawn(spawn_ability, source, team, target_position)
		else:
			used = _spawn_unit(spawn_ability, team, target_position)
	elif ability is UpgradeAbility:
		used = _add_upgrade(ability as UpgradeAbility, team)
	elif ability is SetRallyPointAbility:
		used = set_rally_point(source, target_position)
	elif ability is UnlockTagAbility:
		tag_unlock_requested.emit((ability as UnlockTagAbility).tag)
		used = true

	if used:
		ability_used.emit(ability.id)
	return used


func get_upgrades(team: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var value: Variant = _team_upgrades.get(team, null)
	if value is Array:
		var values: Array = value
		for entry in values:
			result.append(StringName(str(entry)))
	return result


## Stores a rally point for one source building. Spawned units use the newest
## point, even if it was changed while they were still training.
func set_rally_point(source: Node3D, world_position: Vector3) -> bool:
	if source == null or not is_instance_valid(source):
		return false

	_rally_points[source.get_instance_id()] = world_position
	rally_point_changed.emit(source, world_position)
	return true


func has_rally_point(source: Node3D) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	return _rally_points.has(source.get_instance_id())


func get_rally_point(source: Node3D) -> Vector3:
	if source == null or not is_instance_valid(source):
		return Vector3.ZERO
	var value: Variant = _rally_points.get(source.get_instance_id(), Vector3.ZERO)
	if value is Vector3:
		return value as Vector3
	return Vector3.ZERO


## Returns [code]{"count": int, "remaining": float}[/code] for one building.
func get_queue_info(source: Node3D) -> Dictionary:
	if source == null or not is_instance_valid(source):
		return {"count": 0, "remaining": 0.0}

	var source_id: int = source.get_instance_id()
	var count := 0
	var remaining := 0.0
	for index in range(_pending_spawns.size()):
		var entry: PendingSpawn = _pending_spawns[index]
		if entry.source_id != source_id:
			continue
		if count == 0:
			remaining = maxf(entry.remaining, 0.0)
		count += 1
	return {"count": count, "remaining": remaining}


func _queue_spawn(
	ability: SpawnUnitAbility,
	source: Node3D,
	team: String,
	fallback_position: Vector3
) -> bool:
	if agents_root == null or content == null:
		return false

	var entry := PendingSpawn.new()
	entry.ability = ability
	entry.source = source
	if source != null:
		entry.source_id = source.get_instance_id()
	entry.team = team
	entry.fallback_position = fallback_position
	entry.remaining = maxf(ability.duration, 0.01)
	_pending_spawns.append(entry)
	return true


func _complete_spawn(entry: PendingSpawn) -> void:
	var origin := entry.fallback_position
	if has_rally_point(entry.source):
		origin = get_rally_point(entry.source)

	if not _spawn_unit(entry.ability, entry.team, origin):
		return

	if entry.source != null and is_instance_valid(entry.source):
		training_completed.emit(entry.source, entry.ability.id)


func _spawn_unit(ability: SpawnUnitAbility, team: String, origin: Vector3) -> bool:
	var definition := content.get_unit(ability.unit)
	if definition == null or definition.scene == null:
		return false

	var total: int = maxi(ability.count, 1)
	for index in range(total):
		var instance: Node = definition.scene.instantiate()
		var unit := instance as Node3D
		if unit == null:
			instance.free()
			continue

		if unit.get("team") != null:
			unit.set("team", team)

		var offset := Vector3(
			float(index % 3) * 1.5 - 1.5,
			0.0,
			floori(float(index) / 3.0) * 1.5
		)
		agents_root.add_child(unit)
		unit.global_position = origin + ability.spawn_offset + offset

		if drag_selection != null:
			drag_selection.register_unit(unit)
	return true


func _add_upgrade(ability: UpgradeAbility, team: String) -> bool:
	var current := get_upgrades(team)
	if current.has(ability.upgrade):
		return false

	current.append(ability.upgrade)
	_team_upgrades[team] = current
	upgrade_added.emit(team, ability.upgrade)
	return true

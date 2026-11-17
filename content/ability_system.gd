extends Node
class_name AbilitySystem

## Executes abilities described by the content catalog.
## All rules and costs are checked by Game.gd before an ability reaches here.

signal ability_used(id: StringName)
signal upgrade_added(team: String, upgrade: StringName)
signal tag_unlock_requested(tag: StringName)

@export var content: GameContentCatalog
@export var agents_root: Node3D
@export var drag_selection: DragSelection

var _team_upgrades: Dictionary = {}


func can_execute(ability: AbilityDefinition) -> bool:
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

	return ability is UnlockTagAbility


func use(
	ability: AbilityDefinition,
	_source: Node3D,
	team: String,
	_context: ContentContext,
	spawn_position: Vector3
) -> bool:
	if not can_execute(ability):
		return false

	var used := false
	if ability is SpawnUnitAbility:
		used = _spawn_unit(ability as SpawnUnitAbility, team, spawn_position)
	elif ability is UpgradeAbility:
		used = _add_upgrade(ability as UpgradeAbility, team)
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

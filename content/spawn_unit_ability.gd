extends AbilityDefinition
class_name SpawnUnitAbility

## Spawns one or more units described by a [UnitDefinition] in the catalog.

@export var unit: StringName = &""
@export var count: int = 1
## Offset from the generator's spawn position, used to avoid overlapping units.
@export var spawn_offset: Vector3 = Vector3.ZERO

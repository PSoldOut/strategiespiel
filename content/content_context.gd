extends Resource
class_name ContentContext

## Read-only snapshot of the game state used for content checks.
## The catalog never reaches into game nodes itself.

@export var team: String = ""
@export var owned_buildings: Array[StringName] = []
@export var unlocked_tags: Array[StringName] = []
@export var upgrades: Array[StringName] = []
@export var resources: Dictionary = {}


func can_afford(costs: Dictionary) -> bool:
	for resource_id in costs:
		var key := StringName(str(resource_id))
		var amount: int = int(costs[resource_id])
		if int(resources.get(key, 0)) < amount:
			return false
	return true

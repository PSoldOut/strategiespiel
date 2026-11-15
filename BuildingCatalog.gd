extends Resource
class_name BuildingCatalog

## Data driven list of buildings and their prerequisites.

@export var buildings: Array[BuildingDefinition] = []


func get_definition(id: StringName) -> BuildingDefinition:
	for building in buildings:
		if building != null and building.id == id:
			return building
	return null


## Buildings that can be built with the given owned building ids and unlocked
## abstract tags.
func get_available(
	owned_ids: Array,
	unlocked_tags: Array = []
) -> Array[BuildingDefinition]:
	var available: Array[BuildingDefinition] = []
	for building in buildings:
		if building != null and is_available(building, owned_ids, unlocked_tags):
			available.append(building)
	return available


func is_available(
	building: BuildingDefinition,
	owned_ids: Array,
	unlocked_tags: Array = []
) -> bool:
	for requirement in building.requires:
		if not owned_ids.has(requirement):
			return false
	for tag in building.unlocked_by:
		if not unlocked_tags.has(tag):
			return false
	return true

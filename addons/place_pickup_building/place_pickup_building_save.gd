@tool
class_name PlacePickupBuildingSave
extends Resource
## Serializable snapshot owned by the consuming game's save system.

@export var selected_building_id: StringName
@export var building_states: Array[PlaceableBuildingState] = []

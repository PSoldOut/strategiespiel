@tool
class_name PlaceableBuildingState
extends Resource
## Serializable placement state for one unique building.

enum PlacementState {
	HELD = 0,
	PLACED = 1,
}

@export var building_id: StringName
@export var placement_state := PlacementState.HELD
@export var placed_transform := Transform3D.IDENTITY


func is_held() -> bool:
	return placement_state == PlacementState.HELD


func is_placed() -> bool:
	return placement_state == PlacementState.PLACED

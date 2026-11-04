@tool
class_name PlaceableBuildingDefinition
extends Resource
## Defines one unique building that can alternate between held and placed.

@export var building_id: StringName
@export var scene: PackedScene
@export var footprint := Vector2i.ONE


func is_valid() -> bool:
	return (
		not building_id.is_empty()
		and scene != null
		and footprint.x > 0
		and footprint.y > 0
	)

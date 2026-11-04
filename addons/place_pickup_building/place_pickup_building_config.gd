@tool
class_name PlacePickupBuildingConfig
extends Resource
## Configures selection input and preview presentation.

@export var input_enabled := true
@export var select_next_action := &"building_select_next"
@export var select_previous_action := &"building_select_previous"
@export var valid_preview_color := Color(0.2, 1.0, 0.3, 0.45)
@export var invalid_preview_color := Color(1.0, 0.2, 0.2, 0.45)

@tool
extends EditorPlugin

const CONFIG_SCRIPT := preload("res://addons/place_pickup_building/place_pickup_building_config.gd")
const DEFINITION_SCRIPT := preload(
	"res://addons/place_pickup_building/placeable_building_definition.gd"
)
const STATE_SCRIPT := preload("res://addons/place_pickup_building/placeable_building_state.gd")
const SAVE_SCRIPT := preload("res://addons/place_pickup_building/place_pickup_building_save.gd")
const SYSTEM_SCRIPT := preload(
	"res://addons/place_pickup_building/place_pickup_building_system.gd"
)


func _enter_tree() -> void:
	add_custom_type("PlaceableBuildingDefinition", "Resource", DEFINITION_SCRIPT, null)
	add_custom_type("PlaceableBuildingState", "Resource", STATE_SCRIPT, null)
	add_custom_type("PlacePickupBuildingSave", "Resource", SAVE_SCRIPT, null)
	add_custom_type("PlacePickupBuildingConfig", "Resource", CONFIG_SCRIPT, null)
	add_custom_type("PlacePickupBuildingSystem", "Node3D", SYSTEM_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("PlacePickupBuildingSystem")
	remove_custom_type("PlacePickupBuildingConfig")
	remove_custom_type("PlacePickupBuildingSave")
	remove_custom_type("PlaceableBuildingState")
	remove_custom_type("PlaceableBuildingDefinition")

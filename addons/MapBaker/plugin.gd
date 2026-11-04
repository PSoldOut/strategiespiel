@tool
extends EditorPlugin

const MAP_BAKER_SCRIPT := preload("res://addons/MapBaker/map_baker.gd")
const MAP_BAKER_CONFIG_SCRIPT := preload("res://addons/MapBaker/map_baker_config.gd")


func _enter_tree() -> void:
	add_custom_type("MapBakerConfig", "Resource", MAP_BAKER_CONFIG_SCRIPT, null)
	add_custom_type("MapBaker", "Node3D", MAP_BAKER_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("MapBaker")
	remove_custom_type("MapBakerConfig")

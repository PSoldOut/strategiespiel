@tool
extends EditorPlugin

const MAP_BAKER_SCRIPT := preload("res://addons/mapbaker/map_baker.gd")

func _enter_tree() -> void:
	add_custom_type("MapBaker", "Node3D", MAP_BAKER_SCRIPT, null)


func _exit_tree() -> void:
	remove_custom_type("MapBaker")

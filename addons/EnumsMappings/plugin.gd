@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("EnumMappings", "Node", preload("enum_mappings.gd"), preload("icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("EnumMappings")

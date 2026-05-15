@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("DragSelection")
	pass
	
func _exit_tree() -> void:
	remove_custom_type("DragSelection")

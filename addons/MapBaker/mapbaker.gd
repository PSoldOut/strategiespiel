@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	add_custom_type("MapBaker", "Node3D", preload("res://addons/MapBaker/map_baker.gd"), preload("icon.svg"))
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass

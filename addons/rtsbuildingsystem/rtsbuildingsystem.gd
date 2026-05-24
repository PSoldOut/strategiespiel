@tool
extends EditorPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	add_custom_type("RTSBuildSystem", "Node3D", preload("res://addons/rtsbuildingsystem/system.gd"), preload("icon.svg"))
	add_custom_type("RTSBuilding", "Node3D", preload("res://addons/rtsbuildingsystem/rts_building.gd"), preload("icon.svg"))
	pass


func _exit_tree() -> void:
	remove_custom_type("RTSBuildSystem")
	pass

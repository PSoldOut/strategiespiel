@tool
extends EditorPlugin

const INTERFACE_SCRIPT := preload("res://addons/rtsuserinterface/ui.gd")
const ENTRY_SCRIPT := preload("res://addons/rtsuserinterface/ui_entry.gd")
const INTERFACE_ICON := preload("res://addons/rtsuserinterface/icon.svg")


func _enter_tree() -> void:
	add_custom_type("RTSUserInterface", "Control", INTERFACE_SCRIPT, INTERFACE_ICON)
	add_custom_type("UIEntry", "Resource", ENTRY_SCRIPT, INTERFACE_ICON)


func _exit_tree() -> void:
	remove_custom_type("RTSUserInterface")
	remove_custom_type("UIEntry")

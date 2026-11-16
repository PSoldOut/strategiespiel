@tool
extends EditorPlugin

## Adds a toolbar button that opens the independent map generator scene.

const GENERATOR_SCENE := "res://addons/mapgenerator/map_generator.tscn"

var _toolbar_button: Button


func _enter_tree() -> void:
	_toolbar_button = Button.new()
	_toolbar_button.text = "Map Generator"
	_toolbar_button.tooltip_text = "Eigenständigen Karten-Editor öffnen"
	_toolbar_button.focus_mode = Control.FOCUS_NONE
	_toolbar_button.pressed.connect(_open_generator)
	add_control_to_container(CONTAINER_TOOLBAR, _toolbar_button)
	add_tool_menu_item("Map Generator", _open_generator)


func _exit_tree() -> void:
	remove_tool_menu_item("Map Generator")
	if _toolbar_button != null:
		remove_control_from_container(CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null


func _open_generator() -> void:
	if not ResourceLoader.exists(GENERATOR_SCENE):
		push_error("Map Generator scene not found: %s" % GENERATOR_SCENE)
		return
	EditorInterface.play_custom_scene(GENERATOR_SCENE)

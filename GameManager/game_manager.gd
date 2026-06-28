extends Node
class_name GameManager


var current_state: int = -1
var current_scene: Node = null

@onready var current_state_root: Node = $"../CurrentStateRoot"

var state_scenes := {
	EnumMappings.GameState.MAIN_MENU: preload("res://GameManager/MainMenue/MainMenueManager.tscn"),
	EnumMappings.GameState.MAP_EDITOR: preload("res://GameManager/MapEditor/MapEditorManager.tscn")
}


func _ready() -> void:
	change_state(EnumMappings.GameState.MAIN_MENU)


func change_state(new_state: EnumMappings.GameState) -> void:
	if current_state == new_state:
		return

	if current_scene != null:
		if current_scene.has_method("exit_state"):
			current_scene.exit_state()

		current_scene.queue_free()
		current_scene = null

	current_state = new_state

	var scene: PackedScene = state_scenes[new_state]
	current_scene = scene.instantiate()
	current_state_root.add_child(current_scene)

	if current_scene.has_method("enter_state"):
		current_scene.enter_state()

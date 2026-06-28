extends Node3D
class_name MapEditorManager

@onready var MapEditor: Node3D = $MapEditor

@onready var quit_button: Button = $MapEditor/CanvasLayer/TilePalette/VBoxContainer/QuitButton


func _ready() -> void:
	quit_button.pressed.connect(_on_quit_pressed)


func show_panel(panel: Control) -> void:
	panel.visible = true



func _on_quit_pressed() -> void:
	var game_manager: GameManager = get_node("../../GameManager")
	game_manager.change_state(EnumMappings.GameState.MAIN_MENU)

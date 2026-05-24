extends Control
class_name MainMenueManager

@onready var main_menu_panel: Control = $MainMenuePanel

@onready var map_editor_button: Button = $MainMenuePanel/VBoxContainer/MapEditorButton
@onready var quit_button: Button = $MainMenuePanel/VBoxContainer/QuitButton


func _ready() -> void:
	map_editor_button.pressed.connect(_on_map_editor_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	show_panel(main_menu_panel)


func show_panel(panel: Control) -> void:
	main_menu_panel.visible = false
	panel.visible = true


func _on_map_editor_pressed() -> void:
	var game_manager: GameManager = get_node("../../GameManager")
	game_manager.change_state(EnumMappings.GameState.MAP_EDITOR)


func _on_quit_pressed() -> void:
	get_tree().quit()

extends Control
class_name MainMenueManager

@onready var main_menu_panel: Control = $MainMenuePanel

@onready var play_button: Button = $MainMenuePanel/VBoxContainer/PlayButton
@onready var quit_button: Button = $MainMenuePanel/VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	show_panel(main_menu_panel)


func show_panel(panel: Control) -> void:
	main_menu_panel.visible = false
	panel.visible = true


func _on_play_pressed() -> void:
	var game_manager: GameManager = get_node("../../GameManager")
	game_manager.change_state(EnumMappings.GameState.PVE)


func _on_quit_pressed() -> void:
	get_tree().quit()

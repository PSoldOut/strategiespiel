extends Control
class_name TilePalette

signal tile_type_changed(tile_type: int)
signal selected_height_action_changed(action: float)
signal map_name_changed(map_name: String)
signal save_requested
signal reset_requested

@onready var option_button: OptionButton = $VBoxContainer/OptionButton
@onready var height_button: OptionButton = $VBoxContainer/OptionButton2
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var map_name: LineEdit = $VBoxContainer/LineEdit
var selected_tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE
var selected_height_action: float = 0.0
var selected_map_name: String = "Map001"

func _ready() -> void:
	option_button.clear()
	option_button.add_item(tile_type_to_string(EnumMappings.TileTypeEnums.STANDAD_TILE), EnumMappings.TileTypeEnums.STANDAD_TILE)
	option_button.add_item(tile_type_to_string(EnumMappings.TileTypeEnums.GOLD_TILE), EnumMappings.TileTypeEnums.GOLD_TILE)
	option_button.add_item(tile_type_to_string(EnumMappings.TileTypeEnums.PLAYER_TILE), EnumMappings.TileTypeEnums.PLAYER_TILE)
	_update_label()
	setup_height_options()
	setup_map_name()

	option_button.item_selected.connect(_on_item_selected)



func setup_height_options():
	height_button.clear()

	height_button.add_item("0", 0)
	height_button.add_item("+0.5", 1)
	height_button.add_item("-0.5", 2)

	height_button.item_selected.connect(_on_height_selected)
	selected_height_action_changed.emit(selected_height_action)

	

func setup_map_name() -> void:
	if map_name == null:
		return

	map_name.text = selected_map_name

	if not map_name.text_submitted.is_connected(_on_map_name_submitted):
		map_name.text_submitted.connect(_on_map_name_submitted)

	if not map_name.focus_exited.is_connected(_on_map_name_focus_exited):
		map_name.focus_exited.connect(_on_map_name_focus_exited)


func _on_map_name_submitted(new_text: String) -> void:
	_apply_map_name(new_text)


func _on_map_name_focus_exited() -> void:
	_apply_map_name(map_name.text)


func _apply_map_name(new_text: String) -> void:
	var clean_name := new_text.strip_edges()
	if clean_name.is_empty():
		clean_name = "Map001"

	if clean_name == selected_map_name:
		map_name.text = selected_map_name
		return

	selected_map_name = clean_name
	map_name.text = selected_map_name
	map_name_changed.emit(selected_map_name)



func _on_height_selected(index: int):
	match index:
		0: selected_height_action = 0.0
		1: selected_height_action = 0.5
		2: selected_height_action = -0.5

	print("HEIGHT ACTION:", selected_height_action)
	selected_height_action_changed.emit(selected_height_action)

func _on_item_selected(index: int) -> void:
	selected_tile_type = option_button.get_item_id(index)
	_update_label()
	tile_type_changed.emit(selected_tile_type)


func _update_label() -> void:
	info_label.text = "Selected: " + tile_type_to_string(selected_tile_type)


func tile_type_to_string(tile_type: int) -> String:
	match tile_type:
		EnumMappings.TileTypeEnums.STANDAD_TILE:
			return "StandardTile"
		EnumMappings.TileTypeEnums.GOLD_TILE:
			return "GoldTile"
		EnumMappings.TileTypeEnums.PLAYER_TILE:
			return "PlayerTile"
		_:
			return "Unknown"


func _on_save_button_pressed() -> void:
	save_requested.emit()


func _on_reset_button_pressed() -> void:
	reset_requested.emit()

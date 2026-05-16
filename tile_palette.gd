extends Control
class_name TilePalette

signal tile_type_changed(tile_type: int)

@onready var option_button: OptionButton = $VBoxContainer/OptionButton
@onready var height_button: OptionButton = $VBoxContainer/OptionButton2
@onready var info_label: Label = $VBoxContainer/InfoLabel
var selected_tile_type: int = EnumMappings.TileTypeEnums.STANDAD_TILE
var selected_height_action: float = 0.0

func _ready() -> void:
	option_button.clear()
	option_button.add_item(tile_type_to_string(EnumMappings.TileTypeEnums.STANDAD_TILE), EnumMappings.TileTypeEnums.STANDAD_TILE)
	option_button.add_item(tile_type_to_string(EnumMappings.TileTypeEnums.GOLD_TILE), EnumMappings.TileTypeEnums.GOLD_TILE)
	_update_label()
	setup_height_options()

	option_button.item_selected.connect(_on_item_selected)



func setup_height_options():
	height_button.clear()

	height_button.add_item("0", 0)
	height_button.add_item("+0.5", 1)
	height_button.add_item("-0.5", 2)

	height_button.item_selected.connect(_on_height_selected)

	


func _on_height_selected(index: int):
	match index:
		0: selected_height_action = 0.0
		1: selected_height_action = 0.5
		2: selected_height_action = -0.5

	print("HEIGHT ACTION:", selected_height_action)

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
		_:
			return "Unknown"

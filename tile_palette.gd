extends Control
class_name TilePalette

signal tile_type_changed(tile_type: int)
signal save_requested

@onready var option_button: OptionButton = $VBoxContainer/OptionButton
@onready var height_button: OptionButton = $VBoxContainer/OptionButton2
@onready var direction_button: OptionButton = $VBoxContainer/OptionButton3
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var save_button: Button = $VBoxContainer/SaveButton

var selected_tile_type: int = EnumMappings.TileEnums.STANDAD_TILE
var selected_height: float = 0.0
var selected_direction: int = 0

func _ready() -> void:
	option_button.clear()
	option_button.add_item(tile_type_to_string(EnumMappings.TileEnums.STANDAD_TILE), EnumMappings.TileEnums.STANDAD_TILE)
	option_button.add_item(tile_type_to_string(EnumMappings.TileEnums.GOLD_TILE), EnumMappings.TileEnums.GOLD_TILE)
	option_button.add_item(tile_type_to_string(EnumMappings.TileEnums.RAMP_TILE), EnumMappings.TileEnums.RAMP_TILE)
	_update_label()
	setup_height_options()
	setup_Direction_options()

	option_button.item_selected.connect(_on_item_selected)
	save_button.pressed.connect(_on_save_pressed)


func setup_Direction_options():
	direction_button.clear()

	direction_button.add_item("North", 0)
	direction_button.add_item("East", 1)
	direction_button.add_item("West", 2)
	direction_button.add_item("South", 3)

	direction_button.item_selected.connect(_on_direction_selected)
	
func setup_height_options():
	height_button.clear()

	height_button.add_item("0", 0)
	height_button.add_item("+0.5", 1)
	height_button.add_item("+1", 2)
	height_button.add_item("+1.5", 3)
	height_button.add_item("+2", 4)

	height_button.add_item("-0.5", 5)
	height_button.add_item("-1", 6)
	height_button.add_item("-1.5", 7)
	height_button.add_item("-2", 8)

	height_button.item_selected.connect(_on_height_selected)


func _on_direction_selected(index: int):
	match index:
		0: selected_direction = 0
		1: selected_direction = 1
		2: selected_direction = 2
		3: selected_direction = 3
		
	print("DIRECTION SELECTED:", selected_direction)
	


func _on_height_selected(index: int):
	match index:
		0: selected_height = 0.0
		1: selected_height = 0.5
		2: selected_height = 1.0
		3: selected_height = 1.5
		4: selected_height = 2.0
		5: selected_height = -0.5
		6: selected_height = -1.0
		7: selected_height = -1.5
		8: selected_height = -2.0

	print("HEIGHT SELECTED:", selected_height)

func _on_item_selected(index: int) -> void:
	selected_tile_type = option_button.get_item_id(index)
	_update_label()
	tile_type_changed.emit(selected_tile_type)


func _on_save_pressed() -> void:
	save_requested.emit()


func _update_label() -> void:
	info_label.text = "Selected: " + tile_type_to_string(selected_tile_type)


func tile_type_to_string(tile_type: int) -> String:
	match tile_type:
		EnumMappings.TileEnums.STANDAD_TILE:
			return "StandardTile"
		EnumMappings.TileEnums.GOLD_TILE:
			return "GoldTile"
		EnumMappings.TileEnums.RAMP_TILE:
			return "RampTile"
		_:
			return "Unknown"

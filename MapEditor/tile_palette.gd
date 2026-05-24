extends Control
class_name TilePalette

signal selected_ground_type_changed(tile_type: int)
signal selected_height_action_changed(action: float)
signal selected_building_type_changed(building_type: int)
signal selected_player_changed(player: int)
signal selected_orientation_changed(orientation: int)
signal map_name_changed(map_name: String)
signal save_requested
signal reset_requested 

@export var rtsbuildsystem: RTSBuildSystem
var building = preload("res://ResourceSystem/Resource.tscn")

@onready var ground_label: Label = $VBoxContainer/GroundLabel
@onready var ground_option_button: OptionButton = $VBoxContainer/GroundOptionButton

@onready var height_label: Label = $VBoxContainer/HeightLabel
@onready var height_option_button: OptionButton = $VBoxContainer/HeightOptionButton

@onready var building_label: Label = $VBoxContainer/BuildingLabel
@onready var building_option_button: OptionButton = $VBoxContainer/BuildingOptionButton

# Optional nodes. These may not exist yet in your scene.
@onready var player_label: Label = $VBoxContainer.get_node_or_null("PlayerLabel") as Label
@onready var player_option_button: OptionButton = $VBoxContainer.get_node_or_null("PlayerOptionButton") as OptionButton
@onready var orientation_label: Label = $VBoxContainer.get_node_or_null("OrientationLabel") as Label
@onready var orientation_option_button: OptionButton = $VBoxContainer.get_node_or_null("OrientationOptionButton") as OptionButton

@onready var map_name: LineEdit = $VBoxContainer/LineEdit

var selected_ground_type: int = EnumMappings.GroundType.GRAS_TILE
var selected_height_action: int = 0.0
var selected_building_type: int = EnumMappings.BuildingType.NONE
var selected_player: int = EnumMappings.Player.WORLD
var selected_orientation: int = EnumMappings.Orientation.NORTH
var selected_map_name: String = "Map001"


func _ready() -> void:
	setup_ground_options()
	setup_height_options()
	setup_building_options()
	setup_player_options()
	setup_orientation_options()
	setup_map_name()


# -------------------------------------------------------------------------
# Generic OptionButton builders
# -------------------------------------------------------------------------

func _setup_enum_option_button(
		option_button: OptionButton,
		enum_values: Dictionary,
		selected_value: int,
		text_builder: Callable,
		callback: Callable
) -> void:
	if option_button == null:
		return

	option_button.clear()

	var keys := enum_values.keys()
	keys.sort()

	for key in keys:
		var value: int = enum_values[key]
		var text: String = text_builder.call(value)
		option_button.add_item(text, value)

		if value == selected_value:
			option_button.select(option_button.item_count - 1)

	if not option_button.item_selected.is_connected(callback):
		option_button.item_selected.connect(callback)


func _setup_value_option_button(
		option_button: OptionButton,
		values: Array,
		callback: Callable
) -> void:
	if option_button == null:
		return

	option_button.clear()

	for entry in values:
		var text: String = entry.get("text", "")
		var id: int = entry.get("id", 0)
		option_button.add_item(text, id)

	if not option_button.item_selected.is_connected(callback):
		option_button.item_selected.connect(callback)


func _get_selected_item_id(option_button: OptionButton, index: int) -> int:
	if option_button == null:
		return -1

	if index < 0 or index >= option_button.item_count:
		return -1

	return option_button.get_item_id(index)


# -------------------------------------------------------------------------
# Setup
# -------------------------------------------------------------------------

func setup_ground_options() -> void:
	_setup_enum_option_button(
		ground_option_button,
		EnumMappings.GroundType,
		selected_ground_type,
		Callable(self, "ground_tile_type_to_string"),
		Callable(self, "_on_ground_selected")
	)

	_update_ground_label()
	selected_ground_type_changed.emit(selected_ground_type)


func setup_height_options() -> void:
	_setup_value_option_button(
		height_option_button,
		[
			{"text": "0", "id": 0},
			{"text": "+0.5", "id": 1},
			{"text": "-0.5", "id": 2},
		],
		Callable(self, "_on_height_selected")
	)

	_update_height_label("0.0")
	selected_height_action_changed.emit(selected_height_action)


func setup_building_options() -> void:
	_setup_enum_option_button(
		building_option_button,
		EnumMappings.BuildingType,
		selected_building_type,
		Callable(self, "building_type_to_string"),
		Callable(self, "_on_building_selected")
	)

	_update_building_label()
	selected_building_type_changed.emit(selected_building_type)


func setup_player_options() -> void:
	_setup_enum_option_button(
		player_option_button,
		EnumMappings.Player,
		selected_player,
		Callable(self, "player_to_string"),
		Callable(self, "_on_player_selected")
	)

	_update_player_label()
	selected_player_changed.emit(selected_player)


func setup_orientation_options() -> void:
	_setup_enum_option_button(
		orientation_option_button,
		EnumMappings.Orientation,
		selected_orientation,
		Callable(self, "orientation_to_string"),
		Callable(self, "_on_orientation_selected")
	)

	_update_orientation_label()
	selected_orientation_changed.emit(selected_orientation)


func setup_map_name() -> void:
	if map_name == null:
		return

	map_name.text = selected_map_name

	if not map_name.text_submitted.is_connected(_on_map_name_submitted):
		map_name.text_submitted.connect(_on_map_name_submitted)

	if not map_name.focus_exited.is_connected(_on_map_name_focus_exited):
		map_name.focus_exited.connect(_on_map_name_focus_exited)


# -------------------------------------------------------------------------
# Selection callbacks
# -------------------------------------------------------------------------

func _on_ground_selected(index: int) -> void:
	var value := _get_selected_item_id(ground_option_button, index)
	if value == -1:
		return

	selected_ground_type = value
	_update_ground_label()
	selected_ground_type_changed.emit(selected_ground_type)


func _on_height_selected(index: int) -> void:
	match index:
		0:
			selected_height_action = EnumMappings.HeightMapping.HEIGHT_NONE
			_update_height_label("0.0")
		1:
			selected_height_action = EnumMappings.HeightMapping.HEIGHT_UP
			_update_height_label("0.5")
		2:
			selected_height_action = EnumMappings.HeightMapping.HEIGHT_DOWN
			_update_height_label("-0.5")
		_:
			selected_height_action = EnumMappings.HeightMapping.HEIGHT_NONE
			_update_height_label("0.0")

	selected_height_action_changed.emit(selected_height_action)


func _on_building_selected(index: int) -> void:
	var value := _get_selected_item_id(building_option_button, index)
	if value == -1:
		return

	selected_building_type = value
	if value != EnumMappings.BuildingType.NONE:
		rtsbuildsystem.active = true
		rtsbuildsystem.set_preview_object(building)
	else:
		rtsbuildsystem.active = false
		rtsbuildsystem.unset_preview_object()
	_update_building_label()
	selected_building_type_changed.emit(selected_building_type)


func _on_player_selected(index: int) -> void:
	var value := _get_selected_item_id(player_option_button, index)
	if value == -1:
		return

	selected_player = value
	_update_player_label()
	selected_player_changed.emit(selected_player)


func _on_orientation_selected(index: int) -> void:
	var value := _get_selected_item_id(orientation_option_button, index)
	if value == -1:
		return

	selected_orientation = value
	_update_orientation_label()
	selected_orientation_changed.emit(selected_orientation)


# -------------------------------------------------------------------------
# Labels
# -------------------------------------------------------------------------

func _update_ground_label() -> void:
	if ground_label != null:
		ground_label.text = "Ground: " + ground_tile_type_to_string(selected_ground_type)


func _update_height_label(value: String) -> void:
	if height_label != null:
		height_label.text = "Height: " + value


func _update_building_label() -> void:
	if building_label != null:
		building_label.text = "Building: " + building_type_to_string(selected_building_type)


func _update_player_label() -> void:
	if player_label != null:
		player_label.text = "Player: " + player_to_string(selected_player)


func _update_orientation_label() -> void:
	if orientation_label != null:
		orientation_label.text = "Orientation: " + orientation_to_string(selected_orientation)


# -------------------------------------------------------------------------
# Map name
# -------------------------------------------------------------------------

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


# -------------------------------------------------------------------------
# Enum text mappings
# -------------------------------------------------------------------------

func ground_tile_type_to_string(tile_type: int) -> String:
	match tile_type:
		EnumMappings.GroundType.GRAS_TILE:
			return "Gras"
		EnumMappings.GroundType.SAND_TILE:
			return "Sand"
		_:
			return "Unknown Tile: " + str(tile_type)


func building_type_to_string(building_type: int) -> String:
	match building_type:
		EnumMappings.BuildingType.NONE:
			return "None"
		EnumMappings.BuildingType.GOLD:
			return "Gold"
		EnumMappings.BuildingType.STONE:
			return "Stone"
		EnumMappings.BuildingType.HOUSE:
			return "House"
		_:
			return "Unknown Building: " + str(building_type)


func player_to_string(player_enum: int) -> String:
	match player_enum:
		EnumMappings.Player.WORLD:
			return "World"
		EnumMappings.Player.PLAYER_1:
			return "Player 1"
		EnumMappings.Player.PLAYER_2:
			return "Player 2"
		EnumMappings.Player.PLAYER_3:
			return "Player 3"
		EnumMappings.Player.PLAYER_4:
			return "Player 4"
		_:
			return "Unknown Player: " + str(player_enum)


func orientation_to_string(orientation: int) -> String:
	match orientation:
		EnumMappings.Orientation.NORTH:
			return "North"
		EnumMappings.Orientation.EAST:
			return "East"
		EnumMappings.Orientation.SOUTH:
			return "South"
		EnumMappings.Orientation.WEST:
			return "West"
		_:
			return "Unknown Orientation: " + str(orientation)


# -------------------------------------------------------------------------
# Buttons
# -------------------------------------------------------------------------

func _on_save_button_pressed() -> void:
	save_requested.emit()


func _on_reset_button_pressed() -> void:
	reset_requested.emit()

class_name MapBakerConfig
extends Resource
## Configures standalone terrain mesh and collision baking.

@export var tile_size: float = 2.0
@export var build_collision := true
@export var show_tile_lines := true
@export var tile_line_color := Color.BLACK
@export var tile_line_height_offset: float = 0.01
@export var default_terrain_type: int = 0
@export var default_terrain_color := Color(0.5, 0.5, 0.5)
@export var edge_base_height: float = 0.0
@export var terrain_colors: Dictionary[int, Color] = {}


func get_terrain_color(terrain_type: int) -> Color:
	return terrain_colors.get(terrain_type, default_terrain_color)

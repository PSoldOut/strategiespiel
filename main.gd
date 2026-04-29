extends Node3D

@onready var map_spawner: MapSpawner = $MapSpawner
@onready var tile_palette: TilePalette = $CanvasLayer/TilePalette


func _ready() -> void:
	tile_palette.save_requested.connect(_on_save_requested)


func _process(_delta: float) -> void:
	map_spawner.set_palette(
		tile_palette.selected_tile_type,
		tile_palette.selected_height,
		tile_palette.selected_direction
	)


func _on_save_requested() -> void:
	map_spawner.save_map_to_json()
	print("Map saved")

extends Node3D

@onready var map_spawner: MapSpawner = $MapSpawner
@onready var tile_palette: TilePalette = $CanvasLayer/TilePalette
@export var camera: Camera3D
var hovered_tile: RTSMapTile = null
var selected_tile_type: int = EnumMappings.GroundType.GRAS_TILE
var selected_height_action: float = 0.0


func _process(_delta: float) -> void:
	_update_hovered_tile()

func _ready() -> void:
	tile_palette.save_requested.connect(_on_save_requested)
	tile_palette.reset_requested.connect(_on_reset_requested)

func _on_save_requested() -> void:
	map_spawner.save_map()
	print("Map saved")

func _on_reset_requested() -> void:
	map_spawner.reset_map()

func _update_hovered_tile() -> void:

	var tile := _get_tile_under_mouse()
	_set_hovered_tile(tile)

func _get_tile_under_mouse() -> RTSMapTile:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 2000.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var result := get_world_3d().direct_space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var collider: Object = result.get("collider")
	if collider == null:
		return null

	return _extract_tile(collider)

func _extract_tile(collider: Object) -> RTSMapTile:
	if collider is RTSMapTile:
		return collider as RTSMapTile

	if collider is Node:
		var node := collider as Node

		if node.has_meta("tile_ref"):
			var ref = node.get_meta("tile_ref")
			if ref is RTSMapTile:
				return ref

		var current: Node = node
		while current != null:
			if current is RTSMapTile:
				return current as RTSMapTile
			current = current.get_parent()

	return null

func _set_hovered_tile(tile: RTSMapTile) -> void:
	if hovered_tile == tile:
		return

	if hovered_tile != null:
		hovered_tile.set_hovered(false)

	hovered_tile = tile

	if hovered_tile != null:
		hovered_tile.set_hovered(true)

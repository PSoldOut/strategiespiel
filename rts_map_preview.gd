extends Node2D
class_name RTSMapPreview

@export var cell_size: int = 6
@export var padding: int = 20

var map_data: Array = []
var draw_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	draw_offset = Vector2(padding, padding)


func set_map(new_map: Array) -> void:
	map_data = duplicate_map(new_map)
	queue_redraw()


func get_map_pixel_size() -> Vector2:
	if map_data.is_empty():
		return Vector2.ZERO
	return Vector2(map_data[0].size() * cell_size, map_data.size() * cell_size)


func fit_camera_to_map() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or map_data.is_empty():
		return

	var map_pixel_size := get_map_pixel_size()
	var map_center := draw_offset + map_pixel_size * 0.5
	cam.position = map_center

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return


func _draw() -> void:
	if map_data.is_empty():
		return

	for y in range(map_data.size()):
		for x in range(map_data[y].size()):
			var cell: int = map_data[y][x]
			var color: Color = get_cell_color(cell)

			var px := draw_offset.x + x * cell_size
			var py := draw_offset.y + y * cell_size

			draw_rect(Rect2(px, py, cell_size, cell_size), color, true)
			draw_rect(Rect2(px, py, cell_size, cell_size), Color(0, 0, 0, 0.15), false, 1.0)


func get_cell_color(cell: int) -> Color:
	match cell:
		0:
			return Color(0.15, 0.15, 0.15)
		1:
			return Color(0.2, 0.6, 1.0)
		2:
			return Color(0.2, 1.0, 0.2)
		3:
			return Color(1.0, 0.85, 0.2)
		4:
			return Color(0.45, 0.45, 0.45)
		_:
			return Color(1, 0, 1)


func duplicate_map(source: Array) -> Array:
	var result: Array = []
	for row in source:
		result.append(row.duplicate())
	return result

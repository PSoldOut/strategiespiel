extends Control
class_name MinimapCameraMarker

## Draws the ground footprint of the RTS camera over the minimap.
##
## The minimap stays orthographic. The perspective shape comes from projecting
## the four screen-corner rays of the RTS camera onto the ground plane.

## Camera whose visible ground area should be displayed in the minimap.
@export var view_camera: Camera3D
## Orthographic camera that renders the minimap.
@export var minimap_camera: Camera3D
## SubViewport that owns [member minimap_camera].
@export var minimap_viewport: SubViewport

## World-space height of the ground plane the footprint is projected onto.
@export var ground_y := 0.0

@export var fill_color := Color(1.0, 1.0, 1.0, 0.15)
@export var outline_color := Color(1.0, 1.0, 1.0, 0.95)
@export_range(0.1, 20.0, 0.1) var outline_width := 1.5

## Maximum distance used when a ray points at or above the horizon.
@export var max_ray_distance := 4096.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(view_camera) or not is_instance_valid(minimap_camera):
		return
	if not is_instance_valid(minimap_viewport):
		return

	var world_quad := _get_ground_quad()
	if world_quad.size() != 4:
		return

	var viewport_size := Vector2(
		minimap_viewport.size.x,
		minimap_viewport.size.y,
	)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var polygon := PackedVector2Array()
	for world_point in world_quad:
		var minimap_point := minimap_camera.unproject_position(world_point)
		polygon.append(Vector2(
			minimap_point.x / viewport_size.x * size.x,
			minimap_point.y / viewport_size.y * size.y,
		))

	var clip_rect := PackedVector2Array([
		Vector2.ZERO,
		Vector2(size.x, 0.0),
		size,
		Vector2(0.0, size.y),
	])

	for clipped in Geometry2D.intersect_polygons(polygon, clip_rect):
		if clipped.size() < 3:
			continue

		draw_colored_polygon(clipped, fill_color)

		var outline := clipped.duplicate()
		outline.append(clipped[0])
		draw_polyline(outline, outline_color, outline_width, true)


func _get_ground_quad() -> PackedVector3Array:
	var screen_size := view_camera.get_viewport().get_visible_rect().size
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return PackedVector3Array()

	var screen_corners: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(screen_size.x, 0.0),
		screen_size,
		Vector2(0.0, screen_size.y),
	]

	var quad := PackedVector3Array()
	for screen_point in screen_corners:
		var origin := view_camera.project_ray_origin(screen_point)
		var direction := view_camera.project_ray_normal(screen_point)
		quad.append(_ray_to_ground(origin, direction))
	return quad


func _ray_to_ground(origin: Vector3, direction: Vector3) -> Vector3:
	if absf(direction.y) > 0.0001:
		var distance := (ground_y - origin.y) / direction.y
		if distance > 0.0:
			return origin + direction * minf(distance, max_ray_distance)

	# The ray points at or above the horizon, so it never reaches the ground.
	# Use a far point in the horizontal view direction and let the minimap
	# clipping take care of the rest.
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() < 0.0001:
		return Vector3(origin.x, ground_y, origin.z)
	horizontal = horizontal.normalized()
	return Vector3(origin.x, ground_y, origin.z) + horizontal * max_ray_distance

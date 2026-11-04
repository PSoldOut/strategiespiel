class_name BuildingPlacementController
extends Node
## Bridges player input and map validation to PlacePickupBuildingSystem.

signal selected_building_changed(building_id: StringName)

const ACTION_PLACE := &"building_place"
const ACTION_PICKUP := &"building_pickup"
const ACTION_ROTATE := &"building_rotate"
const ACTION_CANCEL := &"building_cancel"
const META_GRID_ORIGIN := &"building_grid_origin"
const META_FOOTPRINT := &"building_footprint"
const METHOD_ACTIVATE := &"activate"
const RAY_LENGTH := 10_000.0

@export var placement_system: PlacePickupBuildingSystem
@export var map_spawner: MapSpawner
@export var camera: Camera3D
@export_flags_3d_physics var collision_mask: int = 1

var enabled := true
var _rotation_steps := 0
var _candidate_origin := Vector2i.ZERO
var _candidate_footprint := Vector2i.ONE
var _candidate_valid := false
var _occupied_cells: Dictionary[Vector2i, StringName] = {}
var _preview_suspended := false


func _ready() -> void:
	if placement_system == null:
		return
	placement_system.selection_changed.connect(_on_selection_changed)
	placement_system.building_placed.connect(_on_building_placed)
	placement_system.building_picked_up.connect(_on_building_picked_up)
	call_deferred("_begin_selected_preview")


func _process(_delta: float) -> void:
	if not enabled or placement_system == null or map_spawner == null or camera == null:
		return
	if placement_system.selected_building_id.is_empty():
		return
	if _preview_suspended:
		return
	var hit := _raycast_mouse()
	if hit.is_empty():
		_candidate_valid = false
		return

	_candidate_origin = map_spawner.world_position_to_grid(hit["position"])
	_candidate_footprint = _get_rotated_footprint()
	_candidate_valid = _can_place(_candidate_origin, _candidate_footprint)
	var transform := _get_building_transform(_candidate_origin, _candidate_footprint)
	if not placement_system.has_active_preview():
		placement_system.begin_preview()
	placement_system.update_preview(transform, _candidate_valid)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or placement_system == null:
		return
	if event.is_action_pressed(ACTION_ROTATE):
		_preview_suspended = false
		_rotation_steps = posmod(_rotation_steps + 1, 4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_CANCEL):
		_preview_suspended = true
		placement_system.cancel_preview()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_PLACE):
		if _preview_suspended:
			_preview_suspended = false
			placement_system.begin_preview()
		elif _candidate_valid:
			placement_system.confirm_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(ACTION_PICKUP):
		_pickup_under_mouse()
		get_viewport().set_input_as_handled()


func _begin_selected_preview() -> void:
	if placement_system == null or placement_system.selected_building_id.is_empty():
		return
	_preview_suspended = false
	_rotation_steps = 0
	placement_system.begin_preview()
	selected_building_changed.emit(placement_system.selected_building_id)


func _get_rotated_footprint() -> Vector2i:
	var definition := placement_system.get_definition(placement_system.selected_building_id)
	if definition == null:
		return Vector2i.ONE
	return (
		Vector2i(definition.footprint.y, definition.footprint.x)
		if _rotation_steps % 2 == 1
		else definition.footprint
	)


func _can_place(origin: Vector2i, footprint: Vector2i) -> bool:
	var reference_height := NAN
	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			if not map_spawner.is_valid_grid_pos(x, y):
				return false
			if _occupied_cells.has(Vector2i(x, y)):
				return false
			var height := map_spawner.get_tile_height(Vector2i(x, y))
			if is_nan(reference_height):
				reference_height = height
			elif not is_equal_approx(reference_height, height):
				return false
	return true


func _get_building_transform(origin: Vector2i, footprint: Vector2i) -> Transform3D:
	var height := map_spawner.get_tile_height(origin)
	var center := Vector3(
		(float(origin.x) + float(footprint.x) * 0.5) * MapSpawner.TILE_SIZE,
		height,
		(float(origin.y) + float(footprint.y) * 0.5) * MapSpawner.TILE_SIZE,
	)
	var basis := Basis(Vector3.UP, float(_rotation_steps) * TAU / 4.0)
	return Transform3D(basis, center)


func _raycast_mouse() -> Dictionary:
	var mouse_position := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_position)
	var to := from + camera.project_ray_normal(mouse_position) * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return map_spawner.get_world_3d().direct_space_state.intersect_ray(query)


func _pickup_under_mouse() -> void:
	var hit := _raycast_mouse()
	if hit.is_empty():
		return
	var node := hit.get("collider") as Node
	while node != null and not node.has_meta(PlacePickupBuildingSystem.META_BUILDING_ID):
		node = node.get_parent()
	if node is Node3D:
		placement_system.pickup_building(node as Node3D)


func _on_selection_changed(_building_id: StringName) -> void:
	call_deferred("_begin_selected_preview")


func _on_building_placed(building_id: StringName, building: Node3D) -> void:
	building.set_meta(META_GRID_ORIGIN, _candidate_origin)
	building.set_meta(META_FOOTPRINT, _candidate_footprint)
	if building.has_method(METHOD_ACTIVATE):
		building.call(METHOD_ACTIVATE)
	if building.has_signal(&"destroyed"):
		building.connect(&"destroyed", _on_building_destroyed)
	for y in range(_candidate_origin.y, _candidate_origin.y + _candidate_footprint.y):
		for x in range(_candidate_origin.x, _candidate_origin.x + _candidate_footprint.x):
			_occupied_cells[Vector2i(x, y)] = building_id


func _on_building_picked_up(building_id: StringName) -> void:
	var cells_to_remove: Array[Vector2i] = []
	for cell in _occupied_cells:
		if _occupied_cells[cell] == building_id:
			cells_to_remove.append(cell)
	for cell in cells_to_remove:
		_occupied_cells.erase(cell)


func _on_building_destroyed(building: Node3D) -> void:
	if is_instance_valid(building):
		placement_system.pickup_building(building)

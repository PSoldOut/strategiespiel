class_name PlacePickupBuildingSystem
extends Node3D
## Manages unique buildings that alternate between held and placed states.

signal selection_changed(building_id: StringName)
signal preview_started(building_id: StringName, preview: Node3D)
signal preview_updated(building_id: StringName, placement_valid: bool)
signal preview_cancelled(building_id: StringName)
signal building_placed(building_id: StringName, building: Node3D)
signal building_picked_up(building_id: StringName)
signal building_state_changed(building_id: StringName, placement_state: int)
signal operation_failed(building_id: StringName, reason: String)

const META_BUILDING_ID := &"place_pickup_building_id"

@export var config: PlacePickupBuildingConfig = PlacePickupBuildingConfig.new()
@export var building_parent: Node3D
@export var definitions: Array[PlaceableBuildingDefinition] = []

var selected_building_id: StringName

var _definitions_by_id: Dictionary[StringName, PlaceableBuildingDefinition] = {}
var _states_by_id: Dictionary[StringName, PlaceableBuildingState] = {}
var _placed_nodes: Dictionary[StringName, Node3D] = {}
var _preview: Node3D
var _preview_building_id: StringName
var _preview_is_valid := false
var _preview_material := StandardMaterial3D.new()


func _ready() -> void:
	initialize(definitions)


func _unhandled_input(event: InputEvent) -> void:
	if config == null or not config.input_enabled:
		return
	if _is_action_pressed(event, config.select_next_action):
		select_next_held()
		get_viewport().set_input_as_handled()
	elif _is_action_pressed(event, config.select_previous_action):
		select_previous_held()
		get_viewport().set_input_as_handled()


func initialize(new_definitions: Array[PlaceableBuildingDefinition]) -> bool:
	cancel_preview()
	_clear_placed_nodes()
	_definitions_by_id.clear()
	_states_by_id.clear()
	definitions = new_definitions

	for definition in definitions:
		if definition == null or not definition.is_valid():
			return _fail(&"", "Every building definition must be valid.")
		if _definitions_by_id.has(definition.building_id):
			return _fail(definition.building_id, "Building IDs must be unique.")

		_definitions_by_id[definition.building_id] = definition
		var state := PlaceableBuildingState.new()
		state.building_id = definition.building_id
		_states_by_id[definition.building_id] = state

	_select_first_held()
	return true


func select_building(building_id: StringName) -> bool:
	var state := _states_by_id.get(building_id) as PlaceableBuildingState
	if state == null or not state.is_held():
		return _fail(building_id, "Only held buildings can be selected.")
	if selected_building_id == building_id:
		return true

	cancel_preview()
	selected_building_id = building_id
	selection_changed.emit(building_id)
	return true


func select_next_held() -> StringName:
	return _select_relative_held(1)


func select_previous_held() -> StringName:
	return _select_relative_held(-1)


func get_held_building_ids() -> Array[StringName]:
	var held_ids: Array[StringName] = []
	for definition in definitions:
		if definition == null:
			continue
		var state := _states_by_id.get(definition.building_id) as PlaceableBuildingState
		if state != null and state.is_held():
			held_ids.append(definition.building_id)
	return held_ids


func get_definition(building_id: StringName) -> PlaceableBuildingDefinition:
	return _definitions_by_id.get(building_id) as PlaceableBuildingDefinition


func get_state(building_id: StringName) -> PlaceableBuildingState:
	var state := _states_by_id.get(building_id) as PlaceableBuildingState
	return state.duplicate(true) as PlaceableBuildingState if state != null else null


func get_placed_node(building_id: StringName) -> Node3D:
	return _placed_nodes.get(building_id) as Node3D


func has_active_preview() -> bool:
	return is_instance_valid(_preview)


func begin_preview(building_id: StringName = &"") -> Node3D:
	_ensure_config()
	var requested_id := building_id if not building_id.is_empty() else selected_building_id
	var state := _states_by_id.get(requested_id) as PlaceableBuildingState
	var definition := get_definition(requested_id)
	if state == null or not state.is_held() or definition == null:
		_fail(requested_id, "A held building with a valid definition is required.")
		return null

	cancel_preview()
	var instance := definition.scene.instantiate()
	if not instance is Node3D:
		instance.free()
		_fail(requested_id, "Building scene root must inherit Node3D.")
		return null

	_preview = instance as Node3D
	_preview_building_id = requested_id
	_preview_is_valid = false
	_get_building_parent().add_child(_preview)
	_prepare_preview(_preview)
	_set_preview_color(config.invalid_preview_color)
	preview_started.emit(requested_id, _preview)
	return _preview


func update_preview(preview_transform: Transform3D, placement_valid: bool) -> bool:
	if not is_instance_valid(_preview):
		return _fail(selected_building_id, "No active building preview exists.")

	_preview.global_transform = preview_transform
	_preview_is_valid = placement_valid
	var color := config.valid_preview_color if placement_valid else config.invalid_preview_color
	_set_preview_color(color)
	preview_updated.emit(_preview_building_id, placement_valid)
	return true


func confirm_placement() -> Node3D:
	if not is_instance_valid(_preview) or not _preview_is_valid:
		_fail(_preview_building_id, "The active preview is not valid for placement.")
		return null

	var building_id := _preview_building_id
	var definition := get_definition(building_id)
	var final_transform := _preview.global_transform
	var instance := definition.scene.instantiate()
	if not instance is Node3D:
		instance.free()
		_fail(building_id, "Building scene root must inherit Node3D.")
		return null

	var building := instance as Node3D
	_get_building_parent().add_child(building)
	building.global_transform = final_transform
	building.set_meta(META_BUILDING_ID, building_id)
	_clear_preview()

	var state := _states_by_id[building_id] as PlaceableBuildingState
	state.placement_state = PlaceableBuildingState.PlacementState.PLACED
	state.placed_transform = final_transform
	_placed_nodes[building_id] = building
	building_placed.emit(building_id, building)
	building_state_changed.emit(building_id, state.placement_state)
	_select_first_held()
	return building


func cancel_preview() -> void:
	if not is_instance_valid(_preview):
		_preview = null
		_preview_building_id = &""
		_preview_is_valid = false
		return

	var building_id := _preview_building_id
	_clear_preview()
	preview_cancelled.emit(building_id)


func pickup_building(building: Node3D) -> bool:
	if not is_instance_valid(building) or not building.has_meta(META_BUILDING_ID):
		return _fail(&"", "Node is not a managed placed building.")
	return pickup_building_by_id(StringName(building.get_meta(META_BUILDING_ID)))


func pickup_building_by_id(building_id: StringName) -> bool:
	var state := _states_by_id.get(building_id) as PlaceableBuildingState
	var building := _placed_nodes.get(building_id) as Node3D
	if state == null or not state.is_placed() or not is_instance_valid(building):
		return _fail(building_id, "Building is not currently placed.")

	_placed_nodes.erase(building_id)
	building.queue_free()
	state.placement_state = PlaceableBuildingState.PlacementState.HELD
	selected_building_id = building_id
	building_picked_up.emit(building_id)
	building_state_changed.emit(building_id, state.placement_state)
	selection_changed.emit(building_id)
	return true


func create_save_state() -> PlacePickupBuildingSave:
	var save := PlacePickupBuildingSave.new()
	save.selected_building_id = selected_building_id
	for definition in definitions:
		if definition == null:
			continue
		var state := _states_by_id.get(definition.building_id) as PlaceableBuildingState
		if state != null:
			save.building_states.append(state.duplicate(true) as PlaceableBuildingState)
	return save


func restore_save_state(save: PlacePickupBuildingSave) -> bool:
	if save == null:
		return _fail(&"", "Save state must not be null.")

	cancel_preview()
	_clear_placed_nodes()
	for state in _states_by_id.values():
		state.placement_state = PlaceableBuildingState.PlacementState.HELD
		state.placed_transform = Transform3D.IDENTITY

	for saved_state in save.building_states:
		if saved_state == null or not _definitions_by_id.has(saved_state.building_id):
			continue
		var state := _states_by_id[saved_state.building_id] as PlaceableBuildingState
		state.placement_state = (
			PlaceableBuildingState.PlacementState.PLACED
			if saved_state.placement_state == PlaceableBuildingState.PlacementState.PLACED
			else PlaceableBuildingState.PlacementState.HELD
		)
		state.placed_transform = saved_state.placed_transform
		if state.is_placed() and not _spawn_saved_building(state):
			state.placement_state = PlaceableBuildingState.PlacementState.HELD

	if not save.selected_building_id.is_empty() and _is_held(save.selected_building_id):
		selected_building_id = save.selected_building_id
		selection_changed.emit(selected_building_id)
	else:
		_select_first_held()
	return true


func _select_relative_held(direction: int) -> StringName:
	var held_ids := get_held_building_ids()
	if held_ids.is_empty():
		cancel_preview()
		selected_building_id = &""
		selection_changed.emit(selected_building_id)
		return selected_building_id

	var current_index := held_ids.find(selected_building_id)
	var next_index := 0 if current_index < 0 else posmod(current_index + direction, held_ids.size())
	select_building(held_ids[next_index])
	return selected_building_id


func _select_first_held() -> void:
	var held_ids := get_held_building_ids()
	var next_selection := held_ids[0] if not held_ids.is_empty() else StringName()
	if selected_building_id == next_selection:
		return
	selected_building_id = next_selection
	selection_changed.emit(selected_building_id)


func _spawn_saved_building(state: PlaceableBuildingState) -> bool:
	var definition := get_definition(state.building_id)
	var instance := definition.scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return _fail(state.building_id, "Saved building scene root must inherit Node3D.")

	var building := instance as Node3D
	_get_building_parent().add_child(building)
	building.global_transform = state.placed_transform
	building.set_meta(META_BUILDING_ID, state.building_id)
	_placed_nodes[state.building_id] = building
	return true


func _prepare_preview(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
		collision_object.input_ray_pickable = false
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = _preview_material
	for child in node.get_children():
		_prepare_preview(child)


func _set_preview_color(color: Color) -> void:
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.albedo_color = color


func _clear_preview() -> void:
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	_preview_building_id = &""
	_preview_is_valid = false


func _clear_placed_nodes() -> void:
	for building in _placed_nodes.values():
		if is_instance_valid(building):
			building.free()
	_placed_nodes.clear()


func _get_building_parent() -> Node3D:
	return building_parent if is_instance_valid(building_parent) else self


func _ensure_config() -> void:
	if config == null:
		config = PlacePickupBuildingConfig.new()


func _is_held(building_id: StringName) -> bool:
	var state := _states_by_id.get(building_id) as PlaceableBuildingState
	return state != null and state.is_held()


func _is_action_pressed(event: InputEvent, action: StringName) -> bool:
	return not action.is_empty() and InputMap.has_action(action) and event.is_action_pressed(action)


func _fail(building_id: StringName, reason: String) -> bool:
	push_error("PlacePickupBuildingSystem: %s Building: %s" % [reason, building_id])
	operation_failed.emit(building_id, reason)
	return false

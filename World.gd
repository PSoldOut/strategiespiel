extends Node3D

const AGENT_SCENE := preload("res://Agent.tscn")

enum states {
	BUILD,
	SELECT
}

var state = states.SELECT

## Buildings that can be constructed and the prerequisites between them.
@export var building_catalog: BuildingCatalog

## Abstract tags that are currently unlocked. Buildings can require them via
## [member BuildingDefinition.unlocked_by].
var unlocked_tags: Array[StringName] = []

var _active_team := "blue"
var _can_show_build_options := false

@onready var navRegion: NavigationRegion3D = $NavigationRegion3D
@onready var ui: RTSUserInterface = $UI
@onready var drag_selection: DragSelection = $DragSelection
@onready var build_system: RTSBuildSystem = $RTSBuildSystem


func _ready() -> void:
	navRegion.bake_navigation_mesh()

	var arr: Array = []
	for _i in range(200):
		var agent = AGENT_SCENE.instantiate()
		agent.position = Vector3(randf_range(0, 256), 1, randf_range(0, 256))
		$Agents.add_child(agent)
		arr.append(agent)
	drag_selection.register_units(arr)

	_refresh_build_options()


func _unhandled_input(event: InputEvent) -> void:
	if state != states.BUILD:
		return
	var cancel := false
	if event is InputEventKey:
		cancel = event.pressed and event.keycode == KEY_ESCAPE
	elif event is InputEventMouseButton:
		cancel = event.pressed and event.button_index == MOUSE_BUTTON_RIGHT
	if cancel:
		_cancel_build()
		get_viewport().set_input_as_handled()


func _cancel_build() -> void:
	if build_system.preview_object != null:
		build_system.unset_preview_object()
	build_system.active = false
	drag_selection.active = true
	state = states.SELECT
	_refresh_build_options()


## Unlocks an abstract tag that buildings can require.
func unlock_tag(tag: StringName) -> void:
	if unlocked_tags.has(tag):
		return
	unlocked_tags.append(tag)
	_refresh_build_options()


func lock_tag(tag: StringName) -> void:
	if unlocked_tags.has(tag):
		unlocked_tags.erase(tag)
		_refresh_build_options()


func _refresh_build_options() -> void:
	if not _can_show_build_options or building_catalog == null:
		ui.clear_build_options()
		return

	var owned := _owned_building_ids(_active_team)
	var available := building_catalog.get_available(owned, unlocked_tags)

	var entries: Array[UIEntry] = []
	for definition in available:
		entries.append(UIEntry.make(
			definition.id,
			definition.label,
			definition.icon,
			false,
			definition.description,
		))
	ui.set_build_options(entries)


func _owned_building_ids(team: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for child in $NavigationRegion3D/Buildings.get_children():
		var building := child as Building
		if building == null or not building.is_constructed():
			continue
		var selection_unit = building.get_node_or_null("SelectionUnit")
		if selection_unit == null or selection_unit.team != team:
			continue
		ids.append(StringName(str(building.type)))
	return ids


func _can_build(unit) -> bool:
	var abilities = unit.get("abilities")
	if abilities == null:
		return false
	return "build" in abilities


func _describe_units(units: Array) -> Array[String]:
	var counts := {}
	var order: Array[String] = []
	for selection_unit in units:
		var unit = selection_unit.get_unit()
		var type_value = unit.get("type")
		var type := str(type_value) if type_value != null else "unit"
		if not counts.has(type):
			counts[type] = 0
			order.append(type)
		counts[type] += 1

	var lines: Array[String] = []
	for type in order:
		lines.append("%dx %s" % [counts[type], type])
	return lines


func _describe_abilities(unit) -> Array[UIEntry]:
	var entries: Array[UIEntry] = []
	var abilities = unit.get("abilities")
	if abilities == null:
		return entries
	for ability in abilities:
		var id := StringName(str(ability))
		entries.append(UIEntry.make(id, String(id)))
	return entries


func _on_drag_selection_selected(units: Array) -> void:
	if units.is_empty():
		_active_team = "blue"
		_can_show_build_options = false
		ui.clear_units()
		ui.clear_abilities()
		ui.clear_build_options()
		return

	var first: SelectionUnit = units[0]
	var unit = first.get_unit()
	_active_team = first.team
	_can_show_build_options = _can_build(unit)

	ui.set_units(_describe_units(units))
	ui.set_abilities(_describe_abilities(unit))

	if _can_show_build_options:
		_refresh_build_options()
	else:
		ui.clear_build_options()


func _on_ui_build_option_pressed(id: StringName) -> void:
	if building_catalog == null:
		return
	var definition := building_catalog.get_definition(id)
	if definition == null or definition.scene == null:
		return

	drag_selection.active = false
	build_system.active = true
	build_system.set_preview_object(definition.scene)
	state = states.BUILD


func _on_ui_ability_pressed(id: StringName) -> void:
	## Abilities are still abstract. Forward the id to selected units that
	## implement [code]use_ability[/code].
	for selection_unit in drag_selection.current_selected:
		var unit = selection_unit.get_unit()
		if unit.has_method("use_ability"):
			unit.use_ability(id)


func _on_ui_mouse_entered_panel() -> void:
	build_system.active = false
	drag_selection.active = false


func _on_ui_mouse_exited_panel() -> void:
	if state == states.BUILD:
		build_system.active = true
	elif state == states.SELECT:
		drag_selection.active = true


func _on_drag_selection_move_command(positions: Array) -> void:
	for i in range(drag_selection.current_selected.size()):
		var unit = drag_selection.current_selected[i]
		if is_instance_valid(unit):
			unit.get_unit().navigation_agent_3d.set_target_position(positions[i])
			unit.get_unit().state = unit.get_unit().State.MOVE_STRAIGHT


func _on_drag_selection_interact_command(target: SelectionUnit) -> void:
	if drag_selection.current_selected.size() > 0 and target.team == drag_selection.current_selected[0].team:
		for i in range(drag_selection.current_selected.size()):
			var unit = drag_selection.current_selected[i]
			if is_instance_valid(unit):
				unit.get_unit().target = target.get_unit()
				unit.get_unit().state = unit.get_unit().State.CHASE_TO_INTERACT
	else:
		for i in range(drag_selection.current_selected.size()):
			var unit = drag_selection.current_selected[i]
			if is_instance_valid(unit):
				unit.get_unit().target = target.get_unit()
				unit.get_unit().state = unit.get_unit().State.CHASE


func _on_building_construction_completed() -> void:
	_refresh_build_options()


func _on_rts_build_system_building_set_command(position: Vector3, scene: Variant) -> void:
	var obj = scene.instantiate()
	obj.global_position = position
	$NavigationRegion3D/Buildings.add_child(obj)
	if obj.has_signal("construction_completed"):
		obj.construction_completed.connect(_on_building_construction_completed)
	drag_selection.register_unit(obj)
	navRegion.bake_navigation_mesh()
	state = states.SELECT
	build_system.unset_preview_object()
	obj.place()
	build_system.active = false
	for su: SelectionUnit in drag_selection.current_selected:
		var unit = su.get_unit()
		unit.target = obj
		unit.state = unit.State.CHASE_TO_INTERACT
	await get_tree().process_frame
	drag_selection.active = true
	_refresh_build_options()

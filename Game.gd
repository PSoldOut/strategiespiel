extends Node3D

const AGENT_SCENE := preload("res://Agent.tscn")
const ICON_UNIT := preload("res://icons/pionir.svg")
const ICON_BUILDING := preload("res://icons/building.svg")

## Resources shown in the HUD, in this order.
const HUD_RESOURCES := [
	{ "id": &"wood", "label": "Holz" },
	{ "id": &"stone", "label": "Stein" },
]

## Display names for units that are not described by the building catalog.
const UNIT_LABELS := {
	&"pionir": "Pionier",
}

## Seconds between refreshes of the selection panel.
const SELECTION_REFRESH_INTERVAL := 0.2

## Resources every team starts with: [code]{resource_id: amount}[/code].
const START_RESOURCES := {
	&"wood": 500,
	&"stone": 200,
}

## Resource deposits placed at the start of the game as a rectangular grid.
## Each entry needs scene, origin (x, z), count, columns and spacing.
const RESOURCE_SPAWNS := [
	{
		"scene": preload("res://wood.tscn"),
		"origin": Vector2(120.0, 120.0),
		"columns": 6,
		"count": 24,
		"spacing": 5.0,
	},
	{
		"scene": preload("res://stone.tscn"),
		"origin": Vector2(168.0, 120.0),
		"columns": 4,
		"count": 16,
		"spacing": 5.0,
	},
]

enum states {
	BUILD,
	SELECT
}

var state = states.SELECT

## Buildings that can be constructed and the prerequisites between them.
@export var building_catalog: BuildingCatalog

@export_group("Map")
## Optional scene exported by the map generator. When assigned, the built-in
## ground is replaced by the generated terrain and the placed buildings and
## resources become part of the running game.
@export var generated_map: PackedScene
@export_group("")

## Abstract tags that are currently unlocked. Buildings can require them via
## [member BuildingDefinition.unlocked_by].
var unlocked_tags: Array[StringName] = []

## Team whose resources are shown in the HUD.
@export var player_team : String = "blue"

## Resource amounts per team and resource id: [code]{team: {id: amount}}[/code].
var _resource_totals : Dictionary = {}

## Selection units currently shown in the UI, including inspected enemies.
var _display_selection : Array = []
var _selection_signature := ""
var _selection_refresh := 0.0

var _active_team := "blue"
var _can_show_build_options := false

## Building the player chose in the build menu but has not placed yet.
var _pending_build : BuildingDefinition = null

## True while the world runs on a scene exported by the map generator.
var _using_generated_map := false
## Number of agents that came from the generated map instead of the fallback spawn.
var _generated_agent_count := 0
## Playable area in world coordinates, used for spawning and camera limits.
var _map_rect := Rect2(0.0, 0.0, 512.0, 512.0)

@onready var navRegion: NavigationRegion3D = $Map/NavigationRegion3D
@onready var buildings: Node3D = $Map/NavigationRegion3D/Buildings
@onready var agents: Node3D = $Map/Agents
@onready var resources: Node3D = $Map/Resources
@onready var ui: RTSUserInterface = $UI
@onready var drag_selection: DragSelection = $DragSelection
@onready var build_system: RTSBuildSystem = $RTSBuildSystem


func _ready() -> void:
	_load_generated_map()
	ui.set_minimap_bounds(_map_rect)
	navRegion.bake_navigation_mesh()

	_resource_totals[player_team] = START_RESOURCES.duplicate()
	_refresh_build_options()
	_refresh_resources()

	# Spawning happens after a physics tick so raycasts against a generated
	# terrain already hit its collision shape.
	await get_tree().physics_frame
	if _generated_agent_count == 0:
		_spawn_agents()
	if not _using_generated_map:
		_spawn_resources()


## Replaces the built-in ground with a scene exported by the map generator.
## The generated scene is instanced below the [NavigationRegion3D] so its
## terrain collision is part of the navigation-visible geometry.
func _load_generated_map() -> void:
	if generated_map == null:
		return

	var map_instance := generated_map.instantiate() as Node3D
	if map_instance == null:
		return

	_using_generated_map = true

	var old_ground := navRegion.get_node_or_null("Ground")
	if old_ground != null:
		navRegion.remove_child(old_ground)
		old_ground.queue_free()

	map_instance.name = "GeneratedMap"
	_prepare_generated_agents(map_instance)
	navRegion.add_child(map_instance)
	_configure_generated_terrain_layers(map_instance)

	var terrain := map_instance.get_node_or_null("Terrain") as Node3D
	_map_rect = _generated_map_rect(map_instance, terrain)
	_configure_camera_for_map()

	var objects := map_instance.get_node_or_null("Objects")
	if objects != null:
		_adopt_generated_objects(objects)


func _generated_map_rect(map_instance: Node3D, terrain: Node3D) -> Rect2:
	if terrain != null:
		var mesh_instance := terrain.get_node_or_null("TerrainMesh") as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			var world_box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			return Rect2(
				world_box.position.x,
				world_box.position.z,
				world_box.size.x,
				world_box.size.z,
			)

	var width := int(map_instance.get_meta("map_width", 0))
	var depth := int(map_instance.get_meta("map_depth", 0))
	var cell_size := float(map_instance.get_meta("map_cell_size", 2.0))
	if width > 0 and depth > 0:
		return Rect2(0.0, 0.0, float(width) * cell_size, float(depth) * cell_size)
	return _map_rect


## Generated terrain only uses the default render layer. Like the built-in
## ground it also has to be visible to the minimap camera.
func _configure_generated_terrain_layers(map_instance: Node3D) -> void:
	var terrain := map_instance.get_node_or_null("Terrain") as Node3D
	if terrain == null:
		return
	for node in terrain.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null:
			mesh_instance.layers |= ui.minimap_cull_mask


func _configure_camera_for_map() -> void:
	var camera := get_node_or_null("RTSCamera") as RTSCamera
	if camera == null:
		return

	var center := _map_rect.get_center()
	var span := maxf(_map_rect.size.x, _map_rect.size.y)
	camera.set_bounds(_map_rect)
	camera.global_position.x = center.x
	camera.global_position.z = center.y
	camera.global_position.y = clampf(span * 0.4, 24.0, camera.max_zoom_out)
	camera.new_zoom = camera.global_position.y


## Gives generated agents the player's team before they enter the tree, so
## their [code]_ready[/code] does not assign a random team.
func _prepare_generated_agents(map_instance: Node) -> void:
	for node in map_instance.find_children("*", "CharacterBody3D", true, false):
		var agent := _generated_agent_value(node)
		if agent != null:
			agent.set("team", player_team)


## Identifies a generated agent without depending on the map generator knowing
## the game's Agent class.
func _generated_agent_value(node: Node) -> CharacterBody3D:
	var body := node as CharacterBody3D
	if body == null or not body.has_method("update_team_color"):
		return null
	if body.get("team") == null:
		return null
	return body


## Moves generated buildings into the building folder, resources into the
## resource folder and agents into the agent folder, preserving world transforms.
func _adopt_generated_objects(objects: Node) -> void:
	for category in objects.get_children():
		for entry in category.get_children():
			if entry is Building:
				_adopt_generated_building(entry as Building)
			elif entry is ResourceNode:
				(entry as ResourceNode).reparent(resources, true)
			else:
				var agent := _generated_agent_value(entry)
				if agent != null:
					_adopt_generated_agent(agent)

		if category.get_child_count() == 0:
			objects.remove_child(category)
			category.queue_free()


func _adopt_generated_agent(agent: CharacterBody3D) -> void:
	agent.reparent(agents, true)
	agent.set("team", player_team)
	var selection_unit := agent.get_node_or_null("DragSelectionUnit")
	if selection_unit != null and selection_unit.has_method("set_team"):
		selection_unit.call("set_team", player_team)
	if agent.has_method("update_team_color"):
		agent.call("update_team_color")
	_generated_agent_count += 1
	if not drag_selection.units.has(agent):
		drag_selection.register_unit(agent)


func _adopt_generated_building(building: Building) -> void:
	building.reparent(buildings, true)
	building.constructed = true
	building.build_progress = building.build_end

	var finished_mesh := building.get_node_or_null("MeshInstance3D") as Node3D
	if finished_mesh != null:
		finished_mesh.visible = true
	var construction_mesh := building.get_node_or_null("ContructionMesh") as Node3D
	if construction_mesh != null:
		construction_mesh.visible = false

	var completed_handler := Callable(self, "_on_building_construction_completed")
	if building.has_signal(&"construction_completed") \
			and not building.is_connected(&"construction_completed", completed_handler):
		building.connect(&"construction_completed", completed_handler)

	var deposit_handler := Callable(self, "_on_resource_deposited")
	if building.has_signal(&"resource_deposited") \
			and not building.is_connected(&"resource_deposited", deposit_handler):
		building.connect(&"resource_deposited", deposit_handler)

	if not drag_selection.units.has(building):
		drag_selection.register_unit(building)


func _spawn_agents() -> void:
	var spawn_rect := Rect2(0.0, 0.0, 256.0, 256.0)
	if _using_generated_map:
		spawn_rect = _map_rect.grow(-3.0)
		if spawn_rect.size.x <= 0.0 or spawn_rect.size.y <= 0.0:
			spawn_rect = _map_rect

	var arr: Array = []
	for _i in range(200):
		var agent = AGENT_SCENE.instantiate()
		var x := randf_range(spawn_rect.position.x, spawn_rect.end.x)
		var z := randf_range(spawn_rect.position.y, spawn_rect.end.y)
		var y := 1.0
		if _using_generated_map:
			y = _ground_height_at(x, z) + 1.0
		agent.position = Vector3(x, y, z)
		agents.add_child(agent)
		arr.append(agent)
	drag_selection.register_units(arr)


func _ground_height_at(x: float, z: float) -> float:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(x, 200.0, z),
		Vector3(x, -50.0, z),
	)
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	var position_value: Variant = hit.get("position", Vector3.ZERO)
	if position_value is Vector3:
		return (position_value as Vector3).y
	return 0.0


func _process(delta: float) -> void:
	if _display_selection.is_empty():
		return
	_selection_refresh += delta
	if _selection_refresh < SELECTION_REFRESH_INTERVAL:
		return
	_selection_refresh = 0.0
	_update_selection_panel()


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
	_pending_build = null
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
			not can_afford(definition.costs, _active_team),
			_build_tooltip(definition, _active_team),
		))
	ui.set_build_options(entries)


## Tooltip for a build option: description, resource costs and, when the
## resources are missing, a hint why the entry is disabled.
func _build_tooltip(definition: BuildingDefinition, team: String) -> String:
	var parts: Array[String] = []
	if not definition.description.is_empty():
		parts.append(definition.description)

	var costs: Array[String] = []
	var ordered: Array[StringName] = []
	for hud_entry in HUD_RESOURCES:
		var hud_id: StringName = hud_entry["id"]
		if definition.costs.has(hud_id):
			ordered.append(hud_id)
	for resource_id in definition.costs:
		var id := StringName(str(resource_id))
		if not ordered.has(id):
			ordered.append(id)
	for id in ordered:
		costs.append("%d %s" % [
			int(definition.costs[id]),
			_resource_label(id),
		])
	if costs.is_empty():
		parts.append("Kosten: keine")
	else:
		parts.append("Kosten: " + ", ".join(PackedStringArray(costs)))

	if not can_afford(definition.costs, team):
		parts.append("Nicht genug Ressourcen")
	return "\n".join(PackedStringArray(parts))


## Returns true when [param team] has enough resources for [param costs].
func can_afford(costs: Dictionary, team: String = "") -> bool:
	var target_team: String = team if not team.is_empty() else player_team
	for resource_id in costs:
		var id := StringName(str(resource_id))
		if get_resource_amount(id, target_team) < int(costs[resource_id]):
			return false
	return true


## Deducts [param costs] from the total of [param team]. Returns false and
## changes nothing when the team cannot afford them.
func spend_resources(costs: Dictionary, team: String = "") -> bool:
	if not can_afford(costs, team):
		return false
	var target_team: String = team if not team.is_empty() else player_team
	var totals: Dictionary = _resource_totals.get(target_team, {})
	for resource_id in costs:
		var id := StringName(str(resource_id))
		totals[id] = int(totals.get(id, 0)) - int(costs[resource_id])
	_resource_totals[target_team] = totals
	_refresh_resources()
	return true


func _owned_building_ids(team: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for child in buildings.get_children():
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


func _describe_selection(units: Array) -> UISelection:
	var first = units[0].get_unit()
	var icon := _unit_icon(first)
	if units.size() == 1:
		return UISelection.make(_unit_display_name(first), icon, _unit_details(first))

	var counts := {}
	var order: Array[String] = []
	var carrying := 0
	var capacity := 0
	for selection_unit in units:
		var unit = selection_unit.get_unit()
		var label := _unit_display_name(unit)
		if not counts.has(label):
			counts[label] = 0
			order.append(label)
		counts[label] += 1
		var carry = unit.get("carry_amount")
		if carry != null:
			carrying += int(carry)
		var max_carry = unit.get("gather_capacity")
		if max_carry != null:
			capacity += int(max_carry)

	var details: Array[String] = []
	for label in order:
		details.append("%dx %s" % [counts[label], label])
	if capacity > 0:
		details.append("Trägt: %d / %d" % [carrying, capacity])
	return UISelection.make("%d Einheiten" % units.size(), icon, details)


func _unit_display_name(unit) -> String:
	if unit is ResourceNode:
		return _resource_label(unit.resource_id)
	if unit is Building:
		return _building_label(StringName(str(unit.type)))
	var type_value = unit.get("type")
	if type_value == null:
		return "Objekt"
	return _type_label(StringName(str(type_value)))


func _unit_icon(unit) -> Texture2D:
	var unit_icon = unit.get("icon")
	if unit_icon is Texture2D:
		return unit_icon
	if unit is Building:
		if building_catalog != null:
			var definition := building_catalog.get_definition(StringName(str(unit.type)))
			if definition != null and definition.icon != null:
				return definition.icon
		return ICON_BUILDING
	return ICON_UNIT


func _unit_details(unit) -> Array[String]:
	var details: Array[String] = []
	if unit is ResourceNode:
		details.append("Restmenge: %d" % unit.amount)
		return details
	if unit is Building:
		if unit.is_constructed():
			details.append("Fertig")
		else:
			details.append("Im Bau: %d %%" % unit.build_progress)
		return details

	var carry = unit.get("carry_amount")
	var max_carry = unit.get("gather_capacity")
	if carry != null and max_carry != null:
		var text := "Trägt: %d / %d" % [int(carry), int(max_carry)]
		var carry_type = unit.get("carry_type")
		if int(carry) > 0 and carry_type != null and not str(carry_type).is_empty():
			text += " " + _resource_label(StringName(str(carry_type)))
		details.append(text)
	return details


func _building_label(id: StringName) -> String:
	if building_catalog != null:
		var definition := building_catalog.get_definition(id)
		if definition != null and not definition.label.is_empty():
			return definition.label
	return String(id).capitalize()


func _type_label(id: StringName) -> String:
	if UNIT_LABELS.has(id):
		return str(UNIT_LABELS[id])
	return String(id).capitalize()


func _resource_label(resource_id: StringName) -> String:
	for definition in HUD_RESOURCES:
		if definition["id"] == resource_id:
			return str(definition["label"])
	return String(resource_id).capitalize()


## Refreshes the selection panel, for example while a pioneer is carrying
## resources or a deposit is being harvested.
func _update_selection_panel(force := false) -> void:
	var valid: Array = []
	for selection_unit in _display_selection:
		if is_instance_valid(selection_unit) and is_instance_valid(selection_unit.get_unit()):
			valid.append(selection_unit)
	_display_selection = valid

	if valid.is_empty():
		if not _selection_signature.is_empty():
			_selection_signature = ""
			ui.clear_selection()
		return

	var info := _describe_selection(valid)
	var signature := info.title + "|" + "|".join(PackedStringArray(info.details))
	if not force and signature == _selection_signature:
		return
	_selection_signature = signature
	ui.set_selection(info)


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
	_display_selection = units.duplicate()
	_selection_refresh = 0.0

	if units.is_empty():
		_active_team = player_team
		_can_show_build_options = false
		_selection_signature = ""
		ui.clear_selection()
		ui.clear_abilities()
		ui.clear_build_options()
		return

	var first: SelectionUnit = units[0]
	var unit = first.get_unit()
	var own := first.team == player_team
	_active_team = first.team if own else player_team
	_can_show_build_options = own and _can_build(unit)

	_update_selection_panel(true)
	if own:
		ui.set_abilities(_describe_abilities(unit))
	else:
		ui.clear_abilities()

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
	if not can_afford(definition.costs, _active_team):
		return

	_pending_build = definition
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


func _on_drag_selection_right_click(_position: Vector3, target) -> void:
	var resource_node := target as ResourceNode
	if resource_node == null:
		return
	for selection_unit in drag_selection.current_selected:
		var unit = selection_unit.get_unit()
		if unit.has_method("gather_from"):
			unit.gather_from(resource_node)


## Adds a delivered amount to the total of a team.
func deposit_resource(team: String, resource_type: StringName, amount: int) -> void:
	if amount <= 0:
		return
	var totals: Dictionary = _resource_totals.get(team, {})
	totals[resource_type] = int(totals.get(resource_type, 0)) + amount
	_resource_totals[team] = totals
	_refresh_resources()
	if team == _active_team:
		_refresh_build_options()


func get_resource_amount(resource_type: StringName, team: String = "") -> int:
	var target_team: String = team if not team.is_empty() else player_team
	var totals: Dictionary = _resource_totals.get(target_team, {})
	return int(totals.get(resource_type, 0))


func _on_resource_deposited(resource_type: StringName, amount: int, team: String) -> void:
	deposit_resource(team, resource_type, amount)


func _refresh_resources() -> void:
	var totals: Dictionary = _resource_totals.get(player_team, {})
	var entries: Array[UIResource] = []
	for definition in HUD_RESOURCES:
		var id: StringName = definition["id"]
		var label : String = str(definition["label"])
		entries.append(UIResource.make(id, label, int(totals.get(id, 0))))
	ui.set_resources(entries)


func _spawn_resources() -> void:
	await get_tree().physics_frame

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ignored: Array[RID] = []
	for agent in agents.get_children():
		if agent is CollisionObject3D:
			ignored.append((agent as CollisionObject3D).get_rid())

	for spawn in RESOURCE_SPAWNS:
		var scene: PackedScene = spawn["scene"]
		var origin: Vector2 = spawn["origin"]
		var columns: int = spawn["columns"]
		var count: int = spawn["count"]
		var spacing: float = spawn["spacing"]
		for index in range(count):
			var column := index % columns
			var row := index / columns
			var x := origin.x + float(column) * spacing
			var z := origin.y + float(row) * spacing
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, 200.0, z), Vector3(x, -50.0, z))
			query.collision_mask = 1
			query.exclude = ignored
			var hit: Dictionary = space.intersect_ray(query)
			var y := 0.0
			if not hit.is_empty():
				y = (hit["position"] as Vector3).y
			var node: Node3D = scene.instantiate()
			resources.add_child(node)
			node.global_position = Vector3(x, y, z)


func _on_building_construction_completed() -> void:
	_refresh_build_options()


func _on_rts_build_system_building_set_command(position: Vector3, scene: Variant) -> void:
	var definition := _pending_build
	_pending_build = null

	if definition != null and not spend_resources(definition.costs, _active_team):
		_cancel_build()
		return

	var obj = scene.instantiate()
	obj.global_position = position
	buildings.add_child(obj)
	if obj.has_signal("construction_completed"):
		obj.construction_completed.connect(_on_building_construction_completed)
	if obj.has_signal("resource_deposited"):
		obj.resource_deposited.connect(_on_resource_deposited)
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

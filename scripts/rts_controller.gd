extends Node

@export var camera_path: NodePath
@onready var cam: Camera3D = get_node(camera_path)
@onready var overlay: Control = $SelectionOverlay

var _drag_start := Vector2.ZERO
var _drag_end := Vector2.ZERO
var _dragging := false
var _selected: Array[Node] = []

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_dragging = true
			_drag_start = event.position
			_drag_end = event.position
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_dragging = false
			_select_units_in_rect(_make_drag_rect())
			overlay.queue_redraw()
	
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var hit := _raycast_ground(event.position)
			if hit.has("position"):
				_issue_move_commands(hit.position)
	
	elif event is InputEventMouseMotion and _dragging:
		_drag_end = event.position
		overlay.queue_redraw()

func _ready() -> void:
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_on_overlay_draw)

func _on_overlay_draw() -> void:
	if not _dragging:
		return
	var rect := _make_drag_rect()
	overlay.draw_rect(rect, Color(0.2, 0.8, 1.0, 0.18), true)
	overlay.draw_rect(rect, Color(0.2, 0.8, 1.0, 0.95), false, 2.0)

func _make_drag_rect() -> Rect2:
	var pos := Vector2(min(_drag_start.x, _drag_end.x), min(_drag_start.y, _drag_end.y))
	var size := Vector2(abs(_drag_end.x - _drag_start.x), abs(_drag_end.y - _drag_start.y))
	return Rect2(pos, size)

func _select_units_in_rect(rect: Rect2) -> void:
	for u in _selected:
		if is_instance_valid(u):
			u._set_selected(false)
	_selected.clear()
	
	var local_team_id := _get_local_team_id()
	
	for u in get_tree().get_nodes_in_group("selectable_units"):
		if not (u is Node3D):
			continue
		if int(u.get("team_id")) != local_team_id:
			continue
		var screen_pos := cam.unproject_position((u as Node3D).global_position)
		if rect.has_point(screen_pos):
			u._set_selected(true)
			_selected.append(u)

func _get_local_team_id() -> int:
	# In this project, host units are spawned as team 0.
	if multiplayer.is_server():
		return 0
	return multiplayer.get_unique_id()

func _issue_move_commands(target: Vector3) -> void:
	if _selected.is_empty():
		return
	var commands: Array = []	
	# Kleine Formation statt Stack auf genau einem Punkt
	var spacing := 1.8
	var cols := int(ceil(sqrt(_selected.size())))
	
	for i in _selected.size():
		var u := _selected[i]
		if not is_instance_valid(u):
			continue
			
		var row := i / cols
		var col := i % cols
		var offset := Vector3((col - cols * 0.5) * spacing, 0.0, row * spacing)
		var final_target := target + offset
		
		commands.append({
			"unit_name": u.name,
			"target": final_target
		})
		
	var pvp_runtime := _get_active_pvp_runtime()
	if pvp_runtime == null:
		for cmd in commands:
			var node := get_tree().current_scene.get_node_or_null(cmd["unit_name"])
			if node != null and node.has_method("set_move_target"):
				node.set_move_target(cmd["target"])
		return
	
	if multiplayer.is_server():
		pvp_runtime.request_move_command(commands)
	else:
		pvp_runtime.rpc_id(1, "request_move_command", commands)

func _get_active_pvp_runtime() -> Node:
	var runtimes := get_tree().get_nodes_in_group("pvp_runtime")
	if runtimes.is_empty():
		return null
	return runtimes[0]

func _raycast_ground(mouse_pos: Vector2) -> Dictionary:
	var origin := cam.project_ray_origin(mouse_pos)
	var dir := cam.project_ray_normal(mouse_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2000.0)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_viewport().get_world_3d().direct_space_state.intersect_ray(query)

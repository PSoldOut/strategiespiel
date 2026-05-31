extends Control
class_name DragSelection

@export var camera : Camera3D
@export var units : Array = []
@export var active : bool = true
@export var team : String = ""
@onready var timer : Timer = Timer.new()
var is_selecting = false
var select_start = Vector2.ZERO
var select_end = Vector2.ZERO
var selection_units : Array = []
var half : bool = false
var current_selected : Array = []

signal move_command(positions : Array)
signal interact_command(target : SelectionUnit)


func _prune_invalid_selection_units() -> void:
	var valid_units: Array = []
	for unit in selection_units:
		if is_instance_valid(unit):
			var parent = unit.get_parent()
			if is_instance_valid(parent) and not parent.is_queued_for_deletion():
				valid_units.append(unit)
	selection_units = valid_units

func _ready() -> void:
	if timer.get_parent() == null:
		add_child(timer)
	timer.wait_time = 0.2
	timer.one_shot = true
	timer.start()

func _process(delta):
	if is_selecting:
		queue_redraw()

func _draw():
	if is_selecting:
		var rect = Rect2(select_start, select_end - select_start).abs()
		
		draw_rect(rect, Color(0, 1, 0, 0.2), true)
		draw_rect(rect, Color(0, 1, 0, 1), false)
		
func set_units(arr : Array):
	units = arr
	selection_units.clear()
	current_selected.clear()
	half = false
	var su : SelectionUnit
	for unit in units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		var found: Array = unit.find_children("", "SelectionUnit", true, false)
		if found.is_empty():
			continue
		su = found[0]
		selection_units.append(su)
		if team == "":
			team = su.team
		su.set_drag_selection(self)
	_prune_invalid_selection_units()
		
		
func _input(event):
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			
			if event.pressed:
				is_selecting = true
				select_start = event.position
				select_end = event.position
				select_units()
			else:
				is_selecting = false
				queue_redraw()
				select_units()
				
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_prune_invalid_selection_units()
			var camera = get_viewport().get_camera_3d()
			var mouse_pos = get_viewport().get_mouse_position()
			var from = camera.project_ray_origin(mouse_pos)
			var to = from + camera.project_ray_normal(mouse_pos) * 10000
			var space_state = camera.get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(from, to)
			var result = space_state.intersect_ray(query)
			var pos
			if result:
				pos = result.position
				print(result["collider"])
				if result["collider"].find_children("", "SelectionUnit", true, false).size() >= 1:
					interact_command.emit(result["collider"].find_children("", "SelectionUnit", true, false)[0])
					return
				for unit : SelectionUnit in selection_units:
					if not is_instance_valid(unit):
						continue
					if team != unit.team and unit.global_transform.origin.distance_to(pos) < 1:
						interact_command.emit(unit)
						return
						
				#var positions = get_formation_positions(pos,units[0].position, units.size(), 1.4)
				var positions = get_formation_positions_simple(pos, current_selected.size(), 1.4)
				
				move_command.emit(positions)
			
	elif event is InputEventMouseMotion and is_selecting:
		select_end = event.position
		if timer.is_stopped():
			timer.start()
			select_units_half()
			
		
		
		
		

func get_formation_positions_simple(center: Vector3, unit_count: int, spacing: float) -> Array:
	var positions = []
	
	var cols = ceil(sqrt(unit_count))
	var rows = ceil(float(unit_count) / cols)
	
	var start_x = - (cols - 1) * spacing / 2.0
	var start_z = - (rows - 1) * spacing / 2.0
	
	var i = 0
	for row in range(rows):
		for col in range(cols):
			if i >= unit_count:
				break
			
			var offset = Vector3(
				start_x + col * spacing,
				0,
				start_z + row * spacing
			)
			
			positions.append(center + offset)
			i += 1
	
	return positions
		
		
		
		
		
func get_formation_positions(center: Vector3, target: Vector3, unit_count: int, spacing: float) -> Array:
	var positions = []
	
	var direction = (target - center).normalized()
	var right = direction.cross(Vector3.UP).normalized()
	
	var cols = ceil(sqrt(unit_count))
	var rows = ceil(float(unit_count) / cols)
	
	var i = 0
	for row in range(rows):
		for col in range(cols):
			if i >= unit_count:
				break
			
			var x_offset = (col - (cols - 1) / 2.0) * spacing
			var z_offset = (row - (rows - 1) / 2.0) * spacing
			
			var offset = right * x_offset + direction * z_offset
			
			positions.append(center + offset)
			i += 1
	
	return positions




		
		
		
	
func select_units_half():
	_prune_invalid_selection_units()
	if selection_units.is_empty():
		return
	current_selected = []
	var rect = Rect2(select_start, select_end - select_start).abs()
	var camera = get_viewport().get_camera_3d()
	if half:
		for i in range(selection_units.size()/2):
			var unit = selection_units[i]
			if not is_instance_valid(unit):
				continue
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			if rect.has_point(screen_pos):
				unit.select()
				current_selected.append(unit)
			else:
				unit.deselect()
		half=!half
				
	else:
		for i in range(selection_units.size()/2, selection_units.size()):
			var unit : SelectionUnit = selection_units[i]
			if not is_instance_valid(unit):
				continue
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			
			if rect.has_point(screen_pos):
				unit.select()
				current_selected.append(unit)
			else:
				unit.deselect()
		half = !half
		



func select_units():
	_prune_invalid_selection_units()
	if selection_units.is_empty():
		return
	current_selected = []
	var rect = Rect2(select_start, select_end - select_start).abs()
	var camera = get_viewport().get_camera_3d()

	# Mindestgröße prüfen
	var is_click = rect.size.length() < 5.0

	

	for unit : SelectionUnit in selection_units:
		if not is_instance_valid(unit):
			continue
		if unit.team != team:
			continue
		var screen_pos = camera.unproject_position(unit.global_transform.origin)
		if is_click:
			# Abstand Maus -> Einheit prüfen
			if screen_pos.distance_to(select_start) < 15.0:
				unit.select()
				current_selected.append(unit)
			else:
				unit.deselect()
		else:
			# Normale Box-Auswahl
			if rect.has_point(screen_pos):
				unit.select()
				current_selected.append(unit)
			else:
				unit.deselect()
		

extends Control
class_name DragSelection
var is_selecting = false
var select_start = Vector2.ZERO
var select_end = Vector2.ZERO
@onready var camera : Camera3D = $"../Camera3D"
@export var units : Array = []
var selection_units : Array = []
var half : bool = false
@onready var timer : Timer = Timer.new()


func _ready() -> void:
	timer.wait_time = 0.2
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
	for unit in units:
		selection_units.append(unit.find_children("", "SelectionUnit", true, false)[0])
		
		
func _input(event):
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
			
			var units : Array
			for unit in get_tree().get_nodes_in_group("units"):
				if unit.selected:
					units.append(unit)
			#var positions = get_formation_positions(pos,units[0].position, units.size(), 1.4)
			var positions = get_formation_positions_simple(pos, units.size(), 1.4)
			
			for i in range(units.size()):
				var unit = units[i]
				unit.navigation_agent_3d.set_target_position(positions[i])
			
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
	if selection_units.is_empty():
		return
	var rect = Rect2(select_start, select_end - select_start).abs()
	var camera = get_viewport().get_camera_3d()
	if half:
		for i in range(selection_units.size()/2):
			var unit = selection_units[i]
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			
			if rect.has_point(screen_pos):
				unit.select()
			else:
				unit.deselect()
		half=!half
				
	else:
		for i in range(selection_units.size()/2, selection_units.size()):
			var unit = selection_units[i]
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			
			if rect.has_point(screen_pos):
				unit.select()
			else:
				unit.deselect()
		half = !half
		



func select_units():
	var rect = Rect2(select_start, select_end - select_start).abs()
	var camera = get_viewport().get_camera_3d()

	# Mindestgröße prüfen
	var is_click = rect.size.length() < 5.0

	if selection_units.is_empty():
		return

	for unit in selection_units:
		var screen_pos = camera.unproject_position(unit.global_transform.origin)
		if is_click:
			# Abstand Maus -> Einheit prüfen
			if screen_pos.distance_to(select_start) < 15.0:
				
				unit.select()
			else:
				unit.deselect()
		else:
			# Normale Box-Auswahl
			if rect.has_point(screen_pos):
				unit.select()
			else:
				unit.deselect()
		

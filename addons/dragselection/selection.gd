extends Control
class_name DragSelection

##die Kamera die von dem Spiel verwendet wird.
@export var camera : Camera3D
##Die DragSelection kann aktiviert und deaktiviert werden
@export var active : bool = true
##Das Team das ausgewählt und gesteuert werden kann
@export var team : String = ""
##Die Farbe des Auswahlrahmens
@export var stroke_color : Color = Color(0, 1, 0, 0.2)
##Die Dicke des Auswahlrahmens
@export var stroke_width : float = 1.0
##Die Farbe der Auswahlfläche
@export var fill_color : Color = Color(0.787, 0.813, 1.0, 1.0)
##Wenn die Agenten eine Kollisionsshape haben kann diese auch für die Auswahl verwendet werden
@export var use_collision_shapes : bool = false
##Das interval in dem die Auswahlbox aktualisiert wird
@export var update_time : float = 0.2
@onready var timer : Timer = Timer.new()

var is_selecting = false
var select_start = Vector2.ZERO
var select_end = Vector2.ZERO
var selection_units : Array = []
var half : bool = false
var current_selected : Array = []
##Die Einheiten die im Spiel anklickbar sind (auch die gegnerischen Einheiten und Gebäude)
var units : Array = []

var selection_area : Area3D
var collision_shape : CollisionShape3D

signal move_command(positions : Array)
signal interact_command(target : SelectionUnit)
signal left_click(pos : Vector3, obj)
signal right_click(pos : Vector3, obj)

func _ready() -> void:
	if use_collision_shapes:
		selection_area = Area3D.new()
		collision_shape = CollisionShape3D.new()
		self.add_child(selection_area)
		selection_area.add_child(collision_shape)
	self.add_child(timer)
	timer.wait_time = update_time
	timer.one_shot = true
	timer.start()
	

func _physics_process(delta):
	if is_selecting:
		queue_redraw()
		if timer.time_left == 0.0:
			timer.start()
			if use_collision_shapes:
				select_units_by_collision()
			else:
				select_units_by_rect()

func _draw():
	if is_selecting:
		var rect = Rect2(select_start, select_end - select_start).abs()
		draw_rect(rect, stroke_color, true)
		draw_rect(rect, fill_color, false, stroke_width)
		
		
func register_units(arr : Array):
	for unit in arr:
		register_unit(unit)


func register_unit(unit):
	var su : SelectionUnit
	if unit is SelectionUnit:
		su = unit
	else:
		su = unit.find_children("", "SelectionUnit", true, false)[0]
		selection_units.append(su)
		if team == "":
			team = su.team
		su.set_drag_selection(self)
	units.append(su.get_unit())


func unregister_unit(unit):
	if unit is not SelectionUnit:
		unit = unit.find_children("", "SelectionUnit", true, false)[0]
	selection_units.erase(unit)
	units.erase(unit.get_unit())
	current_selected.erase(unit)


func _input(event):
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_selecting = true
				select_start = event.position
				select_end = event.position
				if use_collision_shapes:
					select_unit_by_collision()
				else:
					select_unit_by_distance()
			else:
				is_selecting = false
				queue_redraw()
				
				
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
				if result["collider"].find_children("", "SelectionUnit", true, false).size() >= 1:
					interact_command.emit(result["collider"].find_children("", "SelectionUnit", true, false)[0])
					right_click.emit(pos, result["collider"].find_children("", "SelectionUnit", true, false)[0])
					return
				for unit : SelectionUnit in selection_units:
					if team != unit.team and unit.global_transform.origin.distance_to(pos) < 1:
						interact_command.emit(unit)
						right_click.emit(pos, unit.get_unit())
						return
						
				#var positions = get_formation_positions(pos,units[0].position, units.size(), 1.4)
				var positions = get_formation_positions_simple(pos, current_selected.size(), 1.4)
				
				move_command.emit(positions)
			
	elif event is InputEventMouseMotion and is_selecting:
		select_end = event.position
		
			
		
		
		
		

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




		
		
		
	
func select_units_half_by_rect():
	if selection_units.is_empty():
		return
	var rect = Rect2(select_start, select_end - select_start).abs()
	if rect.size.length() < 5.0:
		return
	var camera = get_viewport().get_camera_3d()
	if half:
		for i in range(selection_units.size()/2):
			var unit = selection_units[i]
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			if rect.has_point(screen_pos):
				if not current_selected.has(unit):
					unit.select()
					current_selected.append(unit)
			else:
				unit.deselect()
				current_selected.erase(unit)
		half=!half
				
	else:
		for i in range(selection_units.size()/2, selection_units.size()):
			var unit : SelectionUnit = selection_units[i]
			var screen_pos = camera.unproject_position(unit.global_transform.origin)
			
			if rect.has_point(screen_pos):
				if not current_selected.has(unit):
					unit.select()
					current_selected.append(unit)
			else:
				unit.deselect()
				current_selected.erase(unit)
		half = !half
		


func select_units_by_collision():
	var rect = Rect2(select_start, select_end - select_start).abs()
	if rect.size.length() < 5.0:
		return
	update_selection_shape(camera, rect)
	await get_tree().physics_frame
	var units = selection_area.get_overlapping_bodies()
	for unit in current_selected:
		unit.deselect()
	current_selected = []
	for unit in units:
		if unit.find_children("", "SelectionUnit", true, false).size() > 0:
			var su : SelectionUnit = unit.find_children("", "SelectionUnit", true, false)[0]
			if su.team == self.team:
				current_selected.append(su)
				su.select()



func select_units_by_rect():
	var rect = Rect2(select_start, select_end - select_start).abs()
	# Mindestgröße prüfen
	if rect.size.length() < 5.0 or selection_units.is_empty():
		return
	current_selected = []
	for unit : SelectionUnit in selection_units:
		if unit.team != team:
			continue
		var screen_pos = camera.unproject_position(unit.global_transform.origin)
		# Normale Box-Auswahl
		if rect.has_point(screen_pos):
			unit.select()
			current_selected.append(unit)
		else:
			unit.deselect()

func select_unit_by_distance():
	if selection_units.is_empty():
		return
	for u in selection_units:
		u.deselect()
	current_selected = []
	for unit : SelectionUnit in selection_units:
		if unit.team != team:
			continue
		var screen_pos = camera.unproject_position(unit.global_transform.origin)
		if screen_pos.distance_to(select_start) < 15.0:
			unit.select()
			current_selected.append(unit)
			return
		
		

func select_unit_by_collision():
	if selection_units.is_empty():
		return
	for u in selection_units:
		u.deselect()
	current_selected = []
	var camera = get_viewport().get_camera_3d()
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 10000
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	var result = space_state.intersect_ray(query)
	var pos
	if result:
		pos = result.position
		if result["collider"].find_children("", "SelectionUnit", true, false).size() >= 1:
			var su = result["collider"].find_children("", "SelectionUnit", true, false)[0]
			if su.team == self.team:
				current_selected.append(su)
				su.select()
			



func update_selection_shape(
	camera: Camera3D,
	rect: Rect2,
	far_distance: float = 1000.0
) -> void:

	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)

	var cam_pos := camera.global_position

	var dir_tl := camera.project_ray_normal(tl)
	var dir_tr := camera.project_ray_normal(tr)
	var dir_br := camera.project_ray_normal(br)
	var dir_bl := camera.project_ray_normal(bl)

	# Near-Ebene
	var near_distance := camera.near

	var near_tl := cam_pos + dir_tl * near_distance
	var near_tr := cam_pos + dir_tr * near_distance
	var near_br := cam_pos + dir_br * near_distance
	var near_bl := cam_pos + dir_bl * near_distance

	# Far-Ebene
	var far_tl := cam_pos + dir_tl * far_distance
	var far_tr := cam_pos + dir_tr * far_distance
	var far_br := cam_pos + dir_br * far_distance
	var far_bl := cam_pos + dir_bl * far_distance

	var shape := ConvexPolygonShape3D.new()

	shape.points = PackedVector3Array([
		near_tl,
		near_tr,
		near_br,
		near_bl,

		far_tl,
		far_tr,
		far_br,
		far_bl
	])
	collision_shape.shape = shape 
	

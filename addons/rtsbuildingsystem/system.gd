extends Node3D
class_name RTSBuildSystem



var obj_scene
var preview_object = null
var rts_building : RTSBuilding
var main_area : Area3D
var ground_area1 : Area3D
var ground_area2 : Area3D
var ground_area3 : Area3D
var ground_area4 : Area3D
var active : bool = false
var valid_position : bool = false

signal building_set(building)
@export var building_root : Node
@export var camera : Camera3D

func set_preview_object(scene):
	obj_scene = scene
	preview_object = scene.instantiate()
	rts_building = preview_object.get_node("RTSBuilding")
	main_area = rts_building.get_main_area()
	ground_area1 = rts_building.get_ground_area1()
	ground_area2 = rts_building.get_ground_area2()
	ground_area3 = rts_building.get_ground_area3()
	ground_area4 = rts_building.get_ground_area4()
	building_root.add_child(preview_object)
	set_color(preview_object, Color(1, 1, 1, 0.3))


func unset_preview_object():
	building_root.remove_child(preview_object)
	obj_scene = null
	preview_object = null
	rts_building = null
	main_area = null
	ground_area1 = null
	ground_area2 = null
	ground_area3 = null
	ground_area4 = null


func set_color(obj, color : Color):
	for child in obj.get_children():
		if child is MeshInstance3D:
			
			var mat = child.get_active_material(0)
			
			# Falls kein Material vorhanden → neues erstellen
			if mat == null:
				mat = StandardMaterial3D.new()
			
			# WICHTIG: duplizieren!
			mat = mat.duplicate()
			
			# Transparenz aktivieren
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = color
			
			# Optional: weniger Glanz / besser sichtbar
			mat.metallic = 0
			mat.roughness = 1
			
			child.set_surface_override_material(0, mat)



func _input(event):
	if event is InputEventMouseButton and event.pressed and active:
		if event.button_index == MOUSE_BUTTON_LEFT and valid_position:

			var obj = obj_scene.instantiate()
			obj.global_position = preview_object.global_position
			obj.get_node("CollisionShape3D").disabled = false
			
			building_root.add_child(obj)
			building_set.emit(obj)
	
	
				










func _process(delta):
	
	if active:
		var camera = get_viewport().get_camera_3d()
		var mouse_pos = get_viewport().get_mouse_position()

		var from = camera.project_ray_origin(mouse_pos)
		var to = from + camera.project_ray_normal(mouse_pos) * 10000

		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [preview_object, self]
		var result = space_state.intersect_ray(query)

		if result:
			var pos = result.position
			
			var grid_size = 2.0
			pos = pos.snapped(Vector3(grid_size, 0, grid_size))
			
			pos.y += 2.01
			preview_object.global_position = pos
			
			
			
				
			
			if main_area.get_overlapping_bodies().size() > 0:
				set_color(preview_object, Color(1, 0, 0, 0.3))
				valid_position = false
			else:
				if ground_area1.get_overlapping_bodies().size() > 0 and ground_area2.get_overlapping_bodies().size() > 0 and ground_area3.get_overlapping_bodies().size() > 0 and ground_area4.get_overlapping_bodies().size() > 0:
					set_color(preview_object, Color(1, 1, 1, 0.3))
					valid_position = true
				else:
					set_color(preview_object, Color(1, 0, 0, 0.3))
					valid_position = false
				
				

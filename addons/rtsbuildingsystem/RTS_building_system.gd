extends Node3D
class_name RTSBuildSystem

const DEFAULT_RAY_LENGTH: float = 10000.0
const INVALID_GRID: Vector2i = Vector2i(-999999, -999999)

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



signal building_set_command(position : Vector3, scene)

@export var camera : Camera3D
@export var grid_size : float = 2.0

func set_preview_object(scene):
	unset_preview_object()
	obj_scene = scene
	preview_object = scene.instantiate()
	rts_building = preview_object.get_node("RTSBuilding")
	main_area = rts_building.get_main_area()
	ground_area1 = rts_building.get_ground_area1()
	ground_area2 = rts_building.get_ground_area2()
	ground_area3 = rts_building.get_ground_area3()
	ground_area4 = rts_building.get_ground_area4()
	self.add_child(preview_object)
	set_color(preview_object, Color(1, 1, 1, 0.3))
	set_collision(rts_building, false)
	
		


func set_collision(building : RTSBuilding, state : bool):
	var shapes = []
	for child in rts_building.collision_body.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	for shape : CollisionShape3D in shapes:
		shape.disabled = !state
	


func unset_preview_object():
	self.remove_child(preview_object)
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
			building_set_command.emit(preview_object.global_position, obj_scene)
			#var obj = obj_scene.instantiate()
			#obj.global_position = preview_object.global_position
			#building_root.add_child(obj)
			#building_set.emit(obj)

func _physics_process(delta):
	if active:
		var dic : Dictionary = _get_mouse_map_hit()
		if dic.has("position"):
			var pos = dic["position"]
			var x = int(floor(pos.x / grid_size)) * grid_size
			var z = int(floor(pos.z / grid_size)) * grid_size
			
			pos.x = x+1
			pos.y = snapped(pos.y + rts_building.depth/2.0, 0.5)
			pos.z = z+1
			
			
			#pos.y += 0.01
			preview_object.global_position = pos
			print(pos)
			
			
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
				
					

func _process_new(_delta: float) -> void:
	var tile_size : float = 2.0
	if active:
		var hit := _get_mouse_map_hit()
		if hit.is_empty():
			return
		var grid_pos: Vector2i = hit["grid"]
		var hit_position: Vector3 = hit["position"]
		hit_position = hit_position.snapped(Vector3(0,0.5,0))
		var new_pos =Vector3(
			(float(grid_pos.x) + 0.5) * tile_size,
			hit_position.y + 0.03,
			(float(grid_pos.y) + 0.5) * tile_size
		)
		preview_object.global_position = new_pos
		
		
		
			
		
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

func _get_grid_under_mouse() -> Vector2i:
	var hit := _get_mouse_map_hit()

	if hit.is_empty():
		return INVALID_GRID

	return hit["grid"]


func _get_mouse_map_hit() -> Dictionary:
	return get_mouse_map_hit(
		get_viewport(),
		get_world_3d(),
		camera,
		[rts_building.collision_body, main_area, ground_area1, ground_area2, ground_area3, ground_area4],
		DEFAULT_RAY_LENGTH,
		grid_size
	)


static func get_mouse_map_hit(
	viewport: Viewport,
	world_3d: World3D,
	camera_ref: Camera3D = null,
	exclude: Array = [],
	ray_length: float = DEFAULT_RAY_LENGTH,
	tile_size: int = 2
) -> Dictionary:
	if viewport == null:
		return {}

	if world_3d == null:
		return {}

	if camera_ref == null:
		camera_ref = viewport.get_camera_3d()

	if camera_ref == null:
		return {}

	var mouse_pos := viewport.get_mouse_position()
	var from := camera_ref.project_ray_origin(mouse_pos)
	var to := from + camera_ref.project_ray_normal(mouse_pos) * ray_length

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	var result := world_3d.direct_space_state.intersect_ray(query)

	if result.is_empty():
		return {}

	var pos: Vector3 = result.position
	var grid_pos := world_position_to_grid(pos, tile_size)
	#print(grid_pos)

	return {
		"grid": grid_pos,
		"position": pos,
		"collider": result.collider
	}


static func world_position_to_grid(pos: Vector3, tile_size: int = 2) -> Vector2i:
	var grid_x := int(floor(pos.x / tile_size))
	var grid_y := int(floor(pos.z / tile_size))
	return Vector2i(grid_x, grid_y)


static func get_snapped_mouse_position(
	viewport: Viewport,
	world_3d: World3D,
	camera_ref: Camera3D = null,
	exclude: Array = [],
	ray_length: float = DEFAULT_RAY_LENGTH,
	grid_size: float = 2.0
) -> Vector3:
	if viewport == null:
		return Vector3.ZERO

	if world_3d == null:
		return Vector3.ZERO

	if camera_ref == null:
		camera_ref = viewport.get_camera_3d()

	if camera_ref == null:
		return Vector3.ZERO

	var mouse_pos := viewport.get_mouse_position()
	var from := camera_ref.project_ray_origin(mouse_pos)
	var to := from + camera_ref.project_ray_normal(mouse_pos) * ray_length

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = exclude
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = 1

	var result := world_3d.direct_space_state.intersect_ray(query)

	if result.is_empty():
		return Vector3.ZERO

	var pos: Vector3 = result.position
	return pos.snapped(Vector3(grid_size, 0.0, grid_size))

extends RefCounted
class_name MapEntityOutlineRenderer

static func build_entity_outlines(
	visual_root: Node3D,
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	show_entity_outlines: bool,
	entity_outline_height: float,
	entity_outline_y_offset: float,
	tile_size: float
) -> Node3D:
	if not show_entity_outlines:
		return null

	if map_data.is_empty() or visual_root == null:
		return null

	var entity_outline_root := Node3D.new()
	entity_outline_root.name = "EntityOutlines"
	visual_root.add_child(entity_outline_root)

	spawn_resource_outlines(entity_outline_root, map_data, resource_data, entity_definitions, entity_outline_height, entity_outline_y_offset, tile_size)
	spawn_building_outlines(entity_outline_root, map_data, building_data, entity_definitions, entity_outline_height, entity_outline_y_offset, tile_size)

	return entity_outline_root


static func refresh_entity_outlines(
	visual_root: Node3D,
	old_entity_outline_root: Node3D,
	map_data: Array,
	resource_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	show_entity_outlines: bool,
	entity_outline_height: float,
	entity_outline_y_offset: float,
	tile_size: float
) -> Node3D:
	if old_entity_outline_root != null and is_instance_valid(old_entity_outline_root):
		old_entity_outline_root.queue_free()

	return build_entity_outlines(
		visual_root,
		map_data,
		resource_data,
		building_data,
		entity_definitions,
		show_entity_outlines,
		entity_outline_height,
		entity_outline_y_offset,
		tile_size
	)


static func spawn_resource_outlines(
	entity_outline_root: Node3D,
	map_data: Array,
	resource_data: Array,
	entity_definitions: Dictionary,
	entity_outline_height: float,
	entity_outline_y_offset: float,
	tile_size: float
) -> void:
	for y in range(resource_data.size()):
		if typeof(resource_data[y]) != TYPE_ARRAY:
			continue

		for x in range(resource_data[y].size()):
			var cell: Dictionary = resource_data[y][x]
			var stored_resource_type: int = int(cell.get("resource_type", EnumMappings.ResourceType.NONE))

			if stored_resource_type == EnumMappings.ResourceType.NONE:
				continue

			var stored_orientation: int = int(cell.get("orientation", EnumMappings.Orientation.NORTH))
			var footprint := MapResourceService.get_resource_footprint(entity_definitions, stored_resource_type, stored_orientation)
			var color := MapResourceService.get_resource_color(entity_definitions, stored_resource_type)
			var outline_name := "ResourceOutline_%s_%s" % [x, y]

			spawn_entity_outline(
				entity_outline_root,
				map_data,
				Vector2i(x, y),
				footprint,
				color,
				outline_name,
				entity_outline_height,
				entity_outline_y_offset,
				tile_size
			)


static func spawn_building_outlines(
	entity_outline_root: Node3D,
	map_data: Array,
	building_data: Array,
	entity_definitions: Dictionary,
	entity_outline_height: float,
	entity_outline_y_offset: float,
	tile_size: float
) -> void:
	for y in range(building_data.size()):
		if typeof(building_data[y]) != TYPE_ARRAY:
			continue

		for x in range(building_data[y].size()):
			var cell: Dictionary = building_data[y][x]
			var stored_building_type: int = int(cell.get("building_type", EnumMappings.BuildingType.NONE))

			if stored_building_type == EnumMappings.BuildingType.NONE:
				continue

			var origin := MapBuildingService.get_building_origin_from_cell(cell)
			if origin == Vector2i(-1, -1):
				origin = Vector2i(x, y)

			if origin != Vector2i(x, y):
				continue

			var stored_orientation: int = int(cell.get("orientation", EnumMappings.Orientation.NORTH))
			var footprint := MapBuildingService.get_building_footprint(entity_definitions, stored_building_type, stored_orientation)
			var color := MapBuildingService.get_building_color(entity_definitions, stored_building_type)
			var outline_name := "BuildingOutline_%s_%s" % [x, y]

			spawn_entity_outline(
				entity_outline_root,
				map_data,
				origin,
				footprint,
				color,
				outline_name,
				entity_outline_height,
				entity_outline_y_offset,
				tile_size
			)


static func spawn_entity_outline(
	entity_outline_root: Node3D,
	map_data: Array,
	origin: Vector2i,
	footprint: Vector2i,
	color: Color,
	outline_name: String,
	entity_outline_height: float,
	entity_outline_y_offset: float,
	tile_size: float
) -> MeshInstance3D:
	var safe_footprint := Vector2i(max(1, footprint.x), max(1, footprint.y))

	var outline := MeshInstance3D.new()
	outline.name = outline_name
	outline.mesh = create_outline_box_mesh(safe_footprint, entity_outline_height, tile_size)
	outline.material_override = create_outline_material(color)
	outline.global_position = get_outline_world_position(map_data, origin, safe_footprint, entity_outline_y_offset, tile_size)

	entity_outline_root.add_child(outline)
	return outline


static func create_outline_box_mesh(footprint: Vector2i, entity_outline_height: float, tile_size: float) -> ImmediateMesh:
	var size_x := float(footprint.x) * tile_size
	var size_z := float(footprint.y) * tile_size
	var half_x := size_x * 0.5
	var half_z := size_z * 0.5

	var bottom_y := 0.0
	var top_y := entity_outline_height

	var b0 := Vector3(-half_x, bottom_y, -half_z)
	var b1 := Vector3(half_x, bottom_y, -half_z)
	var b2 := Vector3(half_x, bottom_y, half_z)
	var b3 := Vector3(-half_x, bottom_y, half_z)
	var t0 := Vector3(-half_x, top_y, -half_z)
	var t1 := Vector3(half_x, top_y, -half_z)
	var t2 := Vector3(half_x, top_y, half_z)
	var t3 := Vector3(-half_x, top_y, half_z)

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_add_outline_line(mesh, b0, b1)
	_add_outline_line(mesh, b1, b2)
	_add_outline_line(mesh, b2, b3)
	_add_outline_line(mesh, b3, b0)
	_add_outline_line(mesh, t0, t1)
	_add_outline_line(mesh, t1, t2)
	_add_outline_line(mesh, t2, t3)
	_add_outline_line(mesh, t3, t0)
	_add_outline_line(mesh, b0, t0)
	_add_outline_line(mesh, b1, t1)
	_add_outline_line(mesh, b2, t2)
	_add_outline_line(mesh, b3, t3)
	mesh.surface_end()

	return mesh


static func _add_outline_line(mesh: ImmediateMesh, a: Vector3, b: Vector3) -> void:
	mesh.surface_add_vertex(a)
	mesh.surface_add_vertex(b)


static func create_outline_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	return material


static func get_outline_world_position(
	map_data: Array,
	origin: Vector2i,
	footprint: Vector2i,
	entity_outline_y_offset: float,
	tile_size: float
) -> Vector3:
	var base_height := get_max_height_for_footprint(map_data, origin, footprint)

	return Vector3(
		(float(origin.x) + float(footprint.x) * 0.5) * tile_size,
		base_height + entity_outline_y_offset,
		(float(origin.y) + float(footprint.y) * 0.5) * tile_size
	)


static func get_max_height_for_footprint(map_data: Array, origin: Vector2i, footprint: Vector2i) -> float:
	var max_height := -INF

	for y in range(origin.y, origin.y + footprint.y):
		for x in range(origin.x, origin.x + footprint.x):
			if not MapGridService.is_valid_grid_pos(map_data, x, y):
				continue

			var h := MapGridService.get_tile_height(map_data, Vector2i(x, y))
			if h > max_height:
				max_height = h

	if max_height == -INF:
		return 0.0

	return max_height

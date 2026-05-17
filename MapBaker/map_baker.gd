extends Node3D
class_name MapBaker

@export var tile_size: float = 2.0
@export var build_collision: bool = true
@export var show_tile_lines: bool = true
@export var tile_line_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var tile_line_height_offset: float = 0.01

var mesh_instance: MeshInstance3D
var line_mesh_instance: MeshInstance3D
var static_body: StaticBody3D
var collision_shape: CollisionShape3D
var debug_material: StandardMaterial3D
var line_material: StandardMaterial3D
var baked_map_data: Array = []


func _ready() -> void:
	ensure_nodes()


func ensure_nodes() -> void:
	mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	line_mesh_instance = get_node_or_null("TileLines")
	if line_mesh_instance == null:
		line_mesh_instance = MeshInstance3D.new()
		line_mesh_instance.name = "TileLines"
		add_child(line_mesh_instance)

	if build_collision:
		static_body = get_node_or_null("StaticBody3D")
		if static_body == null:
			static_body = StaticBody3D.new()
			static_body.name = "StaticBody3D"
			add_child(static_body)

		collision_shape = static_body.get_node_or_null("CollisionShape3D")
		if collision_shape == null:
			collision_shape = CollisionShape3D.new()
			collision_shape.name = "CollisionShape3D"
			static_body.add_child(collision_shape)

	debug_material = create_debug_material()
	line_material = create_line_material()


func create_debug_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	return mat


func create_line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tile_line_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	return mat


func bake_map(new_map_data: Array) -> void:
	baked_map_data = new_map_data
	ensure_nodes()

	if baked_map_data.is_empty():
		_clear_generated_meshes()
		return

	var map_h := baked_map_data.size()
	var map_w: int = baked_map_data[0].size()

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var line_st := SurfaceTool.new()
	if show_tile_lines:
		line_st.begin(Mesh.PRIMITIVE_LINES)

	for y in range(map_h):
		for x in range(map_w):
			if x < 0 or x >= baked_map_data[y].size():
				continue

			var cell: Dictionary = baked_map_data[y][x]

			add_cell_top(st, x, y, cell, x, y)

			if show_tile_lines:
				add_cell_tile_lines(line_st, x, y, cell)

			var north_cell := get_cell_safe(baked_map_data, x, y - 1)
			var south_cell := get_cell_safe(baked_map_data, x, y + 1)
			var east_cell := get_cell_safe(baked_map_data, x + 1, y)
			var west_cell := get_cell_safe(baked_map_data, x - 1, y)

			add_north_side(st, x, y, cell, north_cell, x, y)
			add_south_side(st, x, y, cell, south_cell, x, y)
			add_east_side(st, x, y, cell, east_cell, x, y)
			add_west_side(st, x, y, cell, west_cell, x, y)

	var mesh := st.commit()
	mesh_instance.mesh = mesh

	if mesh != null:
		mesh.surface_set_material(0, debug_material)

	if show_tile_lines:
		var line_mesh := line_st.commit()
		line_mesh_instance.mesh = line_mesh
		line_mesh_instance.visible = true
		if line_mesh != null:
			line_material = create_line_material()
			line_mesh.surface_set_material(0, line_material)
	else:
		line_mesh_instance.mesh = null
		line_mesh_instance.visible = false

	if build_collision and mesh != null:
		var shape := mesh.create_trimesh_shape()
		collision_shape.shape = shape


func _clear_generated_meshes() -> void:
	ensure_nodes()
	mesh_instance.mesh = null
	line_mesh_instance.mesh = null
	if collision_shape != null:
		collision_shape.shape = null

func get_cell_safe(map_data: Array, x: int, y: int) -> Dictionary:
	if y < 0 or y >= map_data.size():
		return {
			"type": EnumMappings.TileTypeEnums.STANDAD_TILE,
			"height": 0.0
		}

	if x < 0 or x >= map_data[y].size():
		return {
			"type": EnumMappings.TileTypeEnums.STANDAD_TILE,
			"height": 0.0
		}

	return map_data[y][x]


func get_tile_color(tile_type: int) -> Color:
	match tile_type:
		EnumMappings.TileTypeEnums.STANDAD_TILE:
			return Color(0.2, 0.8, 0.2)
		EnumMappings.TileTypeEnums.GOLD_TILE:
			return Color(1.0, 0.85, 0.2)
		EnumMappings.TileTypeEnums.PLAYER_TILE:
			return Color(0, 0,0)
		_:
			return Color(0.5, 0.5, 0.5)


func get_cell_corner_heights(cell: Dictionary) -> Dictionary:
	if cell.has("corners"):
		var c: Dictionary = cell["corners"]
		return {
			"h_sw": float(c.get("sw", cell.get("height", 0.0))),
			"h_se": float(c.get("se", cell.get("height", 0.0))),
			"h_nw": float(c.get("nw", cell.get("height", 0.0))),
			"h_ne": float(c.get("ne", cell.get("height", 0.0)))
		}

	# fallback for old save files
	var h := float(cell.get("height", 0.0))
	return {
		"h_sw": h,
		"h_se": h,
		"h_nw": h,
		"h_ne": h
	}


func add_quad(
	st: SurfaceTool,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	v3: Vector3,
	uv0: Vector2,
	uv1: Vector2,
	uv2: Vector2,
	uv3: Vector2,
	color: Color
) -> void:
	var normal_1 := Plane(v2, v1, v0).normal
	var normal_2 := Plane(v3, v2, v0).normal


	st.set_normal(normal_1)
	st.set_uv(uv0)
	st.set_color(color)
	st.add_vertex(v0)

	st.set_normal(normal_1)
	st.set_uv(uv1)
	st.set_color(color)
	st.add_vertex(v1)

	st.set_normal(normal_1)
	st.set_uv(uv2)
	st.set_color(color)
	st.add_vertex(v2)

	st.set_normal(normal_2)
	st.set_uv(uv0)
	st.set_color(color)
	st.add_vertex(v0)

	st.set_normal(normal_2)
	st.set_uv(uv2)
	st.set_color(color)
	st.add_vertex(v2)

	st.set_normal(normal_2)
	st.set_uv(uv3)
	st.set_color(color)
	st.add_vertex(v3)


func add_cell_tile_lines(line_st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary) -> void:
	var heights := get_cell_corner_heights(cell)

	var x0 := local_x * tile_size
	var x1 := (local_x + 1) * tile_size
	var z0 := local_y * tile_size
	var z1 := (local_y + 1) * tile_size
	var o := tile_line_height_offset

	var v_sw := Vector3(x0, heights["h_sw"] + o, z1)
	var v_se := Vector3(x1, heights["h_se"] + o, z1)
	var v_ne := Vector3(x1, heights["h_ne"] + o, z0)
	var v_nw := Vector3(x0, heights["h_nw"] + o, z0)

	add_debug_line(line_st, v_sw, v_se)
	add_debug_line(line_st, v_se, v_ne)
	add_debug_line(line_st, v_ne, v_nw)
	add_debug_line(line_st, v_nw, v_sw)


func add_debug_line(line_st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	line_st.set_color(tile_line_color)
	line_st.add_vertex(a)
	line_st.set_color(tile_line_color)
	line_st.add_vertex(b)


func add_cell_top(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary, map_x: int, map_y: int) -> void:
	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var heights := get_cell_corner_heights(cell)
	var color := get_tile_color(tile_type)

	var x0 := local_x * tile_size
	var x1 := (local_x + 1) * tile_size
	var z0 := local_y * tile_size
	var z1 := (local_y + 1) * tile_size

	var v_sw := Vector3(x0, heights["h_sw"], z1)
	var v_se := Vector3(x1, heights["h_se"], z1)
	var v_ne := Vector3(x1, heights["h_ne"], z0)
	var v_nw := Vector3(x0, heights["h_nw"], z0)

	add_quad(
		st,
		v_sw, v_se, v_ne, v_nw,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func add_south_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
	map_x: int,
	map_y: int
) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left :float= heights["h_sw"]
	var top_right :float= heights["h_se"]
	var bottom_left :float= neighbor_heights["h_nw"]
	var bottom_right :float= neighbor_heights["h_ne"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var color := get_tile_color(tile_type)

	var x0 := local_x * tile_size
	var x1 := (local_x + 1) * tile_size
	var z := (local_y + 1) * tile_size

	var v_bl := Vector3(x0, bottom_left, z)
	var v_br := Vector3(x1, bottom_right, z)
	var v_tr := Vector3(x1, top_right, z)
	var v_tl := Vector3(x0, top_left, z)

	add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func add_north_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
	map_x: int,
	map_y: int
) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left :float= heights["h_ne"]
	var top_right :float= heights["h_nw"]
	var bottom_left :float= neighbor_heights["h_se"]
	var bottom_right :float= neighbor_heights["h_sw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var color := get_tile_color(tile_type)

	var x0 := local_x * tile_size
	var x1 := (local_x + 1) * tile_size
	var z := local_y * tile_size

	var v_bl := Vector3(x1, bottom_left, z)
	var v_br := Vector3(x0, bottom_right, z)
	var v_tr := Vector3(x0, top_right, z)
	var v_tl := Vector3(x1, top_left, z)

	add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func add_east_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
	map_x: int,
	map_y: int
) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left :float= heights["h_se"]
	var top_right :float= heights["h_ne"]
	var bottom_left :float= neighbor_heights["h_sw"]
	var bottom_right :float= neighbor_heights["h_nw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var color := get_tile_color(tile_type)

	var x := (local_x + 1) * tile_size
	var z0 := (local_y + 1) * tile_size
	var z1 := local_y * tile_size

	var v_bl := Vector3(x, bottom_left, z0)
	var v_br := Vector3(x, bottom_right, z1)
	var v_tr := Vector3(x, top_right, z1)
	var v_tl := Vector3(x, top_left, z0)

	add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func add_west_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
	map_x: int,
	map_y: int
) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left :float= heights["h_nw"]
	var top_right :float= heights["h_sw"]
	var bottom_left :float= neighbor_heights["h_ne"]
	var bottom_right :float= neighbor_heights["h_se"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.TileTypeEnums.STANDAD_TILE))
	var color := get_tile_color(tile_type)

	var x := local_x * tile_size
	var z0 := local_y * tile_size
	var z1 := (local_y + 1) * tile_size

	var v_bl := Vector3(x, bottom_left, z0)
	var v_br := Vector3(x, bottom_right, z1)
	var v_tr := Vector3(x, top_right, z1)
	var v_tl := Vector3(x, top_left, z0)

	add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)

func create_baked_node(baked_name: String = "BakedMap") -> Node3D:
	ensure_nodes()

	var root := Node3D.new()
	root.name = baked_name

	if mesh_instance != null and mesh_instance.mesh != null:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.name = "MeshInstance3D"
		mesh_copy.mesh = mesh_instance.mesh
		if debug_material != null:
			mesh_copy.material_override = debug_material
		root.add_child(mesh_copy)

	if show_tile_lines and line_mesh_instance != null and line_mesh_instance.mesh != null:
		var line_copy := MeshInstance3D.new()
		line_copy.name = "TileLines"
		line_copy.mesh = line_mesh_instance.mesh
		if line_material != null:
			line_copy.material_override = line_material
		root.add_child(line_copy)

	if build_collision and collision_shape != null and collision_shape.shape != null:
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		root.add_child(body)

		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		shape.shape = collision_shape.shape
		body.add_child(shape)

	return root


func save_baked_map(new_map_data: Array, path: String, baked_name: String = "BakedMap") -> void:
	bake_map(new_map_data)

	if mesh_instance == null or mesh_instance.mesh == null:
		push_error("Nothing to save: baked map mesh is empty")
		return

	var root := create_baked_node(baked_name)
	_set_owner_recursive(root, root)

	var packed := PackedScene.new()
	var result := packed.pack(root)
	if result != OK:
		push_error("Failed to pack baked map scene. Error code: %s" % result)
		return

	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		push_error("Failed to save baked map scene. Error code: %s" % save_result)
		return

	print("Baked map scene saved to: ", path)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

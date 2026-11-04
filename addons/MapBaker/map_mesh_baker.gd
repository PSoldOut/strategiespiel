class_name MapMeshBaker
extends RefCounted

var config: MapBakerConfig = MapBakerConfig.new()


func bake_meshes(map_data: Array, requested_bounds := Rect2i()) -> Dictionary:
	var result := {
		"terrain_mesh": null,
		"tile_line_mesh": null,
	}
	var bake_bounds := _resolve_bake_bounds(map_data, requested_bounds)
	if bake_bounds.size.x <= 0 or bake_bounds.size.y <= 0:
		return result

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var line_st := SurfaceTool.new()
	if config.show_tile_lines:
		line_st.begin(Mesh.PRIMITIVE_LINES)

	for y in range(bake_bounds.position.y, bake_bounds.end.y):
		if not map_data[y] is Array:
			continue

		var row: Array = map_data[y]
		for x in range(bake_bounds.position.x, bake_bounds.end.x):
			if x >= row.size() or not row[x] is Dictionary:
				continue

			var cell: Dictionary = row[x]
			var local_x := x - bake_bounds.position.x
			var local_y := y - bake_bounds.position.y

			_add_cell_top(st, local_x, local_y, cell)

			if config.show_tile_lines:
				_add_cell_tile_lines(line_st, local_x, local_y, cell)

			var north_cell := _get_cell_safe(map_data, x, y - 1)
			var south_cell := _get_cell_safe(map_data, x, y + 1)
			var east_cell := _get_cell_safe(map_data, x + 1, y)
			var west_cell := _get_cell_safe(map_data, x - 1, y)

			_add_north_side(st, local_x, local_y, cell, north_cell)
			_add_south_side(st, local_x, local_y, cell, south_cell)
			_add_east_side(st, local_x, local_y, cell, east_cell)
			_add_west_side(st, local_x, local_y, cell, west_cell)

	result["terrain_mesh"] = st.commit()

	if config.show_tile_lines:
		result["tile_line_mesh"] = line_st.commit()

	return result


func _get_cell_safe(map_data: Array, x: int, y: int) -> Dictionary:
	if y < 0 or y >= map_data.size():
		return _make_edge_cell()

	if not map_data[y] is Array:
		return _make_edge_cell()

	if x < 0 or x >= map_data[y].size():
		return _make_edge_cell()

	if not map_data[y][x] is Dictionary:
		return _make_edge_cell()

	return map_data[y][x]


func _get_tile_color(tile_type: int) -> Color:
	return config.get_terrain_color(tile_type)


func _resolve_bake_bounds(map_data: Array, requested_bounds: Rect2i) -> Rect2i:
	if map_data.is_empty() or not map_data[0] is Array:
		return Rect2i()
	var map_bounds := Rect2i(0, 0, map_data[0].size(), map_data.size())
	if requested_bounds.size.x <= 0 or requested_bounds.size.y <= 0:
		return map_bounds
	return requested_bounds.intersection(map_bounds)


func _make_edge_cell() -> Dictionary:
	var height := config.edge_base_height
	return {
		"type": config.default_terrain_type,
		"height": height,
		"corners": {
			"sw": height,
			"se": height,
			"nw": height,
			"ne": height,
		},
	}


func _get_cell_corner_heights(cell: Dictionary) -> Dictionary:
	if cell.has("corners"):
		var c: Dictionary = cell["corners"]
		return {
			"h_sw": float(c.get("sw", cell.get("height", 0.0))),
			"h_se": float(c.get("se", cell.get("height", 0.0))),
			"h_nw": float(c.get("nw", cell.get("height", 0.0))),
			"h_ne": float(c.get("ne", cell.get("height", 0.0)))
		}

	var h := float(cell.get("height", 0.0))
	return {
		"h_sw": h,
		"h_se": h,
		"h_nw": h,
		"h_ne": h
	}


func _add_quad(
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
	# Wichtig:
	# Godot/Physics wertet die Triangle-Winding für Trimesh-Collision aus.
	# Wenn der Raycast nur von unten trifft, ist die Vorderseite der Dreiecke
	# falsch herum. Deshalb werden die beiden Triangles hier gedreht:
	#
	# vorher: v0, v1, v2  und  v0, v2, v3
	# jetzt:  v0, v2, v1  und  v0, v3, v2
	#
	# Dadurch zeigen die Frontfaces der Quads auf die andere Seite,
	# ohne den MeshInstance3D oder CollisionShape3D räumlich zu rotieren.

	var normal_1 := Plane(v0, v2, v1).normal
	var normal_2 := Plane(v0, v3, v2).normal

	st.set_normal(normal_1)
	st.set_uv(uv0)
	st.set_color(color)
	st.add_vertex(v0)

	st.set_normal(normal_1)
	st.set_uv(uv2)
	st.set_color(color)
	st.add_vertex(v2)

	st.set_normal(normal_1)
	st.set_uv(uv1)
	st.set_color(color)
	st.add_vertex(v1)

	st.set_normal(normal_2)
	st.set_uv(uv0)
	st.set_color(color)
	st.add_vertex(v0)

	st.set_normal(normal_2)
	st.set_uv(uv3)
	st.set_color(color)
	st.add_vertex(v3)

	st.set_normal(normal_2)
	st.set_uv(uv2)
	st.set_color(color)
	st.add_vertex(v2)



func _add_cell_tile_lines(
	line_st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
) -> void:
	var heights := _get_cell_corner_heights(cell)

	var x0 := local_x * config.tile_size
	var x1 := (local_x + 1) * config.tile_size
	var z0 := local_y * config.tile_size
	var z1 := (local_y + 1) * config.tile_size
	var o := config.tile_line_height_offset

	var v_sw := Vector3(x0, heights["h_sw"] + o, z1)
	var v_se := Vector3(x1, heights["h_se"] + o, z1)
	var v_ne := Vector3(x1, heights["h_ne"] + o, z0)
	var v_nw := Vector3(x0, heights["h_nw"] + o, z0)

	_add_debug_line(line_st, v_sw, v_se)
	_add_debug_line(line_st, v_se, v_ne)
	_add_debug_line(line_st, v_ne, v_nw)
	_add_debug_line(line_st, v_nw, v_sw)


func _add_debug_line(line_st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	line_st.set_color(config.tile_line_color)
	line_st.add_vertex(a)
	line_st.set_color(config.tile_line_color)
	line_st.add_vertex(b)


func _add_cell_top(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary) -> void:
	var tile_type: int = int(cell.get("type", config.default_terrain_type))
	var heights := _get_cell_corner_heights(cell)
	var color := _get_tile_color(tile_type)

	var x0 := local_x * config.tile_size
	var x1 := (local_x + 1) * config.tile_size
	var z0 := local_y * config.tile_size
	var z1 := (local_y + 1) * config.tile_size

	var v_sw := Vector3(x0, heights["h_sw"], z1)
	var v_se := Vector3(x1, heights["h_se"], z1)
	var v_ne := Vector3(x1, heights["h_ne"], z0)
	var v_nw := Vector3(x0, heights["h_nw"], z0)

	_add_quad(
		st,
		v_sw, v_se, v_ne, v_nw,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func _add_south_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
) -> void:
	var heights := _get_cell_corner_heights(cell)
	var neighbor_heights := _get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_sw"]
	var top_right: float = heights["h_se"]
	var bottom_left: float = neighbor_heights["h_nw"]
	var bottom_right: float = neighbor_heights["h_ne"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", config.default_terrain_type))
	var color := _get_tile_color(tile_type)

	var x0 := local_x * config.tile_size
	var x1 := (local_x + 1) * config.tile_size
	var z := (local_y + 1) * config.tile_size

	var v_bl := Vector3(x0, bottom_left, z)
	var v_br := Vector3(x1, bottom_right, z)
	var v_tr := Vector3(x1, top_right, z)
	var v_tl := Vector3(x0, top_left, z)

	_add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func _add_north_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
) -> void:
	var heights := _get_cell_corner_heights(cell)
	var neighbor_heights := _get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_ne"]
	var top_right: float = heights["h_nw"]
	var bottom_left: float = neighbor_heights["h_se"]
	var bottom_right: float = neighbor_heights["h_sw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", config.default_terrain_type))
	var color := _get_tile_color(tile_type)

	var x0 := local_x * config.tile_size
	var x1 := (local_x + 1) * config.tile_size
	var z := local_y * config.tile_size

	var v_bl := Vector3(x1, bottom_left, z)
	var v_br := Vector3(x0, bottom_right, z)
	var v_tr := Vector3(x0, top_right, z)
	var v_tl := Vector3(x1, top_left, z)

	_add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func _add_east_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
) -> void:
	var heights := _get_cell_corner_heights(cell)
	var neighbor_heights := _get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_se"]
	var top_right: float = heights["h_ne"]
	var bottom_left: float = neighbor_heights["h_sw"]
	var bottom_right: float = neighbor_heights["h_nw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", config.default_terrain_type))
	var color := _get_tile_color(tile_type)

	var x := (local_x + 1) * config.tile_size
	var z0 := (local_y + 1) * config.tile_size
	var z1 := local_y * config.tile_size

	var v_bl := Vector3(x, bottom_left, z0)
	var v_br := Vector3(x, bottom_right, z1)
	var v_tr := Vector3(x, top_right, z1)
	var v_tl := Vector3(x, top_left, z0)

	_add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)


func _add_west_side(
	st: SurfaceTool,
	local_x: int,
	local_y: int,
	cell: Dictionary,
	neighbor: Dictionary,
) -> void:
	var heights := _get_cell_corner_heights(cell)
	var neighbor_heights := _get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_nw"]
	var top_right: float = heights["h_sw"]
	var bottom_left: float = neighbor_heights["h_ne"]
	var bottom_right: float = neighbor_heights["h_se"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", config.default_terrain_type))
	var color := _get_tile_color(tile_type)

	var x := local_x * config.tile_size
	var z0 := local_y * config.tile_size
	var z1 := (local_y + 1) * config.tile_size

	var v_bl := Vector3(x, bottom_left, z0)
	var v_br := Vector3(x, bottom_right, z1)
	var v_tr := Vector3(x, top_right, z1)
	var v_tl := Vector3(x, top_left, z0)

	_add_quad(
		st,
		v_bl, v_br, v_tr, v_tl,
		Vector2(0.0, 1.0),
		Vector2(1.0, 1.0),
		Vector2(1.0, 0.0),
		Vector2(0.0, 0.0),
		color
	)

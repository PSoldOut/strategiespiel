extends RefCounted
class_name MapMeshBaker

var tile_size: float = 2.0
var show_tile_lines: bool = true
var tile_line_color: Color = Color(0.0, 0.0, 0.0, 1.0)
var tile_line_height_offset: float = 0.01


func bake_meshes(map_data: Array) -> Dictionary:
	var result := {
		"terrain_mesh": null,
		"tile_line_mesh": null,
	}

	if map_data.is_empty():
		return result

	var map_h := map_data.size()
	if map_h <= 0:
		return result

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var line_st := SurfaceTool.new()
	if show_tile_lines:
		line_st.begin(Mesh.PRIMITIVE_LINES)

	for y in range(map_h):
		if not map_data[y] is Array:
			continue

		var row: Array = map_data[y]
		for x in range(row.size()):
			var cell: Dictionary = row[x]

			add_cell_top(st, x, y, cell)

			if show_tile_lines:
				add_cell_tile_lines(line_st, x, y, cell)

			var north_cell := get_cell_safe(map_data, x, y - 1)
			var south_cell := get_cell_safe(map_data, x, y + 1)
			var east_cell := get_cell_safe(map_data, x + 1, y)
			var west_cell := get_cell_safe(map_data, x - 1, y)

			add_north_side(st, x, y, cell, north_cell)
			add_south_side(st, x, y, cell, south_cell)
			add_east_side(st, x, y, cell, east_cell)
			add_west_side(st, x, y, cell, west_cell)

	result["terrain_mesh"] = st.commit()

	if show_tile_lines:
		result["tile_line_mesh"] = line_st.commit()

	return result


func get_cell_safe(map_data: Array, x: int, y: int) -> Dictionary:
	if y < 0 or y >= map_data.size():
		return {
			"type": EnumMappings.GroundType.GRAS_TILE,
			"height": 0.0
		}

	if not map_data[y] is Array:
		return {
			"type": EnumMappings.GroundType.GRAS_TILE,
			"height": 0.0
		}

	if x < 0 or x >= map_data[y].size():
		return {
			"type": EnumMappings.GroundType.GRAS_TILE,
			"height": 0.0
		}

	return map_data[y][x]


func get_tile_color(tile_type: int) -> Color:
	match tile_type:
		EnumMappings.GroundType.GRAS_TILE:
			return Color(0.2, 0.8, 0.2)
		EnumMappings.GroundType.SAND_TILE:
			return Color(1.0, 0.85, 0.2)
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


func add_cell_top(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary) -> void:
	var tile_type: int = int(cell.get("type", EnumMappings.GroundType.GRAS_TILE))
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


func add_south_side(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary, neighbor: Dictionary) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_sw"]
	var top_right: float = heights["h_se"]
	var bottom_left: float = neighbor_heights["h_nw"]
	var bottom_right: float = neighbor_heights["h_ne"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.GroundType.GRAS_TILE))
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


func add_north_side(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary, neighbor: Dictionary) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_ne"]
	var top_right: float = heights["h_nw"]
	var bottom_left: float = neighbor_heights["h_se"]
	var bottom_right: float = neighbor_heights["h_sw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.GroundType.GRAS_TILE))
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


func add_east_side(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary, neighbor: Dictionary) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_se"]
	var top_right: float = heights["h_ne"]
	var bottom_left: float = neighbor_heights["h_sw"]
	var bottom_right: float = neighbor_heights["h_nw"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.GroundType.GRAS_TILE))
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


func add_west_side(st: SurfaceTool, local_x: int, local_y: int, cell: Dictionary, neighbor: Dictionary) -> void:
	var heights := get_cell_corner_heights(cell)
	var neighbor_heights := get_cell_corner_heights(neighbor)

	var top_left: float = heights["h_nw"]
	var top_right: float = heights["h_sw"]
	var bottom_left: float = neighbor_heights["h_ne"]
	var bottom_right: float = neighbor_heights["h_se"]

	if top_left <= bottom_left and top_right <= bottom_right:
		return

	var tile_type: int = int(cell.get("type", EnumMappings.GroundType.GRAS_TILE))
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

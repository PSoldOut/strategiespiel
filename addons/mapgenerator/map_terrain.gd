class_name MapTerrain
extends Node3D

## Heightfield terrain with one ground type per cell.
##
## The terrain is completely independent from the game. It builds an
## [ArrayMesh] with one surface per ground type and a matching
## [ConcavePolygonShape3D] for picking and collisions.

signal changed

enum GroundType {
	MEADOW,
	SAND,
	WATER,
}

const GROUND_KEYS: Array[String] = ["meadow", "sand", "water"]
const GROUND_LABELS: Array[String] = ["Wiese", "Sand", "Wasser"]
const MAX_SIZE: int = 512

## Size of one grid cell in world units. The game uses 2.0 as well.
@export var cell_size: float = 2.0
## Number of cells along X.
@export var width: int = 32
## Number of cells along Z.
@export var depth: int = 32
## Height every corner starts with.
@export var initial_height: float = 0.0
@export var min_height: float = -6.0
@export var max_height: float = 24.0

@export_group("Look")
@export var meadow_color: Color = Color(0.33, 0.55, 0.25)
@export var sand_color: Color = Color(0.82, 0.74, 0.5)
@export var water_color: Color = Color(0.18, 0.42, 0.68)
@export var show_grid: bool = true
@export var grid_color: Color = Color(0.05, 0.05, 0.05, 0.22)

var _heights: PackedFloat32Array = PackedFloat32Array()
var _ground: PackedInt32Array = PackedInt32Array()

var _mesh_instance: MeshInstance3D
var _collision_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _grid_instance: MeshInstance3D

var _materials: Array[StandardMaterial3D] = []
var _grid_material: StandardMaterial3D
var _dirty: bool = false


func _ready() -> void:
	_ensure_nodes()
	reset()


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild()


func _ensure_nodes() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainMesh"
	add_child(_mesh_instance)

	_collision_body = StaticBody3D.new()
	_collision_body.name = "TerrainCollision"
	# Layer 1 for the game, layer 2 so the editor can pick the ground without
	# hitting placed objects.
	_collision_body.collision_layer = 3
	_collision_body.collision_mask = 0
	add_child(_collision_body)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	_collision_body.add_child(_collision_shape)

	_grid_instance = MeshInstance3D.new()
	_grid_instance.name = "Grid"
	add_child(_grid_instance)

	_build_materials()


func _build_materials() -> void:
	_materials.clear()
	_materials.append(_make_surface_material(meadow_color, 1.0))
	_materials.append(_make_surface_material(sand_color, 1.0))
	_materials.append(_make_surface_material(water_color, 0.25))

	_grid_material = StandardMaterial3D.new()
	_grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_material.albedo_color = grid_color
	_grid_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _make_surface_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Restores the configured size and clears every height and ground type.
func reset() -> void:
	_ensure_nodes()

	width = clampi(width, 1, MAX_SIZE)
	depth = clampi(depth, 1, MAX_SIZE)

	_heights.resize((width + 1) * (depth + 1))
	_heights.fill(initial_height)

	_ground.resize(width * depth)
	_ground.fill(GroundType.MEADOW)

	_dirty = false
	_rebuild()
	changed.emit()


## Changes the field size in cells and clears the map.
func set_map_size(new_width: int, new_depth: int) -> void:
	width = clampi(new_width, 1, MAX_SIZE)
	depth = clampi(new_depth, 1, MAX_SIZE)
	reset()


func flush() -> void:
	if _dirty:
		_rebuild()


func _mark_dirty() -> void:
	_dirty = true


func _rebuild() -> void:
	_dirty = false
	_mesh_instance.mesh = build_mesh()
	_collision_shape.shape = build_collision_shape()
	_rebuild_grid()
	changed.emit()


func _rebuild_grid() -> void:
	if not show_grid:
		_grid_instance.visible = false
		return

	_grid_instance.visible = true
	var line_vertices := PackedVector3Array()
	var lift := Vector3.UP * 0.04

	for z in range(depth + 1):
		for x in range(width):
			line_vertices.append(_corner_position(x, z) + lift)
			line_vertices.append(_corner_position(x + 1, z) + lift)

	for x in range(width + 1):
		for z in range(depth):
			line_vertices.append(_corner_position(x, z) + lift)
			line_vertices.append(_corner_position(x, z + 1) + lift)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = line_vertices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh.surface_set_material(0, _grid_material)
	_grid_instance.mesh = mesh


## Builds the render mesh with one surface per ground type.
func build_mesh() -> ArrayMesh:
	var vertices: Array = [[], [], []]
	var normals: Array = [[], [], []]
	var uvs: Array = [[], [], []]
	var indices: Array = [[], [], []]

	for z in range(depth):
		for x in range(width):
			var type: int = _ground[z * width + x]
			var p00 := _corner_position(x, z)
			var p10 := _corner_position(x + 1, z)
			var p11 := _corner_position(x + 1, z + 1)
			var p01 := _corner_position(x, z + 1)

			var normal := (p01 - p00).cross(p10 - p00).normalized()
			if normal.is_zero_approx():
				normal = Vector3.UP

			var cell_vertices: Array = vertices[type]
			var cell_normals: Array = normals[type]
			var cell_uvs: Array = uvs[type]
			var cell_indices: Array = indices[type]
			var base: int = cell_vertices.size()

			cell_vertices.append(p00)
			cell_vertices.append(p10)
			cell_vertices.append(p11)
			cell_vertices.append(p01)
			for _i in range(4):
				cell_normals.append(normal)
			cell_uvs.append(Vector2(0.0, 0.0))
			cell_uvs.append(Vector2(1.0, 0.0))
			cell_uvs.append(Vector2(1.0, 1.0))
			cell_uvs.append(Vector2(0.0, 1.0))

			cell_indices.append(base + 0)
			cell_indices.append(base + 1)
			cell_indices.append(base + 2)
			cell_indices.append(base + 0)
			cell_indices.append(base + 2)
			cell_indices.append(base + 3)

	var mesh := ArrayMesh.new()
	for type in range(GROUND_KEYS.size()):
		var cell_vertices: Array = vertices[type]
		if cell_vertices.is_empty():
			continue

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(cell_vertices)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(normals[type])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(uvs[type])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices[type])

		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[type])

	return mesh


## Builds the collision shape used by the editor and the exported map.
func build_collision_shape() -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()

	for z in range(depth):
		for x in range(width):
			var p00 := _corner_position(x, z)
			var p10 := _corner_position(x + 1, z)
			var p11 := _corner_position(x + 1, z + 1)
			var p01 := _corner_position(x, z + 1)

			faces.append(p00)
			faces.append(p10)
			faces.append(p11)
			faces.append(p00)
			faces.append(p11)
			faces.append(p01)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	return shape


## Creates a plain scene tree for the exported map. It contains no plugin
## scripts, so the scene can be loaded by the game directly.
func build_export_terrain() -> Node3D:
	var root := Node3D.new()
	root.name = "Terrain"

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainMesh"
	mesh_instance.mesh = build_mesh()
	root.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 3
	body.collision_mask = 0
	root.add_child(body)

	var shape_instance := CollisionShape3D.new()
	shape_instance.name = "CollisionShape3D"
	shape_instance.shape = build_collision_shape()
	body.add_child(shape_instance)

	return root


func _corner_position(x: int, z: int) -> Vector3:
	return Vector3(
		float(x) * cell_size,
		_heights[z * (width + 1) + x],
		float(z) * cell_size
	)


func get_corners() -> Vector2i:
	return Vector2i(width + 1, depth + 1)


func get_height_at_cell_corner(x: int, z: int) -> float:
	if x < 0 or x > width or z < 0 or z > depth:
		return 0.0
	return _heights[z * (width + 1) + x]


## Bilinear height sample in local terrain coordinates.
func sample_height(local_x: float, local_z: float) -> float:
	var gx: float = clampf(local_x / cell_size, 0.0, float(width))
	var gz: float = clampf(local_z / cell_size, 0.0, float(depth))

	var x0: int = clampi(floori(gx), 0, width - 1)
	var z0: int = clampi(floori(gz), 0, depth - 1)
	var tx: float = gx - float(x0)
	var tz: float = gz - float(z0)

	var h00 := get_height_at_cell_corner(x0, z0)
	var h10 := get_height_at_cell_corner(x0 + 1, z0)
	var h01 := get_height_at_cell_corner(x0, z0 + 1)
	var h11 := get_height_at_cell_corner(x0 + 1, z0 + 1)

	var bottom: float = lerpf(h00, h10, tx)
	var top: float = lerpf(h01, h11, tx)
	return lerpf(bottom, top, tz)


## Converts a world position into a cell. The result can be outside the map.
func world_to_cell(world_position: Vector3) -> Vector2i:
	var local := to_local(world_position)
	return Vector2i(floori(local.x / cell_size), floori(local.z / cell_size))


func is_cell_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < depth


func get_cell_center_local(cell: Vector2i) -> Vector3:
	return Vector3(
		(float(cell.x) + 0.5) * cell_size,
		0.0,
		(float(cell.y) + 0.5) * cell_size
	)


## Cell center on top of the terrain, in world coordinates.
func get_cell_center_world(cell: Vector2i) -> Vector3:
	var local := get_cell_center_local(cell)
	local.y = sample_height(local.x, local.z)
	return to_global(local)


func get_ground_type(cell: Vector2i) -> int:
	if not is_cell_inside(cell):
		return GroundType.MEADOW
	return _ground[cell.y * width + cell.x]


func set_ground_type(cell: Vector2i, type: int) -> void:
	if not is_cell_inside(cell):
		return
	var index: int = cell.y * width + cell.x
	var clamped_type: int = clampi(type, 0, GROUND_KEYS.size() - 1)
	if _ground[index] == clamped_type:
		return
	_ground[index] = clamped_type
	_mark_dirty()


## Raises or lowers the terrain around a world position.
## [param radius_cells] is the brush radius in cells, [param delta] is the
## height change in world units at the brush center.
func sculpt(world_position: Vector3, radius_cells: float, delta: float) -> void:
	if is_zero_approx(delta):
		return

	var local := to_local(world_position)
	var radius_world: float = maxf(radius_cells, 0.25) * cell_size
	var min_x: int = clampi(floori((local.x - radius_world) / cell_size), 0, width)
	var max_x: int = clampi(ceili((local.x + radius_world) / cell_size), 0, width)
	var min_z: int = clampi(floori((local.z - radius_world) / cell_size), 0, depth)
	var max_z: int = clampi(ceili((local.z + radius_world) / cell_size), 0, depth)

	var touched: bool = false
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var dx: float = float(x) * cell_size - local.x
			var dz: float = float(z) * cell_size - local.z
			var distance: float = sqrt(dx * dx + dz * dz)
			if distance > radius_world:
				continue

			var falloff: float = 1.0 - distance / radius_world
			falloff = falloff * falloff * (3.0 - 2.0 * falloff)
			var index: int = z * (width + 1) + x
			_heights[index] = clampf(
				_heights[index] + delta * falloff,
				min_height,
				max_height
			)
			touched = true

	if touched:
		_mark_dirty()


## Paints the selected ground type inside the brush circle.
func paint(world_position: Vector3, radius_cells: float, type: int) -> void:
	var local := to_local(world_position)
	var radius_world: float = maxf(radius_cells, 0.25) * cell_size
	var center := world_to_cell(world_position)
	var range_cells: int = maxi(1, ceili(radius_cells))
	var clamped_type: int = clampi(type, 0, GROUND_KEYS.size() - 1)

	var touched: bool = false
	for z in range(maxi(0, center.y - range_cells), mini(depth - 1, center.y + range_cells) + 1):
		for x in range(maxi(0, center.x - range_cells), mini(width - 1, center.x + range_cells) + 1):
			var cell_center := get_cell_center_local(Vector2i(x, z))
			var dx: float = cell_center.x - local.x
			var dz: float = cell_center.z - local.z
			if sqrt(dx * dx + dz * dz) > radius_world:
				continue

			var index: int = z * width + x
			if _ground[index] != clamped_type:
				_ground[index] = clamped_type
				touched = true

	if touched:
		_mark_dirty()


func serialize_data() -> Dictionary:
	var heights: Array = []
	for value in _heights:
		heights.append(value)

	var ground_types: Array = []
	for value in _ground:
		ground_types.append(GROUND_KEYS[clampi(value, 0, GROUND_KEYS.size() - 1)])

	return {
		"cell_size": cell_size,
		"width": width,
		"depth": depth,
		"min_height": min_height,
		"max_height": max_height,
		"heights": heights,
		"ground_types": ground_types,
	}


func load_data(data: Dictionary) -> void:
	width = clampi(int(data.get("width", width)), 1, MAX_SIZE)
	depth = clampi(int(data.get("depth", depth)), 1, MAX_SIZE)
	cell_size = float(data.get("cell_size", cell_size))
	min_height = float(data.get("min_height", min_height))
	max_height = float(data.get("max_height", max_height))

	_ensure_nodes()

	_heights.resize((width + 1) * (depth + 1))
	_heights.fill(initial_height)
	_ground.resize(width * depth)
	_ground.fill(GroundType.MEADOW)

	var heights_value: Variant = data.get("heights", [])
	if heights_value is Array:
		var heights: Array = heights_value
		var count: int = mini(heights.size(), _heights.size())
		for index in range(count):
			_heights[index] = float(heights[index])

	var ground_value: Variant = data.get("ground_types", [])
	if ground_value is Array:
		var ground_types: Array = ground_value
		var count: int = mini(ground_types.size(), _ground.size())
		for index in range(count):
			var key: String = str(ground_types[index])
			var type: int = GROUND_KEYS.find(key)
			_ground[index] = type if type >= 0 else GroundType.MEADOW

	_dirty = false
	_rebuild()


static func ground_label(type: int) -> String:
	return GROUND_LABELS[clampi(type, 0, GROUND_LABELS.size() - 1)]

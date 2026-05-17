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

	static_body = get_node_or_null("StaticBody3D")
	if static_body == null and build_collision:
		static_body = StaticBody3D.new()
		static_body.name = "StaticBody3D"
		add_child(static_body)

	if static_body != null:
		collision_shape = static_body.get_node_or_null("CollisionShape3D")
		if collision_shape == null and build_collision:
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

	var mesh_baker := MapMeshBaker.new()
	mesh_baker.tile_size = tile_size
	mesh_baker.show_tile_lines = show_tile_lines
	mesh_baker.tile_line_color = tile_line_color
	mesh_baker.tile_line_height_offset = tile_line_height_offset

	var baked_meshes := mesh_baker.bake_meshes(baked_map_data)
	var terrain_mesh: Mesh = baked_meshes.get("terrain_mesh", null)
	var tile_line_mesh: Mesh = baked_meshes.get("tile_line_mesh", null)

	_apply_terrain_mesh(terrain_mesh)
	_apply_tile_line_mesh(tile_line_mesh)
	_apply_collision_from_mesh(terrain_mesh)


func _apply_terrain_mesh(terrain_mesh: Mesh) -> void:
	mesh_instance.mesh = terrain_mesh

	if terrain_mesh != null:
		debug_material = create_debug_material()
		terrain_mesh.surface_set_material(0, debug_material)


func _apply_tile_line_mesh(tile_line_mesh: Mesh) -> void:
	if not show_tile_lines:
		line_mesh_instance.mesh = null
		line_mesh_instance.visible = false
		return

	line_mesh_instance.mesh = tile_line_mesh
	line_mesh_instance.visible = tile_line_mesh != null

	if tile_line_mesh != null:
		line_material = create_line_material()
		tile_line_mesh.surface_set_material(0, line_material)


func _apply_collision_from_mesh(terrain_mesh: Mesh) -> void:
	if not build_collision:
		if collision_shape != null:
			collision_shape.shape = null
		if static_body != null:
			static_body.visible = false
		return

	if static_body == null or collision_shape == null:
		ensure_nodes()

	if collision_shape == null:
		return

	collision_shape.shape = MapCollisionBaker.make_trimesh_shape(terrain_mesh)

	if static_body != null:
		static_body.visible = collision_shape.shape != null


func _clear_generated_meshes() -> void:
	ensure_nodes()
	mesh_instance.mesh = null
	line_mesh_instance.mesh = null
	if collision_shape != null:
		collision_shape.shape = null


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

	if build_collision and mesh_instance != null and mesh_instance.mesh != null:
		var body := MapCollisionBaker.make_static_body_from_mesh(mesh_instance.mesh)
		if body != null:
			root.add_child(body)

	return root


func save_baked_map(whole_map_data: Array, path: String, baked_name: String = "BakedMap") -> Error:
	var root := get_baked_map(whole_map_data, baked_name)
	if root == null:
		push_error("Nothing to save: baked whole map mesh is empty")
		return ERR_CANT_CREATE

	return _save_baked_root(root, path)


func save_baked_quad(quad_map_data: Array, path: String, baked_name: String = "BakedQuad") -> Error:
	var root := get_baked_quad(quad_map_data, baked_name)
	if root == null:
		push_error("Nothing to save: baked quad mesh is empty")
		return ERR_CANT_CREATE

	return _save_baked_root(root, path)


func get_baked_map(whole_map_data: Array, baked_name: String = "BakedMap") -> Node3D:
	bake_map(whole_map_data)

	if mesh_instance == null or mesh_instance.mesh == null:
		return null

	var root := create_baked_node(baked_name)
	_prepare_packed_scene_owners(root)
	return root


func get_baked_quad(quad_map_data: Array, baked_name: String = "BakedQuad") -> Node3D:
	bake_map(quad_map_data)

	if mesh_instance == null or mesh_instance.mesh == null:
		return null

	var root := create_baked_node(baked_name)
	_prepare_packed_scene_owners(root)
	return root


func save_baked_four_rotated_corners(corner_map_data: Array, path: String, baked_name: String = "BakedMap") -> Error:
	var full_map := MapQuads.build_from_single_corner(corner_map_data)
	return save_baked_map(full_map, path, baked_name)


func get_baked_four_rotated_corners(corner_map_data: Array, baked_name: String = "BakedMap") -> Node3D:
	var full_map := MapQuads.build_from_single_corner(corner_map_data)
	return get_baked_map(full_map, baked_name)


func _save_baked_root(root: Node3D, path: String) -> Error:
	_ensure_directory_for_file(path)

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("Failed to pack baked map scene. Error code: %s" % pack_result)
		return pack_result

	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		push_error("Failed to save baked map scene. Error code: %s" % save_result)
		return save_result

	print("Baked map scene saved to: ", path)
	return OK


func _ensure_directory_for_file(path: String) -> void:
	var base_dir := path.get_base_dir()
	if base_dir.is_empty() or DirAccess.dir_exists_absolute(base_dir):
		return

	var result := DirAccess.make_dir_recursive_absolute(base_dir)
	if result != OK:
		push_error("Failed to create directory for baked map: %s Error: %s" % [base_dir, result])


func _prepare_packed_scene_owners(root: Node) -> void:
	for child in root.get_children():
		child.owner = root
		_set_owner_recursive(child, root)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

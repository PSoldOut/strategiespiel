class_name MapBaker
extends Node3D
## Converts normalized row-major terrain data into meshes and collision.

@export var config: MapBakerConfig = MapBakerConfig.new()

var _mesh_instance: MeshInstance3D
var _line_mesh_instance: MeshInstance3D
var _static_body: StaticBody3D
var _collision_shape: CollisionShape3D
var _terrain_material: StandardMaterial3D
var _line_material: StandardMaterial3D


func _ready() -> void:
	_ensure_nodes()


func bake_map(map_data: Array, bake_bounds := Rect2i()) -> bool:
	_ensure_config()
	_ensure_nodes()
	if map_data.is_empty():
		_clear_generated_meshes()
		return false

	var mesh_baker := MapMeshBaker.new()
	mesh_baker.config = config
	var baked_meshes := mesh_baker.bake_meshes(map_data, bake_bounds)
	var terrain_mesh := baked_meshes.get("terrain_mesh") as Mesh
	var tile_line_mesh := baked_meshes.get("tile_line_mesh") as Mesh

	_apply_terrain_mesh(terrain_mesh)
	_apply_tile_line_mesh(tile_line_mesh)
	_apply_collision_from_mesh(terrain_mesh)
	return terrain_mesh != null


func create_baked_node(baked_name: String = "BakedMap") -> Node3D:
	_ensure_config()
	_ensure_nodes()
	var root := Node3D.new()
	root.name = baked_name

	if _mesh_instance.mesh != null:
		var mesh_copy := MeshInstance3D.new()
		mesh_copy.name = "MeshInstance3D"
		mesh_copy.mesh = _mesh_instance.mesh
		mesh_copy.material_override = _terrain_material
		root.add_child(mesh_copy)

	if config.show_tile_lines and _line_mesh_instance.mesh != null:
		var line_copy := MeshInstance3D.new()
		line_copy.name = "TileLines"
		line_copy.mesh = _line_mesh_instance.mesh
		line_copy.material_override = _line_material
		root.add_child(line_copy)

	if config.build_collision and _mesh_instance.mesh != null:
		var body := MapCollisionBaker.make_static_body_from_mesh(_mesh_instance.mesh)
		if body != null:
			root.add_child(body)
	return root


func get_baked_map(map_data: Array, baked_name: String = "BakedMap") -> Node3D:
	if not bake_map(map_data):
		return null
	var root := create_baked_node(baked_name)
	_prepare_packed_scene_owners(root)
	return root


func save_baked_map(
	map_data: Array,
	path: String,
	baked_name: String = "BakedMap",
) -> Error:
	var root := get_baked_map(map_data, baked_name)
	if root == null:
		push_error("MapBaker: nothing to save because the baked mesh is empty.")
		return ERR_CANT_CREATE

	var directory_result := _ensure_directory_for_file(path)
	if directory_result != OK:
		root.free()
		return directory_result

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		push_error("MapBaker: failed to pack scene. Error: %s" % pack_result)
		root.free()
		return pack_result

	var save_result := ResourceSaver.save(packed, path)
	root.free()
	if save_result != OK:
		push_error("MapBaker: failed to save scene. Error: %s" % save_result)
	return save_result


func _ensure_config() -> void:
	if config == null:
		config = MapBakerConfig.new()


func _ensure_nodes() -> void:
	_ensure_config()
	_mesh_instance = get_node_or_null("MeshInstance3D")
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance3D"
		add_child(_mesh_instance)

	_line_mesh_instance = get_node_or_null("TileLines")
	if _line_mesh_instance == null:
		_line_mesh_instance = MeshInstance3D.new()
		_line_mesh_instance.name = "TileLines"
		add_child(_line_mesh_instance)

	_static_body = get_node_or_null("StaticBody3D")
	if _static_body == null and config.build_collision:
		_static_body = StaticBody3D.new()
		_static_body.name = "StaticBody3D"
		add_child(_static_body)

	if _static_body != null:
		_collision_shape = _static_body.get_node_or_null("CollisionShape3D")
		if _collision_shape == null and config.build_collision:
			_collision_shape = CollisionShape3D.new()
			_collision_shape.name = "CollisionShape3D"
			_static_body.add_child(_collision_shape)

	_terrain_material = _create_terrain_material()
	_line_material = _create_line_material()


func _create_terrain_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	return material


func _create_line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = config.tile_line_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _apply_terrain_mesh(terrain_mesh: Mesh) -> void:
	_mesh_instance.mesh = terrain_mesh
	if terrain_mesh != null:
		_terrain_material = _create_terrain_material()
		terrain_mesh.surface_set_material(0, _terrain_material)


func _apply_tile_line_mesh(tile_line_mesh: Mesh) -> void:
	if not config.show_tile_lines:
		_line_mesh_instance.mesh = null
		_line_mesh_instance.visible = false
		return
	_line_mesh_instance.mesh = tile_line_mesh
	_line_mesh_instance.visible = tile_line_mesh != null
	if tile_line_mesh != null:
		_line_material = _create_line_material()
		tile_line_mesh.surface_set_material(0, _line_material)


func _apply_collision_from_mesh(terrain_mesh: Mesh) -> void:
	if not config.build_collision:
		if _collision_shape != null:
			_collision_shape.shape = null
		return
	if _collision_shape == null:
		_ensure_nodes()
	if _collision_shape != null:
		_collision_shape.shape = MapCollisionBaker.make_trimesh_shape(terrain_mesh)


func _clear_generated_meshes() -> void:
	_ensure_nodes()
	_mesh_instance.mesh = null
	_line_mesh_instance.mesh = null
	if _collision_shape != null:
		_collision_shape.shape = null


func _ensure_directory_for_file(path: String) -> Error:
	var base_directory := path.get_base_dir()
	if base_directory.is_empty() or DirAccess.dir_exists_absolute(base_directory):
		return OK
	var result := DirAccess.make_dir_recursive_absolute(base_directory)
	if result != OK:
		push_error("MapBaker: failed to create directory: " + base_directory)
	return result


func _prepare_packed_scene_owners(root: Node) -> void:
	for child in root.get_children():
		child.owner = root
		_set_owner_recursive(child, root)


func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)

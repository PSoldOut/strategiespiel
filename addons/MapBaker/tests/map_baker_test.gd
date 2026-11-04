extends SceneTree


func _init() -> void:
	var config := MapBakerConfig.new()
	config.tile_size = 2.0
	config.build_collision = true
	config.show_tile_lines = true
	config.default_terrain_type = 10
	config.terrain_colors = {
		10: Color.GREEN,
		20: Color.SANDY_BROWN,
	}

	var map_data := [
		[_make_cell(10, 0.0), _make_cell(20, 0.5)],
		[_make_cell(20, 1.0), _make_cell(10, 1.5)],
	]

	var full_baker := MapBaker.new()
	full_baker.config = config
	root.add_child(full_baker)
	assert(full_baker.bake_map(map_data))
	var full_node := full_baker.create_baked_node()
	var full_mesh_instance := full_node.get_node("MeshInstance3D") as MeshInstance3D
	assert(full_mesh_instance.mesh != null)
	assert(full_node.get_node_or_null("StaticBody3D/CollisionShape3D") != null)
	assert(is_equal_approx(full_mesh_instance.mesh.get_aabb().size.x, 4.0))
	assert(is_equal_approx(full_mesh_instance.mesh.get_aabb().size.z, 4.0))

	var chunk_baker := MapBaker.new()
	chunk_baker.config = config
	root.add_child(chunk_baker)
	assert(chunk_baker.bake_map(map_data, Rect2i(1, 0, 1, 2)))
	var chunk_node := chunk_baker.create_baked_node()
	var chunk_mesh_instance := chunk_node.get_node("MeshInstance3D") as MeshInstance3D
	assert(chunk_mesh_instance.mesh != null)
	assert(is_equal_approx(chunk_mesh_instance.mesh.get_aabb().size.x, 2.0))
	assert(is_equal_approx(chunk_mesh_instance.mesh.get_aabb().size.z, 4.0))

	full_node.free()
	chunk_node.free()
	full_baker.free()
	chunk_baker.free()
	print("Map baker tests passed.")
	quit()


func _make_cell(terrain_type: int, height: float) -> Dictionary:
	return {
		"type": terrain_type,
		"height": height,
		"corners": {
			"sw": height,
			"se": height,
			"nw": height,
			"ne": height,
		},
	}

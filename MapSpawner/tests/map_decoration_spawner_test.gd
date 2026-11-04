extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := EntitySpawnCatalog.new()
	catalog.register_scene(&"grass_tuft", _create_decoration_scene(false))
	catalog.register_scene(&"rock", _create_decoration_scene(true))

	var spawn_parent := Node3D.new()
	root.add_child(spawn_parent)
	var spawner := EntitySpawner.new()
	spawner.catalog = catalog
	spawner.spawn_parent = spawn_parent
	root.add_child(spawner)

	var result := MapGenerationResult.new()
	result.map_data = [[_make_cell(0.5), _make_cell(1.0)]]
	result.decorations = [
		{
			&"id": &"grass_tuft",
			&"grid_position": Vector2i(0, 0),
			&"rotation_steps": 0,
			&"collision_mode": MapDecorationRule.CollisionMode.NONE,
		},
		{
			&"id": &"rock",
			&"grid_position": Vector2i(1, 0),
			&"rotation_steps": 1,
			&"collision_mode": MapDecorationRule.CollisionMode.BLOCKING,
		},
	]

	var spawned := MapDecorationSpawner.spawn_all(result, spawner, 2.0)
	assert(spawned.size() == 2)
	assert(spawned[0].global_position == Vector3(1.0, 0.5, 1.0))
	assert(spawned[1].global_position == Vector3(3.0, 1.0, 1.0))
	assert(spawned[1].get_node_or_null("StaticBody3D/CollisionShape3D") != null)
	assert(
		spawned[1].get_meta(MapDecorationSpawner.META_COLLISION_MODE)
		== MapDecorationRule.CollisionMode.BLOCKING
	)

	spawn_parent.free()
	spawner.free()
	print("Map decoration spawner tests passed.")
	quit()


func _create_decoration_scene(with_collision: bool) -> PackedScene:
	var scene_root := Node3D.new()
	if with_collision:
		var body := StaticBody3D.new()
		body.name = "StaticBody3D"
		scene_root.add_child(body)
		body.owner = scene_root
		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		collision.shape = BoxShape3D.new()
		body.add_child(collision)
		collision.owner = scene_root

	var packed_scene := PackedScene.new()
	assert(packed_scene.pack(scene_root) == OK)
	scene_root.free()
	return packed_scene


func _make_cell(height: float) -> Dictionary:
	return {
		&"type": 0,
		&"height": height,
		&"corners": {
			&"sw": height,
			&"se": height,
			&"nw": height,
			&"ne": height,
		},
	}

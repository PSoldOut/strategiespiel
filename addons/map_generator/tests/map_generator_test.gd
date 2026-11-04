extends SceneTree


func _init() -> void:
	var rule := MapDecorationRule.new()
	rule.decoration_id = &"test_decoration"
	rule.allowed_terrain_ids = PackedInt32Array([20])
	rule.density = 1.0
	rule.collision_mode = MapDecorationRule.CollisionMode.BLOCKING

	var config := MapGeneratorConfig.new()
	config.width = 7
	config.height = 5
	config.default_terrain_id = 10
	config.secondary_terrain_id = 20
	config.min_height = -2.0
	config.max_height = 4.0
	config.height_step = 0.5
	config.noise_frequency = 0.12
	config.decoration_rules = [rule]

	var generator := SeededMapGenerator.new()
	var first := generator.generate(config, 123456789)
	var second := generator.generate(config, 123456789)
	var different := generator.generate(config, 987654321)

	assert(first != null)
	assert(first.map_data == second.map_data)
	assert(first.decorations == second.decorations)
	assert(first.map_data != different.map_data or first.decorations != different.decorations)
	assert(first.map_data.size() == config.height)
	assert(first.decorations.size() > 0)

	for y in config.height:
		assert(first.map_data[y].size() == config.width)
		for x in config.width:
			var cell: Dictionary = first.map_data[y][x]
			var cell_height: float = cell[&"height"]
			assert(cell_height >= config.min_height)
			assert(cell_height <= config.max_height)
			var steps := (cell_height - config.min_height) / config.height_step
			assert(is_equal_approx(steps, roundf(steps)))
			if x + 1 < config.width:
				var east_corners: Dictionary = first.map_data[y][x + 1][&"corners"]
				assert(cell[&"corners"][&"ne"] == east_corners[&"nw"])
				assert(cell[&"corners"][&"se"] == east_corners[&"sw"])
			if y + 1 < config.height:
				var south_corners: Dictionary = first.map_data[y + 1][x][&"corners"]
				assert(cell[&"corners"][&"sw"] == south_corners[&"nw"])
				assert(cell[&"corners"][&"se"] == south_corners[&"ne"])

	for decoration in first.decorations:
		var position: Vector2i = decoration[&"grid_position"]
		assert(first.map_data[position.y][position.x][&"type"] == 20)
		assert(decoration[&"rotation_steps"] in range(4))
		assert(decoration[&"collision_mode"] == MapDecorationRule.CollisionMode.BLOCKING)

	print("Map generator tests passed.")
	quit()

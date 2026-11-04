class_name SeededMapGenerator
extends RefCounted

const GENERATOR_VERSION := "1.0.0"
const HEIGHT_SEED_SALT := 1_013_904_223
const RNG_SEED_SALT := 1_664_525

const CELL_TYPE := &"type"
const CELL_HEIGHT := &"height"
const CELL_CORNERS := &"corners"
const CORNER_SW := &"sw"
const CORNER_SE := &"se"
const CORNER_NW := &"nw"
const CORNER_NE := &"ne"
const DECORATION_ID := &"id"
const GRID_POSITION := &"grid_position"
const ROTATION_STEPS := &"rotation_steps"
const COLLISION_MODE := &"collision_mode"


func generate(config: MapGeneratorConfig, seed: int) -> MapGenerationResult:
	var validation_error := _get_validation_error(config)
	if not validation_error.is_empty():
		push_error("SeededMapGenerator: %s" % validation_error)
		return null

	var terrain_noise := _create_noise(seed, config.noise_frequency)
	var height_noise := _create_noise(seed ^ HEIGHT_SEED_SALT, config.noise_frequency)
	var decoration_rng := RandomNumberGenerator.new()
	decoration_rng.seed = seed ^ RNG_SEED_SALT

	var map_data := _generate_cells(config, terrain_noise, height_noise)
	_assign_corner_heights(map_data, config.width, config.height)

	var result := MapGenerationResult.new()
	result.seed = seed
	result.generator_version = GENERATOR_VERSION
	result.map_data = map_data
	result.decorations = _generate_decorations(config, map_data, decoration_rng)
	return result


func _create_noise(seed: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = int((seed ^ (seed >> 32)) & 0x7FFFFFFF)
	noise.frequency = frequency
	return noise


func _generate_cells(
	config: MapGeneratorConfig,
	terrain_noise: FastNoiseLite,
	height_noise: FastNoiseLite,
) -> Array:
	var map_data: Array = []
	map_data.resize(config.height)
	for y in config.height:
		var row: Array[Dictionary] = []
		row.resize(config.width)
		for x in config.width:
			var terrain_value := terrain_noise.get_noise_2d(x, y)
			var terrain_id := config.default_terrain_id
			if terrain_value >= config.terrain_threshold:
				terrain_id = config.secondary_terrain_id

			var normalized_height := (height_noise.get_noise_2d(x, y) + 1.0) * 0.5
			var raw_height := lerpf(config.min_height, config.max_height, normalized_height)
			var cell_height := _quantize_height(raw_height, config)
			row[x] = {
				CELL_TYPE: terrain_id,
				CELL_HEIGHT: cell_height,
				CELL_CORNERS: {},
			}
		map_data[y] = row
	return map_data


func _quantize_height(value: float, config: MapGeneratorConfig) -> float:
	var step_count := roundf((value - config.min_height) / config.height_step)
	return clampf(
		config.min_height + step_count * config.height_step,
		config.min_height,
		config.max_height,
	)


func _assign_corner_heights(map_data: Array, width: int, height: int) -> void:
	var corner_heights: Array = []
	corner_heights.resize(height + 1)
	for vertex_y in height + 1:
		var row := PackedFloat64Array()
		row.resize(width + 1)
		for vertex_x in width + 1:
			row[vertex_x] = _average_adjacent_heights(
				map_data,
				vertex_x,
				vertex_y,
				width,
				height,
			)
		corner_heights[vertex_y] = row

	for y in height:
		for x in width:
			map_data[y][x][CELL_CORNERS] = {
				CORNER_SW: corner_heights[y + 1][x],
				CORNER_SE: corner_heights[y + 1][x + 1],
				CORNER_NW: corner_heights[y][x],
				CORNER_NE: corner_heights[y][x + 1],
			}


func _average_adjacent_heights(
	map_data: Array,
	vertex_x: int,
	vertex_y: int,
	width: int,
	height: int,
) -> float:
	var total := 0.0
	var cell_count := 0
	for cell_y in range(vertex_y - 1, vertex_y + 1):
		if cell_y < 0 or cell_y >= height:
			continue
		for cell_x in range(vertex_x - 1, vertex_x + 1):
			if cell_x < 0 or cell_x >= width:
				continue
			total += float(map_data[cell_y][cell_x][CELL_HEIGHT])
			cell_count += 1
	return total / cell_count


func _generate_decorations(
	config: MapGeneratorConfig,
	map_data: Array,
	rng: RandomNumberGenerator,
) -> Array[Dictionary]:
	var decorations: Array[Dictionary] = []
	for y in config.height:
		for x in config.width:
			var terrain_id: int = map_data[y][x][CELL_TYPE]
			for rule in config.decoration_rules:
				if (
					not rule.allowed_terrain_ids.is_empty()
					and not rule.allowed_terrain_ids.has(terrain_id)
				):
					continue
				if rng.randf() >= rule.density:
					continue
				decorations.append({
					DECORATION_ID: rule.decoration_id,
					GRID_POSITION: Vector2i(x, y),
					ROTATION_STEPS: rng.randi_range(0, 3),
					COLLISION_MODE: rule.collision_mode,
				})
				break
	return decorations


func _get_validation_error(config: MapGeneratorConfig) -> String:
	if config == null:
		return "config must not be null."
	if config.width <= 0 or config.height <= 0:
		return "width and height must be greater than zero."
	if config.min_height > config.max_height:
		return "min_height must not exceed max_height."
	if config.height_step <= 0.0:
		return "height_step must be greater than zero."
	if config.noise_frequency <= 0.0:
		return "noise_frequency must be greater than zero."
	if config.terrain_threshold < -1.0 or config.terrain_threshold > 1.0:
		return "terrain_threshold must be between -1.0 and 1.0."
	for rule_index in config.decoration_rules.size():
		var rule := config.decoration_rules[rule_index]
		if rule == null:
			return "decoration rule %d must not be null." % rule_index
		if rule.decoration_id.is_empty():
			return "decoration rule %d must have a decoration_id." % rule_index
		if rule.density < 0.0 or rule.density > 1.0:
			return "decoration rule %d density must be between 0.0 and 1.0." % rule_index
		if (
			rule.collision_mode != MapDecorationRule.CollisionMode.NONE
			and rule.collision_mode != MapDecorationRule.CollisionMode.BLOCKING
		):
			return "decoration rule %d has an invalid collision_mode." % rule_index
	return ""

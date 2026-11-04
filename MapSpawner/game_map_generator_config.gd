class_name GameMapGeneratorConfig
extends RefCounted
## Adapts game terrain IDs and map dimensions to the standalone generator.


static func create_default(
	width: int,
	height: int,
	decoration_rules: Array[MapDecorationRule] = [],
) -> MapGeneratorConfig:
	var config := MapGeneratorConfig.new()
	config.width = width
	config.height = height
	config.default_terrain_id = EnumMappings.GroundType.GRAS_TILE
	config.secondary_terrain_id = EnumMappings.GroundType.GRAS_TILE
	config.terrain_threshold = 1.0
	config.min_height = -2.0
	config.max_height = 2.0
	config.height_step = 0.5
	config.noise_frequency = 0.025
	config.decoration_rules = decoration_rules
	return config

class_name GameMapBakerConfig
extends RefCounted
## Adapts game terrain IDs and rendering policy to the standalone MapBaker.


static func create(
	tile_size: float,
	build_collision: bool,
	show_tile_lines: bool,
	edge_base_height: float = 0.0,
) -> MapBakerConfig:
	var config := MapBakerConfig.new()
	config.tile_size = tile_size
	config.build_collision = build_collision
	config.show_tile_lines = show_tile_lines
	config.default_terrain_type = EnumMappings.GroundType.GRAS_TILE
	config.default_terrain_color = Color(0.5, 0.5, 0.5)
	config.edge_base_height = edge_base_height
	config.terrain_colors = {
		EnumMappings.GroundType.GRAS_TILE: Color(0.2, 0.8, 0.2),
		EnumMappings.GroundType.SAND_TILE: Color(1.0, 0.85, 0.2),
	}
	return config
